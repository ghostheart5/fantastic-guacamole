[CmdletBinding()]
param(
    [switch]$ConfirmStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'This script must never be run against production.' -ForegroundColor Yellow
if (-not $ConfirmStaging) {
    throw 'Refusing to run. Pass -ConfirmStaging only after completing the final approval checklist.'
}

. "$PSScriptRoot/StagingValidation.Common.ps1"
Import-StagingEnvironment -EnvironmentFile "$PSScriptRoot/.env"

$supabaseUrl = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_URL'
if ($supabaseUrl -notmatch 'pxtjkwfedrtnxuihtdox') {
    throw 'Refusing to run: STAGING_SUPABASE_URL does not contain the confirmed staging project reference.'
}
if ($supabaseUrl -match '(?i)/rest/v1/?$') {
    throw 'Refusing to run: STAGING_SUPABASE_URL must be the base URL, not a REST endpoint.'
}

try {
    $target = [uri]$supabaseUrl
}
catch {
    throw 'STAGING_SUPABASE_URL is not a valid absolute URL.'
}
if ($target.Scheme -ne 'https' -or $target.Host -ne 'pxtjkwfedrtnxuihtdox.supabase.co' -or $target.AbsolutePath -notin @('', '/')) {
    throw 'Refusing to run: STAGING_SUPABASE_URL must be the confirmed staging base URL.'
}

foreach ($name in @(
    'STAGING_SUPABASE_ANON_KEY',
    'STAGING_USER_A_EMAIL',
    'STAGING_USER_A_PASSWORD',
    'STAGING_USER_B_EMAIL',
    'STAGING_USER_B_PASSWORD',
    'STAGING_USER_A_UUID',
    'STAGING_USER_B_UUID'
)) {
    Get-RequiredStagingValue -Name $name | Out-Null
}
Test-StagingUserUuidConfiguration `
    -UserAUuid (Get-RequiredStagingValue -Name 'STAGING_USER_A_UUID') `
    -UserBUuid (Get-RequiredStagingValue -Name 'STAGING_USER_B_UUID')

$approvalMarker = Join-Path $PSScriptRoot '.core_sync_rls_approved'
if (-not (Test-Path -LiteralPath $approvalMarker -PathType Leaf)) {
    throw "Refusing to run: local approval marker is missing: $approvalMarker"
}

Write-Host "Target STAGING_SUPABASE_URL: $supabaseUrl" -ForegroundColor Cyan
Write-Host 'Only generated Core-Sync, Profiles, and Monetization isolation suites will run.' -ForegroundColor Cyan

$suiteResults = @()
foreach ($suite in @(
    @{ Name = 'Core-Sync RLS'; Path = "$PSScriptRoot/core_sync_rls_tests/Run-CoreSyncRlsTests.ps1" },
    @{ Name = 'Profiles RLS'; Path = "$PSScriptRoot/profiles_rls_tests/ProfilesRlsTests.ps1" },
    @{ Name = 'Monetization isolation'; Path = "$PSScriptRoot/monetization_isolation_tests/Run-MonetizationReadIsolationTests.ps1" }
)) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $suite.Path -ConfirmStaging -ApproveMutationTests 2>&1 | Out-String
    Write-Host $output
    $suiteResults += [pscustomobject]@{
        Name = $suite.Name
        ExitCode = $LASTEXITCODE
        Passed = [regex]::Matches($output, '(?m)^PASS\s').Count
        Failed = [regex]::Matches($output, '(?m)^FAIL\s').Count
        Skipped = [regex]::Matches($output, '(?m)^SKIP\s').Count
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL  $($suite.Name) suite exited with code $LASTEXITCODE" -ForegroundColor Red
    }
}

$passed = ($suiteResults | Measure-Object -Property Passed -Sum).Sum
$failed = ($suiteResults | Measure-Object -Property Failed -Sum).Sum
$skipped = ($suiteResults | Measure-Object -Property Skipped -Sum).Sum
$failedSuites = @($suiteResults | Where-Object { $_.ExitCode -ne 0 }).Count
Write-Host "Summary: PASS $passed | FAIL $failed | SKIP $skipped | Failed suites $failedSuites" -ForegroundColor Cyan

if ($failed -gt 0 -or $failedSuites -gt 0) {
    exit 1
}