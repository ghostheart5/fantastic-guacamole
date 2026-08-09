function Invoke-MonetizationSubscriptionStatusesReadIsolationTests {
    param([Parameter(Mandatory)]$Context)
    Invoke-MonetizationReadIsolationTest -Context $Context -Table 'monetization_subscription_statuses'
}