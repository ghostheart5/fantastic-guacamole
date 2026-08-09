[CmdletBinding()]
param(
    [switch]$ConfirmStaging,
    [switch]$ApproveMutationTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/CoreSyncRls.TestSupport.ps1"
$context = New-CoreSyncRlsContext -ConfirmStaging $ConfirmStaging -ApproveMutationTests $ApproveMutationTests

foreach ($testFile in @('tasks.ps1', 'goals.ps1', 'habits.ps1', 'settings.ps1', 'purchase_bindings.ps1', 'user_daily_metrics.ps1')) {
    . "$PSScriptRoot/$testFile"
}

Invoke-TasksRlsTests -Context $context
Invoke-GoalsRlsTests -Context $context
Invoke-HabitsRlsTests -Context $context
Invoke-SettingsRlsTests -Context $context
Invoke-PurchaseBindingsRlsTests -Context $context
Invoke-UserDailyMetricsRlsTests -Context $context

if ($script:ValidationFailures -gt 0) { exit 1 }