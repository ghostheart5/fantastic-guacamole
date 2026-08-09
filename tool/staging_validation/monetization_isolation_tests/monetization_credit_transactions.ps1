function Invoke-MonetizationCreditTransactionsReadIsolationTests {
    param([Parameter(Mandatory)]$Context)
    Invoke-MonetizationReadIsolationTest -Context $Context -Table 'monetization_credit_transactions'
}