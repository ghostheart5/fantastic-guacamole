function Invoke-RateLimitRpcTests {
    param(
        [Parameter(Mandatory)]$UserA,
        [Parameter(Mandatory)][string]$UserAPassword,
        [Parameter(Mandatory)][string]$UserAEmail,
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey
    )

    $secondSession = New-StagingSession -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -Email $UserAEmail -Password $UserAPassword -Label 'staging_user_a second session'
    if ($secondSession.UserId -ne $UserA.UserId) {
        throw 'Second User A login resolved to a different user ID.'
    }

    $anonymous = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'consume_ai_proxy_rate_limit' -AccessToken $null
    Assert-RpcFailure -Name 'AI rate-limit RPC rejects anonymous caller' -Response $anonymous

    Write-Host 'Rate-limit prerequisite: User A must have no calls in the preceding one-minute window.' -ForegroundColor Yellow
    for ($requestNumber = 1; $requestNumber -le 20; $requestNumber++) {
        $token = if ($requestNumber -le 10) { $UserA.AccessToken } else { $secondSession.AccessToken }
        $response = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
            -RpcName 'consume_ai_proxy_rate_limit' -AccessToken $token
        Assert-RpcSuccess -Name "AI rate-limit request $requestNumber succeeds" -Response $response | Out-Null
    }

    $overLimit = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'consume_ai_proxy_rate_limit' -AccessToken $UserA.AccessToken
    Assert-RpcFailure -Name 'AI rate-limit request 21 fails across User A sessions' -Response $overLimit
}