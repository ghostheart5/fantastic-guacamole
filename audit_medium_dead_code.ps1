$ErrorActionPreference = "Stop"

Write-Host "Auditing medium-confidence dead code..." -ForegroundColor Cyan

$patterns = @(
  "PlanEntity",
  "plan_entity.dart",
  "PlanRepository",
  "plan_repository.dart",
  "legacy_logs_provider",
  "featureFlag",
  "FeatureFlag"
)

foreach ($pattern in $patterns) {
  Write-Host ""
  Write-Host "Pattern: $pattern" -ForegroundColor Yellow

  Select-String `
    -Path .\lib\**\*.dart,.\test\**\*.dart `
    -Pattern $pattern `
    -ErrorAction SilentlyContinue |
    Select-Object Path,LineNumber,Line
}

Write-Host ""
Write-Host "Medium-confidence audit complete." -ForegroundColor Green
