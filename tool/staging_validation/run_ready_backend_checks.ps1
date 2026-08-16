throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

[CmdletBinding()]
param(
    [switch]$ConfirmStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'This script must never be run against production.' -ForegroundColor Yellow
if (-not $ConfirmStaging) {
    throw 'Refusing to run. Pass -ConfirmStaging only after explicitly confirming STAGING_SUPABASE_URL is a staging project.'
}

. "$PSScriptRoot/StagingValidation.Common.ps1"
Import-StagingEnvironment -EnvironmentFile "$PSScriptRoot/.env"

$supabaseUrl = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_URL'
$expectedStagingHost = 'retired-staging-project.invalid'

try {
    $target = [uri]$supabaseUrl
}
catch {
    throw 'STAGING_SUPABASE_URL is not a valid absolute URL.'
}

if ($target.Scheme -ne 'https' -or $target.Host -ne $expectedStagingHost -or
    $target.AbsolutePath -notin @('', '/')) {
    throw "Refusing to run: STAGING_SUPABASE_URL must be the confirmed staging base URL https://$expectedStagingHost."
}

Write-Host "Target STAGING_SUPABASE_URL: $supabaseUrl" -ForegroundColor Cyan
$anonKey = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_ANON_KEY'
$userAEmail = Get-RequiredStagingValue -Name 'STAGING_USER_A_EMAIL'
$userAPassword = Get-RequiredStagingValue -Name 'STAGING_USER_A_PASSWORD'
$userBEmail = Get-RequiredStagingValue -Name 'STAGING_USER_B_EMAIL'
$userBPassword = Get-RequiredStagingValue -Name 'STAGING_USER_B_PASSWORD'
$userAUuid = Get-RequiredStagingValue -Name 'STAGING_USER_A_UUID'
$userBUuid = Get-RequiredStagingValue -Name 'STAGING_USER_B_UUID'
Test-StagingUserUuidConfiguration -UserAUuid $userAUuid -UserBUuid $userBUuid

Write-Host 'No db push, migration apply/reset, or Edge Function deploy command is present in this runner.' -ForegroundColor Cyan

. "$PSScriptRoot/credit_debit_tests.ps1"
. "$PSScriptRoot/privileged_rpc_denial_tests.ps1"
. "$PSScriptRoot/profile_repair_tests.ps1"
. "$PSScriptRoot/global_metrics_denial_tests.ps1"
. "$PSScriptRoot/rate_limit_rpc_tests.ps1"

$userA = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
    -Email $userAEmail -Password $userAPassword -Label 'staging_user_a'
$userB = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
    -Email $userBEmail -Password $userBPassword -Label 'staging_user_b'
Assert-StagingSessionIdentity -Session $userA -ExpectedUserId $userAUuid
Assert-StagingSessionIdentity -Session $userB -ExpectedUserId $userBUuid

Invoke-CreditDebitTests -UserA $userA -SupabaseUrl $supabaseUrl -AnonKey $anonKey
Invoke-PrivilegedRpcDenialTests -UserA $userA -UserB $userB -SupabaseUrl $supabaseUrl -AnonKey $anonKey
Invoke-ProfileRepairTests -UserA $userA -UserB $userB -SupabaseUrl $supabaseUrl -AnonKey $anonKey
Invoke-GlobalMetricsDenialTests -UserA $userA -UserB $userB -SupabaseUrl $supabaseUrl -AnonKey $anonKey
Invoke-RateLimitRpcTests -UserA $userA -UserAEmail $userAEmail -UserAPassword $userAPassword `
    -SupabaseUrl $supabaseUrl -AnonKey $anonKey

Write-Host "Completed with $script:ValidationFailures failure(s) and $script:ValidationSkips skip(s)." -ForegroundColor Cyan
if ($script:ValidationFailures -gt 0) {
    exit 1
}
