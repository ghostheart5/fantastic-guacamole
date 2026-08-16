throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

function Invoke-MonetizationPurchasesReadIsolationTests {
    param([Parameter(Mandatory)]$Context)
    Invoke-MonetizationReadIsolationTest -Context $Context -Table 'monetization_purchases'
}
