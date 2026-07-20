Write-Host "ChronoSpark Simple Check Starting..."

$LogFile = "chronospark_simple_check_log.txt"

"ChronoSpark Simple Check" | Out-File $LogFile
"Date: $(Get-Date)" | Out-File $LogFile -Append
"Folder: $(Get-Location)" | Out-File $LogFile -Append

function Run-Step {
    param(
        [string]$Name,
        [string]$Command
    )

    Write-Host ""
    Write-Host "Running: $Name"
    Write-Host "Command: $Command"

    "`n==============================" | Out-File $LogFile -Append
    $Name | Out-File $LogFile -Append
    "COMMAND: $Command" | Out-File $LogFile -Append
    "==============================" | Out-File $LogFile -Append

    cmd /c $Command 2>&1 | Tee-Object -FilePath $LogFile -Append
}

Run-Step "Current Folder" "cd"
Run-Step "Directory List" "dir"
Run-Step "Git Status" "git status"
Run-Step "Flutter Version" "flutter --version"
Run-Step "Flutter Doctor" "flutter doctor -v"
Run-Step "Flutter Pub Get" "flutter pub get"
Run-Step "Flutter Analyze" "flutter analyze"

Write-Host ""
Write-Host "Done. Log saved to:"
Write-Host $LogFile