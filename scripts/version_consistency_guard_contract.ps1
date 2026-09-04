$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guard = Join-Path $PSScriptRoot 'version_consistency_guard.ps1'
$failures = New-Object System.Collections.Generic.List[string]

$pubspecMatch = [regex]::Match(
  (Get-Content -Raw (Join-Path $root 'pubspec.yaml')),
  '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$'
)
if (-not $pubspecMatch.Success) {
  throw 'Could not read the current version from pubspec.yaml.'
}
$versionName = $pubspecMatch.Groups[1].Value
$versionCode = $pubspecMatch.Groups[2].Value
$matchingTag = "v$versionName"

$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  'pwsh'
} elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  'powershell'
} else {
  throw 'PowerShell is required to run the version consistency guard contract.'
}

$originalRefType = $env:GITHUB_REF_TYPE
$originalRefName = $env:GITHUB_REF_NAME
$originalSha = $env:GITHUB_SHA
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "chronospark-version-guard-$([guid]::NewGuid().ToString('N'))"

function Invoke-GitFixture([string[]]$Arguments) {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & git -C $fixtureRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0) {
    throw "Fixture git command failed: git $($Arguments -join ' ')`n$($output -join "`n")"
  }
  return $output
}

function Invoke-ContractCase(
  [string]$Name,
  [string]$RefType,
  [string]$RefName,
  [string]$EventSha,
  [string[]]$GuardArguments,
  [int]$ExpectedExitCode,
  [string]$ExpectedMessage = ''
) {
  $env:GITHUB_REF_TYPE = $RefType
  $env:GITHUB_REF_NAME = $RefName
  $env:GITHUB_SHA = $EventSha

  $arguments = @('-NoProfile')
  if ($env:OS -eq 'Windows_NT') {
    $arguments += @('-ExecutionPolicy', 'Bypass')
  }
  $arguments += @('-File', $guard, '-RepositoryRoot', $fixtureRoot)
  $arguments += $GuardArguments

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    # Expected rejection cases write to stderr. Keep that output available to
    # the contract assertions instead of treating it as a harness failure.
    $output = & $powerShellCommand @arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $outputText = $output -join "`n"
  if ($exitCode -ne $ExpectedExitCode) {
    $failures.Add(
      "$Name expected exit code $ExpectedExitCode but received $exitCode.`n$outputText"
    )
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedMessage) -and $outputText -notmatch [regex]::Escape($ExpectedMessage)) {
    $failures.Add("$Name did not emit expected message '$ExpectedMessage'.`n$outputText")
  }
}

try {
  New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'android') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $fixtureRoot 'pubspec.yaml') -Value "version: $versionName+$versionCode" -NoNewline
  Set-Content -LiteralPath (Join-Path $fixtureRoot 'android/gradle.properties') -Value "CHRONOSPARK_VERSION_NAME=$versionName`nCHRONOSPARK_VERSION_CODE=$versionCode" -NoNewline
  & git -C $fixtureRoot init --initial-branch=main | Out-Null
  & git -C $fixtureRoot config user.name 'ChronoSpark Contract'
  & git -C $fixtureRoot config user.email 'contract@invalid.local'
  Invoke-GitFixture @('add', 'pubspec.yaml', 'android/gradle.properties') | Out-Null
  Invoke-GitFixture @('commit', '-m', 'authorized production source') | Out-Null
  $mainCommit = (Invoke-GitFixture @('rev-parse', 'HEAD') | Select-Object -First 1).Trim()
  Invoke-GitFixture @('tag', $matchingTag) | Out-Null

  Invoke-ContractCase `
    -Name 'Candidate branch is not treated as a release tag' `
    -RefType 'branch' `
    -RefName 'release/chronospark-production-candidate-20260821' `
    -EventSha $mainCommit `
    -GuardArguments @() `
    -ExpectedExitCode 0

  Invoke-ContractCase `
    -Name 'Matching authorized GitHub tag is validated' `
    -RefType 'tag' `
    -RefName $matchingTag `
    -EventSha $mainCommit `
    -GuardArguments @('-RequireTag') `
    -ExpectedExitCode 0

  Invoke-ContractCase `
    -Name 'Invalid GitHub tag is rejected' `
    -RefType 'tag' `
    -RefName 'release/not-a-version' `
    -EventSha $mainCommit `
    -GuardArguments @('-RequireTag') `
    -ExpectedExitCode 1 `
    -ExpectedMessage 'must match vMAJOR.MINOR.PATCH'

  Invoke-ContractCase `
    -Name 'Mismatched version tag is rejected' `
    -RefType 'tag' `
    -RefName 'v999.999.999' `
    -EventSha $mainCommit `
    -GuardArguments @('-RequireTag') `
    -ExpectedExitCode 1 `
    -ExpectedMessage 'does not match pubspec version'

  Invoke-ContractCase `
    -Name 'Required tag fails closed on a branch' `
    -RefType 'branch' `
    -RefName 'release/chronospark-production-candidate-20260821' `
    -EventSha $mainCommit `
    -GuardArguments @('-RequireTag') `
    -ExpectedExitCode 1 `
    -ExpectedMessage 'A release tag is required.'

  Invoke-ContractCase `
    -Name 'Explicit matching authorized tag remains supported' `
    -RefType 'branch' `
    -RefName 'release/chronospark-production-candidate-20260821' `
    -EventSha $mainCommit `
    -GuardArguments @('-ExpectedTag', $matchingTag) `
    -ExpectedExitCode 0

  Invoke-GitFixture @('switch', '-c', 'feature') | Out-Null
  Add-Content -LiteralPath (Join-Path $fixtureRoot 'pubspec.yaml') -Value "`n# unauthorized release source"
  Invoke-GitFixture @('add', 'pubspec.yaml') | Out-Null
  Invoke-GitFixture @('commit', '-m', 'unauthorized source') | Out-Null
  $featureCommit = (Invoke-GitFixture @('rev-parse', 'HEAD') | Select-Object -First 1).Trim()
  $candidateTag = "v$versionName-rc.1"
  Invoke-GitFixture @('tag', $candidateTag) | Out-Null

  Invoke-ContractCase `
    -Name 'Tag outside main and production is rejected' `
    -RefType 'tag' `
    -RefName $candidateTag `
    -EventSha $featureCommit `
    -GuardArguments @('-RequireTag') `
    -ExpectedExitCode 1 `
    -ExpectedMessage 'is not reachable from an authorized main/production ref.'

  Invoke-GitFixture @('branch', 'production', $featureCommit) | Out-Null
  Invoke-ContractCase `
    -Name 'Production branch commit is authorized' `
    -RefType 'tag' `
    -RefName $candidateTag `
    -EventSha $featureCommit `
    -GuardArguments @('-RequireTag') `
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
  if ($null -eq $originalSha) {
    Remove-Item Env:GITHUB_SHA -ErrorAction SilentlyContinue
  } else {
    $env:GITHUB_SHA = $originalSha
  }

  $resolvedFixture = [System.IO.Path]::GetFullPath($fixtureRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedFixture.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Version consistency guard contract failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Version consistency guard contract passed.' -ForegroundColor Green
