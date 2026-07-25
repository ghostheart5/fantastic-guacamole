$ErrorActionPreference = "Stop"

Write-Host "Upgrading CreatorScreen into unified future Creator workbench..." -ForegroundColor Cyan

# Find CreatorScreen file automatically.
$creatorFile = Get-ChildItem -Path .\lib -Recurse -Filter *.dart |
  Select-String -Pattern "class CreatorScreen extends ConsumerWidget" |
  Select-Object -First 1 -ExpandProperty Path

if (-not $creatorFile) {
  throw "Could not find CreatorScreen file."
}

Write-Host "Found CreatorScreen: $creatorFile" -ForegroundColor Green

$text = Get-Content $creatorFile -Raw

# Update subtitle from old optional language to future unified module language.
$text = $text -replace "'OPTIONAL ENTRY FORGE'", "'TASK · GOAL · PLAN FORGE'"

# Update snack message.
$text = $text -replace "content:\s*Text\('Entry created\.'\)", "content: Text('Creator updated.')"

# Remove old redirect to Plan after creating an entry.
$text = $text -replace "\s*ref\.read\(appFlowProvider\.notifier\)\.toPlan\(\);\s*", "`r`n                      // Stay in Creator: tasks, goals, and planning now live here.`r`n"

# Replace old purpose card copy.
$oldPurpose = "'Creator is optional\. Use Smart Coach, Day Plan, and Flowmap for guided workflows\. Use Creator when you want direct, manual task forging\.'"

$newPurpose = "'Creator is the unified workbench for tasks, goals, and planning. Use it to forge new entries, connect them to goals, and shape your plan from one future-facing command surface.'"

$text = $text -replace $oldPurpose, $newPurpose

Set-Content $creatorFile $text -NoNewline

Write-Host ""
Write-Host "CreatorScreen upgraded." -ForegroundColor Green
Write-Host ""
Write-Host "Checking for old Creator wording or old Plan redirect..." -ForegroundColor Cyan

Select-String -Path $creatorFile -Pattern "OPTIONAL ENTRY FORGE|Creator is optional|toPlan\(\)|Entry created" -ErrorAction SilentlyContinue |
  Select-Object Path, LineNumber, Line

Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "flutter analyze" -ForegroundColor Yellow
