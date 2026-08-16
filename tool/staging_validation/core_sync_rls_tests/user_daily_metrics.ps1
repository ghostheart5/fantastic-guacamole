throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-UserDailyMetricsRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'user_daily_metrics' -UpdatePayload @{ tasks_created = 1 } `
        -PayloadFactory { param($userId, $key) $date = (Get-Date '2090-01-01').AddDays([Math]::Abs($key.GetHashCode()) % 10000).ToString('yyyy-MM-dd'); @{ user_id = $userId; date = $date; device_id = "rls-$key" } } `
        -LocatorFactory { param($userId, $key) $date = (Get-Date '2090-01-01').AddDays([Math]::Abs($key.GetHashCode()) % 10000).ToString('yyyy-MM-dd'); @{ user_id = $userId; date = $date } }
}
