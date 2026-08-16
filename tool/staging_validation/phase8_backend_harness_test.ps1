throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/StagingValidation.Common.ps1"

$script:Passed = 0

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Name)
    if (-not $Condition) { throw "ASSERTION_FAILED:$Name" }
    $script:Passed++
    Write-Host "PASS  $Name" -ForegroundColor Green
}

function Assert-ThrowsCode {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Name
    )
    try {
        & $Action
    }
    catch {
        Assert-True -Condition ($_.Exception.Message -eq $Code) -Name $Name
        return
    }
    throw "ASSERTION_FAILED:$Name"
}

$approvedUrl = 'https://retired-staging-project.invalid'
Assert-ThrowsCode -Action {
    Assert-ApprovedStagingTarget -SupabaseUrl $approvedUrl -ConfirmStaging $false
} -Code 'STAGING_CONFIRMATION_REQUIRED' -Name 'staging confirmation is mandatory'
Assert-ThrowsCode -Action {
    Assert-ApprovedStagingTarget -SupabaseUrl 'https://example.supabase.co' -ConfirmStaging $true
} -Code 'STAGING_TARGET_REFUSED' -Name 'unknown Supabase host is refused'
Assert-ThrowsCode -Action {
    Assert-ApprovedStagingTarget -SupabaseUrl 'http://retired-staging-project.invalid' -ConfirmStaging $true
} -Code 'STAGING_TARGET_REFUSED' -Name 'non-HTTPS staging target is refused'
Assert-ThrowsCode -Action {
    Assert-ApprovedStagingTarget -SupabaseUrl "$approvedUrl/rest/v1" -ConfirmStaging $true
} -Code 'STAGING_TARGET_REFUSED' -Name 'non-base staging URL is refused'
Assert-ThrowsCode -Action {
    Assert-ApprovedStagingTarget -SupabaseUrl $approvedUrl -ConfirmStaging $true -ExpectedHost 'other.supabase.co'
} -Code 'STAGING_HOST_NOT_APPROVED' -Name 'caller cannot substitute the approved hostname'
Assert-ApprovedStagingTarget -SupabaseUrl $approvedUrl -ConfirmStaging $true
$script:Passed++
Write-Host 'PASS  exact approved staging base URL is accepted after confirmation' -ForegroundColor Green

$runIdA = New-Phase8TestRunId
$runIdB = New-Phase8TestRunId
Assert-True -Condition ($runIdA -ne $runIdB) -Name 'test run identifiers are unique'
Assert-Phase8RunOwnedResource -ResourceIdentifier "tasks/$runIdA/row" -RunId $runIdA
$script:Passed++
Write-Host 'PASS  cleanup accepts only a run-owned resource' -ForegroundColor Green
Assert-ThrowsCode -Action {
    Assert-Phase8RunOwnedResource -ResourceIdentifier 'tasks/unrelated/row' -RunId $runIdA
} -Code 'CLEANUP_RESOURCE_NOT_RUN_OWNED' -Name 'cleanup refuses unrelated resources'
Assert-ThrowsCode -Action {
    Assert-Phase8RunOwnedResource -ResourceIdentifier "tasks/*/$runIdA" -RunId $runIdA
} -Code 'CLEANUP_RESOURCE_NOT_RUN_OWNED' -Name 'cleanup refuses wildcard resources'

$diagnostic = Get-SafeDiagnosticText -Text 'Authorization: Bearer eyJabc.def.ghi password=unsafe token=unsafe secret=unsafe'
Assert-True -Condition (
    $diagnostic -notmatch 'eyJabc|unsafe' -and
    $diagnostic -match '\[REDACTED\]'
) -Name 'diagnostics redact tokens, passwords, and secrets'

$originalSecret = [Environment]::GetEnvironmentVariable('STAGING_SUPABASE_SERVICE_ROLE_KEY')
try {
    [Environment]::SetEnvironmentVariable('STAGING_SUPABASE_SERVICE_ROLE_KEY', 'test-only-secret', 'Process')
    Assert-ThrowsCode -Action {
        Assert-NoClientPrivilegedSecrets
    } -Code 'CLIENT_PRIVILEGED_SECRET_REFUSED:STAGING_SUPABASE_SERVICE_ROLE_KEY' `
        -Name 'client harness refuses a service-role secret'
}
finally {
    [Environment]::SetEnvironmentVariable('STAGING_SUPABASE_SERVICE_ROLE_KEY', $originalSecret, 'Process')
}

Write-Host "Completed $script:Passed offline staging-guard assertions." -ForegroundColor Cyan
