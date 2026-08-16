throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

[CmdletBinding()]
param(
    [switch]$ConfirmStaging,
    [switch]$ApproveMutationTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../core_sync_rls_tests/CoreSyncRls.TestSupport.ps1"
$context = New-CoreSyncRlsContext -ConfirmStaging $ConfirmStaging -ApproveMutationTests $ApproveMutationTests

function Get-ProfileFieldValue {
    param([Parameter(Mandatory)]$Response, [Parameter(Mandatory)][string]$Field)

    $rows = $Response.Content | ConvertFrom-Json
    if ($rows.Count -ne 1) { throw 'Expected exactly one caller-owned profile row.' }
    return $rows[0].$Field
}

$profileAFilter = @{ id = $context.UserA.UserId }
$profileBFilter = @{ id = $context.UserB.UserId }
$readOwn = Invoke-StagingRestRequest -Method 'GET' -Context $context -Table 'profiles' -Session $context.UserA -Filters $profileAFilter -Body $null
if (-not (Test-RestSuccess -Name 'profiles: User A reads own profile' -Response $readOwn)) { exit 1 }
$originalAFullName = Get-ProfileFieldValue -Response $readOwn -Field 'full_name'

$readAByB = Invoke-StagingRestRequest -Method 'GET' -Context $context -Table 'profiles' -Session $context.UserB -Filters $profileAFilter -Body $null
Test-RestDeniedOrEmpty -Name 'profiles: User B cannot read User A profile' -Response $readAByB

$updateAByB = Invoke-StagingRestRequest -Method 'PATCH' -Context $context -Table 'profiles' -Session $context.UserB -Filters $profileAFilter `
    -Body @{ full_name = "RLS mutation probe $([guid]::NewGuid().ToString('N'))" }
Test-RestDeniedOrEmpty -Name 'profiles: User B cannot update User A profile' -Response $updateAByB
Invoke-StagingRestRequest -Method 'PATCH' -Context $context -Table 'profiles' -Session $context.UserA -Filters $profileAFilter -Body @{ full_name = $originalAFullName } | Out-Null

$readB = Invoke-StagingRestRequest -Method 'GET' -Context $context -Table 'profiles' -Session $context.UserB -Filters $profileBFilter -Body $null
if (-not (Test-RestSuccess -Name 'profiles: User B reads own profile for restoration' -Response $readB)) { exit 1 }
$originalBFullName = Get-ProfileFieldValue -Response $readB -Field 'full_name'

$writeBByA = Invoke-StagingRestRequest -Method 'PATCH' -Context $context -Table 'profiles' -Session $context.UserA -Filters $profileBFilter `
    -Body @{ full_name = "RLS mutation probe $([guid]::NewGuid().ToString('N'))" }
Test-RestDeniedOrEmpty -Name 'profiles: User A cannot write User B profile' -Response $writeBByA
Invoke-StagingRestRequest -Method 'PATCH' -Context $context -Table 'profiles' -Session $context.UserB -Filters $profileBFilter -Body @{ full_name = $originalBFullName } | Out-Null

$writeAByB = Invoke-StagingRestRequest -Method 'PATCH' -Context $context -Table 'profiles' -Session $context.UserB -Filters $profileAFilter `
    -Body @{ full_name = "RLS mutation probe $([guid]::NewGuid().ToString('N'))" }
Test-RestDeniedOrEmpty -Name 'profiles: User B cannot write User A profile' -Response $writeAByB
Invoke-StagingRestRequest -Method 'PATCH' -Context $context -Table 'profiles' -Session $context.UserA -Filters $profileAFilter -Body @{ full_name = $originalAFullName } | Out-Null

if ($script:ValidationFailures -gt 0) { exit 1 }
