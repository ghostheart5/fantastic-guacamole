function Invoke-PrivilegedRpcDenialTests {
    param(
        [Parameter(Mandatory)]$UserA,
        [Parameter(Mandatory)]$UserB,
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey
    )

    foreach ($testCase in @(
        @{ Name = 'User A cannot ensure User B wallet'; Token = $UserA.AccessToken; Target = $UserB.UserId; Rpc = 'ensure_monetization_wallet' },
        @{ Name = 'User B cannot ensure User A wallet'; Token = $UserB.AccessToken; Target = $UserA.UserId; Rpc = 'ensure_monetization_wallet' },
        @{ Name = 'User A cannot reset User B allowance'; Token = $UserA.AccessToken; Target = $UserB.UserId; Rpc = 'reset_monetization_allowance' },
        @{ Name = 'User B cannot reset User A allowance'; Token = $UserB.AccessToken; Target = $UserA.UserId; Rpc = 'reset_monetization_allowance' },
        @{ Name = 'Anonymous caller cannot ensure a wallet'; Token = $null; Target = $UserA.UserId; Rpc = 'ensure_monetization_wallet' },
        @{ Name = 'Anonymous caller cannot reset an allowance'; Token = $null; Target = $UserA.UserId; Rpc = 'reset_monetization_allowance' }
    )) {
        $response = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey -RpcName $testCase.Rpc `
            -AccessToken $testCase.Token -Arguments @{ target_user_id = $testCase.Target }
        Assert-RpcFailure -Name $testCase.Name -Response $response
    }

    Write-ValidationSkip -Name 'grant_monetization_credits denial' `
        -Detail 'BLOCKED: local signature is known, but staging-effective service/admin-only authorization is not confirmed.'
    Write-ValidationSkip -Name 'apply_verified_purchase denial' `
        -Detail 'Not generated: receipt application is server-only and belongs to the blocked receipt-validation category.'
}