throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-SettingsRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'settings' -UpdatePayload @{ theme_mode = 'system' } -RequiresEmptyOwnershipSlot `
        -PayloadFactory { param($userId, $key) @{ user_id = $userId; id = 'default' } } `
        -LocatorFactory { param($userId, $key) @{ user_id = $userId; id = 'default' } }
}
