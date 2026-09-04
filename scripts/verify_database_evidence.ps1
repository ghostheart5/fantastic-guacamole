[CmdletBinding()]
param(
  [string]$ExactCommitPath = 'artifacts/database-evidence/exact-commit.json',
  [string]$EdgeJUnitPath = 'coverage/edge-function-tests.junit.xml',
  [string]$ExpectedCommit = $env:GITHUB_SHA
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

if ([string]::IsNullOrWhiteSpace($ExpectedCommit) -or
  $ExpectedCommit -notmatch '^[A-Fa-f0-9]{40}$') {
  throw 'An exact 40-character -ExpectedCommit is required.'
}
if (-not (Test-Path -LiteralPath $ExactCommitPath -PathType Leaf)) {
  throw "Exact database source evidence is missing: $ExactCommitPath"
}
if (-not (Test-Path -LiteralPath $EdgeJUnitPath -PathType Leaf)) {
  throw "Edge Function JUnit evidence is missing: $EdgeJUnitPath"
}

try {
  $source = Get-Content -LiteralPath $ExactCommitPath -Raw | ConvertFrom-Json
}
catch {
  throw "Exact database source evidence is invalid JSON: $ExactCommitPath"
}
if ($source.schemaVersion -ne 1) {
  throw 'Database source evidence has an unsupported schema version.'
}
if ([string]$source.commit -cne $ExpectedCommit.ToLowerInvariant()) {
  throw 'Database evidence commit does not match the expected workflow commit.'
}
if ([string]::IsNullOrWhiteSpace([string]$source.runId) -or
  [string]::IsNullOrWhiteSpace([string]$source.runAttempt)) {
  throw 'Database source evidence is missing the workflow run identity.'
}

try {
  [xml]$junit = Get-Content -LiteralPath $EdgeJUnitPath -Raw
}
catch {
  throw "Edge Function JUnit evidence is invalid XML: $EdgeJUnitPath"
}
if ($junit.DocumentElement.LocalName -ne 'testsuites') {
  throw 'Edge Function JUnit evidence must have a testsuites root.'
}
$testCases = @($junit.SelectNodes("//*[local-name()='testcase']"))
$failures = @($junit.SelectNodes("//*[local-name()='testcase']/*[local-name()='failure']"))
$errors = @($junit.SelectNodes("//*[local-name()='testcase']/*[local-name()='error']"))
$skipped = @($junit.SelectNodes("//*[local-name()='testcase']/*[local-name()='skipped']"))
if ($testCases.Count -le 0) {
  throw 'Edge Function JUnit evidence contains zero tests.'
}
if ($failures.Count -gt 0 -or $errors.Count -gt 0 -or $skipped.Count -gt 0) {
  throw "Edge Function JUnit evidence is incomplete: $($failures.Count) failures, $($errors.Count) errors, $($skipped.Count) skipped."
}

Write-Host "Database evidence verified for commit $($source.commit) with $($testCases.Count) Edge test(s)." -ForegroundColor Green
