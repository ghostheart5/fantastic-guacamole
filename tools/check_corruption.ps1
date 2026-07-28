$ErrorActionPreference = "Continue"

$failed = $false

function Pass($msg) {
    Write-Host "[PASS] $msg" -ForegroundColor Green
}

function Fail($msg) {
    Write-Host "[FAIL] $msg" -ForegroundColor Red
    $script:failed = $true
}

function Warn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Fantastic Guacamole Corruption Check ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path ".\pubspec.yaml")) {
    Fail "pubspec.yaml not found. Run this from the project root."
    exit 1
}

Pass "pubspec.yaml found"

Write-Host ""
Write-Host "Checking for merge conflict markers..." -ForegroundColor Cyan

$conflictFiles = Get-ChildItem -Recurse -File -Include *.dart,*.yaml,*.yml,*.json,*.md,*.txt |
    Where-Object {
        $_.FullName -notmatch "\\.git\\" -and
        $_.FullName -notmatch "\\build\\" -and
        $_.FullName -notmatch "\\.dart_tool\\"
    }

$conflicts = $conflictFiles | Select-String -Pattern "<<<<<<<|=======|>>>>>>>" -ErrorAction SilentlyContinue

if ($conflicts) {
    $conflicts | ForEach-Object {
        Write-Host "$($_.Path):$($_.LineNumber): $($_.Line)" -ForegroundColor Red
    }
    Fail "Merge conflict markers found."
} else {
    Pass "No merge conflict markers found."
}

Write-Host ""
Write-Host "Checking for empty Dart files..." -ForegroundColor Cyan

$emptyFiles = Get-ChildItem .\lib, .\test -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -eq 0 }

if ($emptyFiles) {
    $emptyFiles | ForEach-Object {
        Write-Host $_.FullName -ForegroundColor Red
    }
    Fail "Empty Dart files found."
} else {
    Pass "No empty Dart files found."
}

Write-Host ""
Write-Host "Checking for null bytes in Dart files..." -ForegroundColor Cyan

$nullFiles = @()

Get-ChildItem .\lib, .\test -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if ($bytes -contains 0) {
            $nullFiles += $_.FullName
        }
    } catch {
        $nullFiles += $_.FullName
    }
}

if ($nullFiles.Count -gt 0) {
    $nullFiles | ForEach-Object {
        Write-Host $_ -ForegroundColor Red
    }
    Fail "Null bytes or unreadable Dart files found."
} else {
    Pass "No null bytes found."
}

Write-Host ""
Write-Host "Checking for suspicious control characters..." -ForegroundColor Cyan

$badControlFiles = @()

Get-ChildItem .\lib, .\test -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $text = Get-Content $_.FullName -Raw -ErrorAction Stop
        foreach ($char in $text.ToCharArray()) {
            $code = [int][char]$char
            if (($code -lt 32) -and ($code -ne 9) -and ($code -ne 10) -and ($code -ne 13)) {
                $badControlFiles += $_.FullName
                break
            }
        }
    } catch {
        $badControlFiles += $_.FullName
    }
}

if ($badControlFiles.Count -gt 0) {
    $badControlFiles | Sort-Object -Unique | ForEach-Object {
        Write-Host $_ -ForegroundColor Red
    }
    Fail "Suspicious control characters or unreadable files found."
} else {
    Pass "No suspicious control characters found."
}

Write-Host ""
Write-Host "Checking for backup/temp/reject files..." -ForegroundColor Cyan

$suspicious = Get-ChildItem -Recurse -File |
    Where-Object {
        $_.FullName -notmatch "\\.git\\" -and
        $_.FullName -notmatch "\\build\\" -and
        $_.FullName -notmatch "\\.dart_tool\\" -and
        (
            $_.Name -match "\.bak$" -or
            $_.Name -match "\.tmp$" -or
            $_.Name -match "\.orig$" -or
            $_.Name -match "\.rej$" -or
            $_.Name -match "~$"
        )
    }

if ($suspicious) {
    $suspicious | ForEach-Object {
        Write-Host $_.FullName -ForegroundColor Yellow
    }
    Warn "Suspicious backup/temp files found."
} else {
    Pass "No suspicious backup/temp files found."
}

Write-Host ""
Write-Host "Running flutter pub get..." -ForegroundColor Cyan

flutter pub get
if ($LASTEXITCODE -ne 0) {
    Fail "flutter pub get failed."
} else {
    Pass "flutter pub get passed."
}

Write-Host ""
Write-Host "Running Dart parser/format check..." -ForegroundColor Cyan

dart format --output=none --set-exit-if-changed lib test
$formatExit = $LASTEXITCODE

if ($formatExit -eq 65) {
    Fail "Dart syntax corruption detected."
} elseif ($formatExit -ne 0) {
    Warn "Dart files need formatting."
} else {
    Pass "Dart parser check passed."
}

Write-Host ""
Write-Host "Running flutter analyze..." -ForegroundColor Cyan

flutter analyze
if ($LASTEXITCODE -ne 0) {
    Fail "flutter analyze failed."
} else {
    Pass "flutter analyze passed."
}

Write-Host ""
Write-Host "Running flutter test..." -ForegroundColor Cyan

flutter test
if ($LASTEXITCODE -ne 0) {
    Fail "flutter test failed."
} else {
    Pass "flutter test passed."
}

Write-Host ""
Write-Host "Checking git status..." -ForegroundColor Cyan

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitStatus = git status --short
    if ($gitStatus) {
        $gitStatus
        Warn "Git working tree has changes."
    } else {
        Pass "Git working tree clean."
    }
} else {
    Warn "Git not installed or not available in PATH."
}

Write-Host ""
Write-Host "=== Corruption Check Complete ===" -ForegroundColor Cyan

if ($failed) {
    Write-Host "RESULT: CORRUPTION OR BREAKAGE FOUND" -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: NO CORRUPTION FOUND" -ForegroundColor Green
    exit 0
}
