throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-TasksRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'tasks' -UpdatePayload @{ title = 'cross-user mutation attempt' } `
        -PayloadFactory { param($userId, $key) @{ user_id = $userId; id = $key; title = 'RLS test task' } } `
        -LocatorFactory { param($userId, $key) @{ user_id = $userId; id = $key } }
}
