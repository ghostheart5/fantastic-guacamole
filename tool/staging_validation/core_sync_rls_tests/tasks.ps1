function Invoke-TasksRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'tasks' -UpdatePayload @{ title = 'cross-user mutation attempt' } `
        -PayloadFactory { param($userId, $key) @{ user_id = $userId; id = $key; title = 'RLS test task' } } `
        -LocatorFactory { param($userId, $key) @{ user_id = $userId; id = $key } }
}