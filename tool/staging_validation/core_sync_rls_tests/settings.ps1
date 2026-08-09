function Invoke-SettingsRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'settings' -UpdatePayload @{ theme_mode = 'system' } -RequiresEmptyOwnershipSlot `
        -PayloadFactory { param($userId, $key) @{ user_id = $userId; id = 'default' } } `
        -LocatorFactory { param($userId, $key) @{ user_id = $userId; id = 'default' } }
}