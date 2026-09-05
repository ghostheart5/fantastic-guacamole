$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('chronospark-secret-guard-' + [guid]::NewGuid().ToString('N'))
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$utf8 = [System.Text.UTF8Encoding]::new($false)
$syntheticToken = 'gh' + 'p_' + ('x' * 24)
$caseCount = 0

function Invoke-GuardCase {
  param(
    [string]$Name,
    [string]$FileName,
    [string]$Content,
    [bool]$Tracked = $false,
    [bool]$Ignored = $false,
    [bool]$InitializeGit = $true,
    [string]$Guard = 'secret_content_guard.ps1',
    [int]$ExpectedExit = 0
  )
  $caseRoot = Join-Path $fixtureRoot $Name
  $caseScripts = Join-Path $caseRoot 'scripts'
  New-Item -ItemType Directory -Path $caseScripts -Force | Out-Null
  foreach ($file in @('secret_content_guard.ps1', 'security_secret_guard.ps1', 'repository_scan_files.ps1')) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot "scripts/$file") -Destination (Join-Path $caseScripts $file)
  }
  if ($InitializeGit) {
    & git -C $caseRoot init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Fixture Git initialization failed.' }
  }
  [System.IO.File]::WriteAllText((Join-Path $caseRoot $FileName), $Content, $utf8)
  if ($Ignored) {
    [System.IO.File]::WriteAllText((Join-Path $caseRoot '.gitignore'), $FileName, $utf8)
  }
  if ($Tracked) {
    & git -C $caseRoot add -- $FileName
    if ($LASTEXITCODE -ne 0) { throw 'Fixture Git staging failed.' }
  }
  # Child guard output contains paths only; never echo fixture token contents.
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $caseScripts $Guard) 2>&1
  $actualExit = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorAction
  if ($actualExit -ne $ExpectedExit) {
    throw "Secret guard fixture '$Name' expected exit $ExpectedExit but received $actualExit."
  }
  if (-not $InitializeGit -and ($output -join ' ') -notmatch 'git repository file discovery failed') {
    throw 'Git failure did not fail closed at repository discovery.'
  }
  $script:caseCount++
  Write-Host "PASS: $Name"
}

try {
  $middleDot = [char]0xB7
  Invoke-GuardCase -Name unicode-benign -FileName "review ${middleDot} safe.json" -Content '{}' -Tracked $true
  Invoke-GuardCase -Name unicode-tracked-token -FileName "review ${middleDot} secret.txt" -Content $syntheticToken -Tracked $true -ExpectedExit 1
  Invoke-GuardCase -Name unicode-untracked-token -FileName "review ${middleDot} untracked.txt" -Content $syntheticToken -ExpectedExit 1
  Invoke-GuardCase -Name brackets-untracked-token -FileName 'review[1].txt' -Content $syntheticToken -ExpectedExit 1
  Invoke-GuardCase -Name ignored-token -FileName 'ignored.txt' -Content $syntheticToken -Ignored $true
  Invoke-GuardCase -Name unicode-key-path -FileName "upload ${middleDot} key.jks" -Content 'fixture only' -Guard 'security_secret_guard.ps1' -ExpectedExit 1
  Invoke-GuardCase -Name missing-repository -FileName 'safe.txt' -Content 'safe' -InitializeGit $false -ExpectedExit 1
  Write-Host "Secret guard execution contract passed: $caseCount cases."
} finally {
  $resolvedFixtureRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
  $tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  if (-not $resolvedFixtureRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
      [System.IO.Path]::GetFileName($resolvedFixtureRoot) -notlike 'chronospark-secret-guard-*') {
    throw 'Refusing cleanup outside the secret guard fixture directory.'
  }
  if (Test-Path -LiteralPath $resolvedFixtureRoot) {
    Remove-Item -LiteralPath $resolvedFixtureRoot -Recurse -Force
  }
}
