$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guard = Join-Path $PSScriptRoot 'version_consistency_guard.ps1'
$failures = New-Object System.Collections.Generic.List[string]

$pubspecMatch = [regex]::Match(
  (Get-Content -Raw (Join-Path $root 'pubspec.yaml')),
  '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$'
)
if (-not $pubspecMatch.Success) {
  throw 'Could not read the current version from pubspec.yaml.'
}
$matchingTag = "v$($pubspecMatch.Groups[1].Value)"

$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  'pwsh'
} elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  'powershell'
} else {
  throw 'PowerShell is required to run the version consistency guard contract.'
}

$originalRefType = $env:GITHUB_REF_TYPE
$originalRefName = $env:GITHUB_REF_NAME

function Invoke-ContractCase(
  [string]$Name,
  [string]$RefType,
  [string]$RefName,
  [string[]]$GuardArguments,
  [int]$ExpectedExitCode
) {
  $env:GITHUB_REF_TYPE = $RefType
  $env:GITHUB_REF_NAME = $RefName

  $arguments = @('-NoProfile')
  if ($env:OS -eq 'Windows_NT') {
    $arguments += @('-ExecutionPolicy', 'Bypass')
  }
  $arguments += @('-File', $guard)
  $arguments += $GuardArguments

  $output = & $powerShellCommand @arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne $ExpectedExitCode) {
    $failures.Add(
      "$Name expected exit code $ExpectedExitCode but received $exitCode.`n$($output -join "`n")"
    )
  }
}

try {
  Invoke-ContractCase `
    -Name 'Candidate branch is not treated as a release tag' `
    -RefType 'branch' `
    -RefName 'release/chronospark-production-candidate-20260821' `
    -GuardArguments @() `
    -ExpectedExitCode 0

  Invoke-ContractCase `
    -Name 'Matching GitHub tag is validated' `
    -RefType 'tag' `
    -RefName $matchingTag `
    -GuardArguments @() `
    -ExpectedExitCode 0

  Invoke-ContractCase `
    -Name 'Invalid GitHub tag is rejected' `
    -RefType 'tag' `
    -RefName 'release/not-a-version' `
    -GuardArguments @() `
    -ExpectedExitCode 1

  Invoke-ContractCase `
    -Name 'Mismatched version tag is rejected' `
    -RefType 'tag' `
    -RefName 'v999.999.999' `
    -GuardArguments @() `
    -ExpectedExitCode 1

  Invoke-ContractCase `
    -Name 'Required tag fails closed on a branch' `
    -RefType 'branch' `
    -RefName 'release/chronospark-production-candidate-20260821' `
    -GuardArguments @('-RequireTag') `
    -ExpectedExitCode 1

  Invoke-ContractCase `
    -Name 'Explicit matching tag remains supported' `
    -RefType 'branch' `
    -RefName 'release/chronospark-production-candidate-20260821' `
    -GuardArguments @('-ExpectedTag', $matchingTag) `
    -ExpectedExitCode 0
} finally {
  if ($null -eq $originalRefType) {
    Remove-Item Env:GITHUB_REF_TYPE -ErrorAction SilentlyContinue
  } else {
    $env:GITHUB_REF_TYPE = $originalRefType
  }

  if ($null -eq $originalRefName) {
    Remove-Item Env:GITHUB_REF_NAME -ErrorAction SilentlyContinue
  } else {
    $env:GITHUB_REF_NAME = $originalRefName
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Version consistency guard contract failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Version consistency guard contract passed.' -ForegroundColor Green
