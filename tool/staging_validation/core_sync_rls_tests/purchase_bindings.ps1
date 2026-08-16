throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-PurchaseBindingsRlsTests {
    param([Parameter(Mandatory)]$Context)

    Invoke-CoreSyncRlsTableTests -Context $Context -Table 'purchase_bindings' -UpdatePayload @{ product_id = 'rls-test-product-updated' } `
        -PayloadFactory { param($userId, $key) @{ token_hash = "rls-$key"; user_id = $userId; product_id = 'rls-test-product' } } `
        -LocatorFactory { param($userId, $key) @{ token_hash = "rls-$key"; user_id = $userId } }
}
