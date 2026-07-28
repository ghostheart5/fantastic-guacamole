$ErrorActionPreference = 'Stop'

$screen = 'lib\features\home\ui\smart_coach_screen.dart'
$hero = 'lib\features\home\ui\widgets\smart_coach_hero.dart'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

Copy-Item $screen "$screen.bak_progression_cleanup_$stamp" -Force
Copy-Item $hero "$hero.bak_progression_cleanup_$stamp" -Force

$s = Get-Content $screen -Raw

$s = $s -replace "(?m)^\s*final String modelProgressionFeedback = decision\?\.progressionFeedback \?\? '';\r?\n", ""
$s = $s -replace "(?m)^\s*progressionFeedback: modelProgressionFeedback,\r?\n", ""
$s = $s -replace "(?m)^\s*const _ProgressionBanner\(\),\r?\n\s*const SizedBox\(height: 12\),\r?\n", ""
$s = $s -replace "(?m)^\s*modelProgressionFeedback\.trim\(\)*.isNotEmpty \|\|\r?\n", ""
$s = $s -replace "(?ms)^\s*if \(modelProgressionFeedback\.trim\(\)\.isNotEmpty\) \.\.\.\[\r?\n.*?^\s*\],\r?\n", ""
$s = $s -replace "(?ms)\r?\n// .*Progression banner.*?\r?\n\s*class _ProgressionBanner extends ConsumerWidget.*?(?=\r?\nclass _QuickNavRow)", ""

[System.IO.File]::WriteAllText((Resolve-Path $screen), $s, [System.Text.UTF8Encoding]::new($false))

$h = Get-Content $hero -Raw

$h = $h -replace "(?m)^\s*required this\.progressionFeedback,\r?\n", ""
$h = $h -replace "(?m)^\s*final String progressionFeedback;\r?\n", ""
$h = $h -replace "(?ms)^\s*if \(progressionFeedback\.trim\(\)\.isNotEmpty\) \.\.\.\[\r?\n.*?^\s*\],\r?\n", ""

[System.IO.File]::WriteAllText((Resolve-Path $hero), $h, [System.Text.UTF8Encoding]::new($false))

dart format $screen $hero

Write-Host ''
Write-Host 'DONE smart coach progression UI cleanup'
Write-Host "Backups:"
Write-Host "$screen.bak_progression_cleanup_$stamp"
Write-Host "$hero.bak_progression_cleanup_$stamp"
Write-Host ''
Write-Host 'Verify with:'
Write-Host 'Select-String -Path lib\features\home\ui\smart_coach_screen.dart,lib\features\home\ui\widgets\smart_coach_hero.dart -Pattern "_ProgressionBanner|Progression Feedback|PROGRESSION SIGNAL|progressionFeedback|modelProgressionFeedback"'
Write-Host ''
Write-Host 'Then run: flutter analyze'
