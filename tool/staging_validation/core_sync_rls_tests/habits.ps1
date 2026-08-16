throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-HabitsRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'habits' -UpdatePayload @{ title = 'cross-user mutation attempt' } `
        -PayloadFactory { param($userId, $key) @{ user_id = $userId; id = $key; title = 'RLS test habit' } } `
        -LocatorFactory { param($userId, $key) @{ user_id = $userId; id = $key } }
}
