[CmdletBinding()]
param(
    [switch]$ConfirmStaging,
    [switch]$ApproveMutationTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../core_sync_rls_tests/CoreSyncRls.TestSupport.ps1"
. "$PSScriptRoot/MonetizationReadIsolation.TestSupport.ps1"
$context = New-CoreSyncRlsContext -ConfirmStaging $ConfirmStaging -ApproveMutationTests $ApproveMutationTests

foreach ($testFile in @(
    'monetization_subscription_statuses.ps1',
    'monetization_wallets.ps1',
    'monetization_credit_transactions.ps1',
    'monetization_purchases.ps1',
    'monetization_entitlement_events.ps1'
)) {
    . "$PSScriptRoot/$testFile"
}

Invoke-MonetizationSubscriptionStatusesReadIsolationTests -Context $context
Invoke-MonetizationWalletsReadIsolationTests -Context $context
Invoke-MonetizationCreditTransactionsReadIsolationTests -Context $context
Invoke-MonetizationPurchasesReadIsolationTests -Context $context
Invoke-MonetizationEntitlementEventsReadIsolationTests -Context $context

if ($script:ValidationFailures -gt 0) { exit 1 }