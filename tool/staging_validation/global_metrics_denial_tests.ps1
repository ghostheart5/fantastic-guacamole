throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-GlobalMetricsDenialTests {
    param(
        [Parameter(Mandatory)]$UserA,
        [Parameter(Mandatory)]$UserB,
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey
    )

    foreach ($testCase in @(
        @{ Name = 'Global metrics rejects anonymous caller'; Token = $null },
        @{ Name = 'Global metrics rejects normal authenticated User A'; Token = $UserA.AccessToken },
        @{ Name = 'Global metrics rejects normal authenticated User B'; Token = $UserB.AccessToken }
    )) {
        $response = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
            -RpcName 'get_global_metrics' -AccessToken $testCase.Token
        Assert-RpcFailure -Name $testCase.Name -Response $response
    }
}
