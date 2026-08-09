[CmdletBinding()]
param(
    [switch]$ConfirmStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'This script must never be run against production.' -ForegroundColor Yellow
if (-not $ConfirmStaging) {
    throw 'Refusing to run. Pass -ConfirmStaging only after hardening approval and migration verification.'
}

. "$PSScriptRoot/core_sync_rls_tests/CoreSyncRls.TestSupport.ps1"
Import-StagingEnvironment -EnvironmentFile "$PSScriptRoot/.env"
$supabaseUrl = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_URL'
if ($supabaseUrl -notmatch 'pxtjkwfedrtnxuihtdox' -or $supabaseUrl -match '(?i)/rest/v1/?$') {
    throw 'Refusing to run: STAGING_SUPABASE_URL must be the confirmed staging base URL, not a REST endpoint.'
}
$target = [uri]$supabaseUrl
if ($target.Scheme -ne 'https' -or $target.Host -ne 'pxtjkwfedrtnxuihtdox.supabase.co' -or $target.AbsolutePath -notin @('', '/')) {
    throw 'Refusing to run: target is not the confirmed staging base URL.'
}

$anonKey = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_ANON_KEY'
$userAUuid = Get-RequiredStagingValue -Name 'STAGING_USER_A_UUID'
$userBUuid = Get-RequiredStagingValue -Name 'STAGING_USER_B_UUID'
Test-StagingUserUuidConfiguration -UserAUuid $userAUuid -UserBUuid $userBUuid
$userA = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
    -Email (Get-RequiredStagingValue -Name 'STAGING_USER_A_EMAIL') `
    -Password (Get-RequiredStagingValue -Name 'STAGING_USER_A_PASSWORD') -Label 'staging_user_a'
$userB = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
    -Email (Get-RequiredStagingValue -Name 'STAGING_USER_B_EMAIL') `
    -Password (Get-RequiredStagingValue -Name 'STAGING_USER_B_PASSWORD') -Label 'staging_user_b'
Assert-StagingSessionIdentity -Session $userA -ExpectedUserId $userAUuid
Assert-StagingSessionIdentity -Session $userB -ExpectedUserId $userBUuid

Write-Host "Target STAGING_SUPABASE_URL: $supabaseUrl" -ForegroundColor Cyan
. "$PSScriptRoot/apply_verified_purchase_bypass_tests/ApplyVerifiedPurchaseBypassTests.ps1"
$context = [pscustomobject]@{ SupabaseUrl = $supabaseUrl; AnonKey = $anonKey; UserA = $userA; UserB = $userB }
Invoke-ApplyVerifiedPurchaseBypassTests -Context $context
Write-Host "Summary: PASS $script:ValidationPasses | FAIL $script:ValidationFailures | SKIP $script:ValidationSkips" -ForegroundColor Cyan
if ($script:ValidationFailures -gt 0) { exit 1 }
