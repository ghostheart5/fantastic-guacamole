param(
  [string]$ExpectedTag,
  [switch]$RequireTag,
  [string[]]$AuthorizedBranches = @('main', 'production'),
  [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
$root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  Split-Path -Parent $PSScriptRoot
} else {
  (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
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

function Resolve-GitCommit([string]$Revision) {
  $resolved = & git -C $root rev-parse --verify "$Revision`^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0 -or $null -eq $resolved) {
    return $null
  }
  return ($resolved | Select-Object -First 1).Trim()
}

function Test-ReleaseTagAuthorization([string]$Tag) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Add-Failure 'Git is required to validate release tag provenance.'
    return
  }
  & git -C $root rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "Release tag provenance cannot be validated because $root is not a Git worktree."
    return
  }

  $tagCommit = Resolve-GitCommit "refs/tags/$Tag"
  if ([string]::IsNullOrWhiteSpace($tagCommit)) {
    Add-Failure "Release tag '$Tag' does not resolve to a commit in this checkout."
    return
  }

  if ($env:GITHUB_REF_TYPE -eq 'tag' -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_SHA)) {
    $eventCommit = Resolve-GitCommit $env:GITHUB_SHA
    if ([string]::IsNullOrWhiteSpace($eventCommit) -or $eventCommit -ne $tagCommit) {
      Add-Failure "Release tag '$Tag' does not resolve to the GitHub event commit."
    }
  }

  $authorized = $false
  $foundAuthorizedRef = $false
  foreach ($branch in $AuthorizedBranches) {
    if ([string]::IsNullOrWhiteSpace($branch)) { continue }
    $candidateRefs = if ($branch.StartsWith('refs/')) {
      @($branch)
    } else {
      @("refs/heads/$branch", "refs/remotes/origin/$branch")
    }
    foreach ($candidateRef in $candidateRefs) {
      & git -C $root show-ref --verify --quiet $candidateRef
      if ($LASTEXITCODE -ne 0) { continue }
      $foundAuthorizedRef = $true
      & git -C $root merge-base --is-ancestor $tagCommit $candidateRef
      if ($LASTEXITCODE -eq 0) {
        $authorized = $true
        break
      }
    }
    if ($authorized) { break }
  }

  if (-not $foundAuthorizedRef) {
    Add-Failure "No authorized release refs were found for: $($AuthorizedBranches -join ', ')."
  } elseif (-not $authorized) {
    Add-Failure "Release tag '$Tag' is not reachable from an authorized main/production ref."
  }
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
  } else {
    Test-ReleaseTagAuthorization $tag
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Version consistency guard failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Version consistency guard passed.' -ForegroundColor Green
