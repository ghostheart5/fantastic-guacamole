$root = ".\lib"

Write-Host ""
Write-Host "=== SCREEN AUDIT ===" -ForegroundColor Cyan
Write-Host ""

$screens = Get-ChildItem $root -Recurse -Filter "*screen.dart"

$results = foreach ($screen in $screens) {
    $name = $screen.BaseName
    $path = $screen.FullName

    $refs = Get-ChildItem $root -Recurse -Filter "*.dart" |
        Select-String -Pattern $name -SimpleMatch |
        Where-Object { $_.Path -ne $path }

    [PSCustomObject]@{
        Screen     = $name
        References = ($refs | Measure-Object).Count
        File       = $path
    }
}

Write-Host "USED SCREENS" -ForegroundColor Green
$results |
    Where-Object { $_.References -gt 0 } |
    Sort-Object References -Descending |
    Format-Table -AutoSize

Write-Host ""
Write-Host "POSSIBLY UNUSED SCREENS" -ForegroundColor Yellow

$results |
    Where-Object { $_.References -eq 0 } |
    Sort-Object Screen |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Total Screens:" $results.Count
Write-Host "Unused Screens:" (($results | Where-Object {$_.References -eq 0}).Count)