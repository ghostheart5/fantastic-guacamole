function Invoke-HabitsRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'habits' -UpdatePayload @{ title = 'cross-user mutation attempt' } `
        -PayloadFactory { param($userId, $key) @{ user_id = $userId; id = $key; title = 'RLS test habit' } } `
        -LocatorFactory { param($userId, $key) @{ user_id = $userId; id = $key } }
}