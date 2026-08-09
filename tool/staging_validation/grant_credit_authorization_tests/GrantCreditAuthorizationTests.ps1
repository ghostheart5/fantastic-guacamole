Set-StrictMode -Version Latest

function Get-GrantCreditVisibleState {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Session
    )

    $wallet = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table 'monetization_wallets' -Session $Session `
        -Filters @{ user_id = $Session.UserId } -Body $null
    if (-not (Test-RestSuccess -Name "$($Session.Label): reads own wallet state" -Response $wallet)) { return $null }

    $transactions = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table 'monetization_credit_transactions' -Session $Session `
        -Filters @{ user_id = $Session.UserId } -Body $null
    if (-not (Test-RestSuccess -Name "$($Session.Label): reads own transaction state" -Response $transactions)) { return $null }

    $walletRows = @($wallet.Content | ConvertFrom-Json)
    $transactionRows = @($transactions.Content | ConvertFrom-Json)
    if ($walletRows.Count -gt 1) {
        Write-ValidationFail -Name "$($Session.Label): wallet state shape" -Detail 'Expected zero or one wallet row.'
        return $null
    }

    $walletRow = if ($walletRows.Count -eq 1) { $walletRows[0] } else { $null }
    return [pscustomobject]@{
        Balance = if ($null -eq $walletRow) { $null } else { $walletRow.balance }
        BonusBalance = if ($null -eq $walletRow) { $null } else { $walletRow.bonus_balance }
        LifetimeEarned = if ($null -eq $walletRow) { $null } else { $walletRow.lifetime_earned }
        TransactionCount = $transactionRows.Count
    }
}

function Assert-NoGrantCreditStateChange {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Before,
        [Parameter(Mandatory)]$After
    )

    if ($Before.Balance -ne $After.Balance -or $Before.BonusBalance -ne $After.BonusBalance -or
        $Before.LifetimeEarned -ne $After.LifetimeEarned -or $Before.TransactionCount -ne $After.TransactionCount) {
        Write-ValidationFail -Name $Name -Detail 'Client-visible wallet balance or transaction state changed after denied grant attempts.'
        return
    }
    Write-ValidationPass -Name $Name
}

function Invoke-GrantCreditAuthorizationTests {
    param([Parameter(Mandatory)]$Context)

    $beforeA = Get-GrantCreditVisibleState -Context $Context -Session $Context.UserA
    $beforeB = Get-GrantCreditVisibleState -Context $Context -Session $Context.UserB
    if ($null -eq $beforeA -or $null -eq $beforeB) { return }

    $arguments = @{
        credit_amount = 1
        transaction_type = 'authorization_probe'
        transaction_source = 'staging_validation'
        transaction_description = 'Expected authorization denial'
        metadata = @{ probe = 'grant_credit_denial' }
    }
    $testCases = @(
        @{ Name = 'Anonymous caller cannot grant credits'; Token = $null; Target = $Context.UserA.UserId },
        @{ Name = 'User A cannot grant credits to User A'; Token = $Context.UserA.AccessToken; Target = $Context.UserA.UserId },
        @{ Name = 'User A cannot grant credits to User B'; Token = $Context.UserA.AccessToken; Target = $Context.UserB.UserId },
        @{ Name = 'User B cannot grant credits to User B'; Token = $Context.UserB.AccessToken; Target = $Context.UserB.UserId },
        @{ Name = 'User B cannot grant credits to User A'; Token = $Context.UserB.AccessToken; Target = $Context.UserA.UserId }
    )
    foreach ($testCase in $testCases) {
        $arguments.target_user_id = $testCase.Target
        $response = Invoke-StagingRpc -SupabaseUrl $Context.SupabaseUrl -AnonKey $Context.AnonKey `
            -RpcName 'grant_monetization_credits' -AccessToken $testCase.Token -Arguments $arguments
        Assert-RpcFailure -Name $testCase.Name -Response $response
    }

    $afterA = Get-GrantCreditVisibleState -Context $Context -Session $Context.UserA
    $afterB = Get-GrantCreditVisibleState -Context $Context -Session $Context.UserB
    if ($null -ne $afterA) {
        Assert-NoGrantCreditStateChange -Name 'User A has no unauthorized wallet balance increase or transaction row' -Before $beforeA -After $afterA
    }
    if ($null -ne $afterB) {
        Assert-NoGrantCreditStateChange -Name 'User B has no unauthorized wallet balance increase or transaction row' -Before $beforeB -After $afterB
    }
}