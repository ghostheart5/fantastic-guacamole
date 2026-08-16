throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

Set-StrictMode -Version Latest

function Get-ApplyVerifiedPurchaseVisibleState {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Session
    )

    $wallet = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table 'monetization_wallets' -Session $Session `
        -Filters @{ user_id = $Session.UserId } -Body $null
    $purchases = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table 'monetization_purchases' -Session $Session `
        -Filters @{ user_id = $Session.UserId } -Body $null
    $events = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table 'monetization_entitlement_events' -Session $Session `
        -Filters @{ user_id = $Session.UserId } -Body $null
    if (-not (Test-RestSuccess -Name "$($Session.Label): reads own wallet baseline" -Response $wallet) -or
        -not (Test-RestSuccess -Name "$($Session.Label): reads own purchase baseline" -Response $purchases) -or
        -not (Test-RestSuccess -Name "$($Session.Label): reads own entitlement baseline" -Response $events)) {
        return $null
    }

    $walletRows = @($wallet.Content | ConvertFrom-Json)
    if ($walletRows.Count -gt 1) {
        Write-ValidationFail -Name "$($Session.Label): wallet state shape" -Detail 'Expected zero or one wallet row.'
        return $null
    }
    $walletRow = if ($walletRows.Count -eq 1) { $walletRows[0] } else { $null }
    return [pscustomobject]@{
        Balance = if ($null -eq $walletRow) { $null } else { $walletRow.balance }
        BonusBalance = if ($null -eq $walletRow) { $null } else { $walletRow.bonus_balance }
        LifetimeEarned = if ($null -eq $walletRow) { $null } else { $walletRow.lifetime_earned }
        PurchaseCount = @($purchases.Content | ConvertFrom-Json).Count
        EntitlementEventCount = @($events.Content | ConvertFrom-Json).Count
    }
}

function Assert-NoApplyVerifiedPurchaseStateChange {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Before,
        [Parameter(Mandatory)]$After
    )

    if ($Before.Balance -ne $After.Balance -or $Before.BonusBalance -ne $After.BonusBalance -or
        $Before.LifetimeEarned -ne $After.LifetimeEarned -or $Before.PurchaseCount -ne $After.PurchaseCount -or
        $Before.EntitlementEventCount -ne $After.EntitlementEventCount) {
        Write-ValidationFail -Name $Name -Detail 'A failed direct RPC call changed client-visible wallet, purchase, or entitlement state.'
        return
    }
    Write-ValidationPass -Name $Name
}

function Invoke-ApplyVerifiedPurchaseBypassTests {
    param([Parameter(Mandatory)]$Context)

    $beforeA = Get-ApplyVerifiedPurchaseVisibleState -Context $Context -Session $Context.UserA
    $beforeB = Get-ApplyVerifiedPurchaseVisibleState -Context $Context -Session $Context.UserB
    if ($null -eq $beforeA -or $null -eq $beforeB) { return }

    $testCases = @(
        @{ Name = 'Anonymous caller cannot apply a verified purchase'; Token = $null; Target = $Context.UserA.UserId },
        @{ Name = 'User A cannot apply a purchase to User A'; Token = $Context.UserA.AccessToken; Target = $Context.UserA.UserId },
        @{ Name = 'User A cannot apply a purchase to User B'; Token = $Context.UserA.AccessToken; Target = $Context.UserB.UserId },
        @{ Name = 'User B cannot apply a purchase to User B'; Token = $Context.UserB.AccessToken; Target = $Context.UserB.UserId },
        @{ Name = 'User B cannot apply a purchase to User A'; Token = $Context.UserB.AccessToken; Target = $Context.UserA.UserId }
    )
    foreach ($testCase in $testCases) {
        $marker = [guid]::NewGuid().ToString('N')
        $response = Invoke-StagingRpc -SupabaseUrl $Context.SupabaseUrl -AnonKey $Context.AnonKey `
            -RpcName 'apply_verified_purchase' -AccessToken $testCase.Token -Arguments @{
                target_user_id = $testCase.Target
                product_id = 'chronospark_credits_100'
                purchase_type = 'inapp'
                purchase_token_hash = "bypass-denial-$marker"
                order_id = "bypass-denial-$marker"
                verified_at = (Get-Date).ToUniversalTime().ToString('o')
                expires_at = $null
                payload = @{ probe = 'direct_rpc_bypass_denial' }
            }
        Assert-RpcFailure -Name $testCase.Name -Response $response
    }

    $afterA = Get-ApplyVerifiedPurchaseVisibleState -Context $Context -Session $Context.UserA
    $afterB = Get-ApplyVerifiedPurchaseVisibleState -Context $Context -Session $Context.UserB
    if ($null -ne $afterA) {
        Assert-NoApplyVerifiedPurchaseStateChange -Name 'User A has no unauthorized wallet, purchase, or entitlement mutation' -Before $beforeA -After $afterA
    }
    if ($null -ne $afterB) {
        Assert-NoApplyVerifiedPurchaseStateChange -Name 'User B has no unauthorized wallet, purchase, or entitlement mutation' -Before $beforeB -After $afterB
    }
}
