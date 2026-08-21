param(
  [string]$ExpectedTag,
  [switch]$RequireTag
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) { $failures.Add($Message) }

function Read-Version([string]$Path, [string]$Pattern, [string]$Label) {
  if (-not (Test-Path $Path)) {
    Add-Failure "Missing $Label file: $Path"
    return $null
  }
  $match = [regex]::Match((Get-Content -Raw $Path), $Pattern)
  if (-not $match.Success) {
    Add-Failure "Could not read $Label from $Path"
    return $null
  }
  return [pscustomobject]@{ Name = $match.Groups[1].Value; Code = [int]$match.Groups[2].Value }
}

$pubspec = Read-Version (Join-Path $root 'pubspec.yaml') '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$' 'pubspec version'
$gradlePath = Join-Path $root 'android/gradle.properties'
$gradleText = if (Test-Path $gradlePath) { Get-Content -Raw $gradlePath } else { '' }
$gradleNameMatch = [regex]::Match($gradleText, '(?m)^CHRONOSPARK_VERSION_NAME\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$')
$gradleCodeMatch = [regex]::Match($gradleText, '(?m)^CHRONOSPARK_VERSION_CODE\s*=\s*([0-9]+)\s*$')
if (-not $gradleNameMatch.Success -or -not $gradleCodeMatch.Success) {
  Add-Failure "Could not read Android version properties from $gradlePath"
  $gradleProps = $null
} else {
  $gradleProps = [pscustomobject]@{ Name = $gradleNameMatch.Groups[1].Value; Code = [int]$gradleCodeMatch.Groups[1].Value }
}

if ($null -ne $pubspec -and $null -ne $gradleProps) {
  if ($pubspec.Name -ne $gradleProps.Name -or $pubspec.Code -ne $gradleProps.Code) {
    Add-Failure "pubspec and Android versions differ ($($pubspec.Name)+$($pubspec.Code) vs $($gradleProps.Name)+$($gradleProps.Code))."
  }
  if ($pubspec.Code -le 0) { Add-Failure 'Version code must be a positive integer.' }
}

$tag = $ExpectedTag
if ([string]::IsNullOrWhiteSpace($tag) -and $env:GITHUB_REF_TYPE -eq 'tag') {
  $tag = $env:GITHUB_REF_NAME
}
if ($RequireTag -and [string]::IsNullOrWhiteSpace($tag)) { Add-Failure 'A release tag is required.' }
if (-not [string]::IsNullOrWhiteSpace($tag)) {
  $tagMatch = [regex]::Match($tag, '^v([0-9]+\.[0-9]+\.[0-9]+)(?:[-+].*)?$')
  if (-not $tagMatch.Success) {
    Add-Failure "Release tag '$tag' must match vMAJOR.MINOR.PATCH (optional prerelease/build suffix allowed)."
  } elseif ($null -ne $pubspec -and $pubspec.Name -ne $tagMatch.Groups[1].Value) {
    Add-Failure "Release tag $tag does not match pubspec version $($pubspec.Name)."
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Version consistency guard failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Version consistency guard passed.' -ForegroundColor Green
