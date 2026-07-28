$ErrorActionPreference = "Stop"

$Out = "auth_monkey_login_audit.txt"
Remove-Item $Out -ErrorAction SilentlyContinue

function Add-Line($x="") {
  Add-Content -Path $Out -Value $x
}

Add-Line "CHRONOSPARK AUTH + MONKEY LOGIN AUDIT"
Add-Line "Generated: $(Get-Date)"
Add-Line "============================================================"
Add-Line ""

Add-Line "1. Mock login references"
Add-Line "------------------------------------------------------------"
Get-ChildItem lib -Recurse -Include *.dart |
  Select-String -Pattern "enableMockLogin|mockLoginEmail|mockLoginPassword|onMockLogin|MockLoginConfigState|isMockLoginEnabled|enableMockLogin" |
  ForEach-Object { Add-Line "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }

Add-Line ""
Add-Line "2. Env / dart-define keys"
Add-Line "------------------------------------------------------------"
Get-ChildItem lib -Recurse -Include *.dart |
  Select-String -Pattern "String\.fromEnvironment|bool\.fromEnvironment|CHRONOSPARK|MOCK|SUPABASE|AUTH" |
  ForEach-Object { Add-Line "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }

Add-Line ""
Add-Line "3. Login screen keys/buttons"
Add-Line "------------------------------------------------------------"
Get-ChildItem lib\features\auth -Recurse -Include *.dart |
  Select-String -Pattern "ValueKey|TESTER ACCESS|COMMAND LOGIN|login-email-field|login-password-field|onTap|onPressed" |
  ForEach-Object { Add-Line "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }

Add-Line ""
Add-Line "4. Auth gateway selection"
Add-Line "------------------------------------------------------------"
Get-ChildItem lib -Recurse -Include *.dart |
  Select-String -Pattern "AlwaysAuthenticatedAuthService|CHRONOSPARK_AUTH_GATEWAY_SELECTED|authGateway|AuthService" |
  ForEach-Object { Add-Line "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }

Add-Line ""
Add-Line "5. Suggested next checks"
Add-Line "------------------------------------------------------------"
Add-Line "Open this report and look for the exact String.fromEnvironment / bool.fromEnvironment names."
Add-Line "If mock login email/password are blank, either the mock command button must work or dart-defines must supply credentials."
Add-Line "If AlwaysAuthenticatedAuthService triggers when mock mode is enabled, use that for monkey testing."

Write-Host ""
Write-Host "WROTE: $Out"
Write-Host ""
Get-Content $Out
