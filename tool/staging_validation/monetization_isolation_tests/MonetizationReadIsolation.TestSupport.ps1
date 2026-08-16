throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

Set-StrictMode -Version Latest

function Invoke-MonetizationReadIsolationTest {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Table
    )

    $readOwn = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table $Table -Session $Context.UserA `
        -Filters @{ user_id = $Context.UserA.UserId } -Body $null
    if (Test-RestSuccess -Name "${Table}: User A queries own records" -Response $readOwn) {
        if ($readOwn.Content.Trim() -eq '[]') {
            Write-ValidationSkip -Name "${Table}: User A own-record visibility" -Detail 'NO_OWN_ROW_AVAILABLE; no naturally provisioned User A row exists.'
        }
        else {
            $rows = $readOwn.Content | ConvertFrom-Json
            $foreignRow = $rows | Where-Object { $_.user_id -ne $Context.UserA.UserId } | Select-Object -First 1
            if ($null -eq $foreignRow) {
                Write-ValidationPass -Name "${Table}: User A receives only own records"
            }
            else {
                Write-ValidationFail -Name "${Table}: User A receives only own records" -Detail 'The own-record query returned a row with a different user_id.'
            }
        }
    }

    $readAByB = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table $Table -Session $Context.UserB `
        -Filters @{ user_id = $Context.UserA.UserId } -Body $null
    Test-RestDeniedOrEmpty -Name "${Table}: User B cannot read User A records" -Response $readAByB

    $readBByA = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table $Table -Session $Context.UserA `
        -Filters @{ user_id = $Context.UserB.UserId } -Body $null
    Test-RestDeniedOrEmpty -Name "${Table}: User A cannot read User B records" -Response $readBByA
}
