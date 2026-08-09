function Invoke-CreditDebitTests {
    param(
        [Parameter(Mandatory)]$UserA,
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey
    )

    $reason = 'staging validation'
    $metadata = @{}

    $zero = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'consume_monetization_credits' -AccessToken $UserA.AccessToken `
        -Arguments @{ credit_amount = 0; reason = $reason; metadata = $metadata }
    Assert-RpcFailure -Name 'Credit debit rejects zero amount' -Response $zero

    $negative = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'consume_monetization_credits' -AccessToken $UserA.AccessToken `
        -Arguments @{ credit_amount = -1; reason = $reason; metadata = $metadata }
    Assert-RpcFailure -Name 'Credit debit rejects negative amount' -Response $negative

    $anonymous = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'consume_monetization_credits' -AccessToken $null `
        -Arguments @{ credit_amount = 1; reason = $reason; metadata = $metadata }
    Assert-RpcFailure -Name 'Credit debit rejects anonymous caller' -Response $anonymous

    Write-ValidationSkip -Name 'Credit debit succeeds and decrements exactly once' `
        -Detail 'NEEDS_SEED_OR_ADMIN_SETUP: no approved wallet balance setup or cleanup path is confirmed.'
    Write-ValidationSkip -Name 'Credit debit insufficient balance preserves wallet' `
        -Detail 'NEEDS_SEED_OR_ADMIN_SETUP: testing this safely requires a known isolated wallet balance.'
}