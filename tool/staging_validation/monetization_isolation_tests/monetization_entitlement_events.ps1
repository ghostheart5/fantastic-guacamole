function Invoke-MonetizationEntitlementEventsReadIsolationTests {
    param([Parameter(Mandatory)]$Context)
    Invoke-MonetizationReadIsolationTest -Context $Context -Table 'monetization_entitlement_events'
}