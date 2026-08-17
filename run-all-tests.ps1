[CmdletBinding()]
param(
    [string]$Config = "$PSScriptRoot\test-orchestrator.json",
    [switch]$AllowConnectedDevice,
    [switch]$SkipMonkey,
    [switch]$SkipMaestro,
    [switch]$SkipSimulator,
    [switch]$KeepGoing
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:Started = Get-Date
$script:Results = [System.Collections.Generic.List[object]]::new()

function Read-Config {
    if (-not (Test-Path -LiteralPath $Config)) { throw "Config file not found: $Config" }
    return Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
}

function Resolve-CommandPath([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Resolve-AndroidTool([string]$Name) {
    $path = Resolve-CommandPath $Name
    if ($path) { return $path }
    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    $candidate = Join-Path $sdkRoot ("platform-tools\$Name.exe")
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $candidate = Join-Path $sdkRoot ("emulator\$Name.exe")
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $null
}

function Invoke-Stage([string]$Name, [string]$Command, [string[]]$Arguments, [string]$WorkingDirectory, [bool]$Optional = $false) {
    $stageStart = Get-Date
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    Write-Host ("{0} {1}" -f $Command, ($Arguments -join ' ')) -ForegroundColor DarkGray
    try {
        Push-Location -LiteralPath $WorkingDirectory
        & $Command @Arguments
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        $status = if ($exitCode -eq 0) { 'passed' } else { 'failed' }
    } catch {
        $exitCode = 1
        $status = 'failed'
        Write-Host $_ -ForegroundColor Red
    } finally {
        Pop-Location
    }
    $script:Results.Add([pscustomobject]@{
        Stage = $Name; Status = $status; ExitCode = $exitCode
        Duration = ((Get-Date) - $stageStart).ToString('hh\:mm\:ss')
    })
    if ($exitCode -ne 0 -and -not $KeepGoing -and -not $Optional) {
        throw "Stage failed: $Name (exit code $exitCode)"
    }
    if ($exitCode -ne 0) { Write-Host "Stage did not pass: $Name" -ForegroundColor Yellow }
}

function Require-Tool([string]$Name) {
    $path = Resolve-CommandPath $Name
    if (-not $path) { throw "Required tool is not on PATH: $Name" }
    return $path
}

function Find-FlutterProject([string]$ConfiguredRoot) {
    $root = if ($ConfiguredRoot) { (Resolve-Path -LiteralPath $ConfiguredRoot).Path } else { (Get-Location).Path }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) {
        throw "No pubspec.yaml found at $root. Run this from the Flutter project root or set projectRoot in the config."
    }
    return $root
}

$cfg = Read-Config
$projectRoot = Find-FlutterProject $cfg.projectRoot
$logRoot = Join-Path $projectRoot ("test-results\orchestrator-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
Start-Transcript -LiteralPath (Join-Path $logRoot 'run.log') -Force | Out-Null

try {
    $flutter = Require-Tool 'flutter'
    $dart = Require-Tool 'dart'

    Invoke-Stage '1. Dependency and static analysis' $flutter @('pub','get') $projectRoot
    Invoke-Stage '2. Dart unit and widget tests' $flutter @('test') $projectRoot

    $integrationDir = Join-Path $projectRoot 'integration_test'
    if (Test-Path -LiteralPath $integrationDir) {
        Invoke-Stage '3. Flutter integration tests' $flutter @('test','integration_test') $projectRoot
    } else {
        Write-Host 'Skipping Flutter integration tests: integration_test\ not found.' -ForegroundColor Yellow
    }

    if (-not $SkipMaestro) {
        $maestro = Resolve-CommandPath 'maestro'
        $maestroDir = if ($cfg.maestroDirectory) { Join-Path $projectRoot $cfg.maestroDirectory } else { Join-Path $projectRoot 'maestro' }
        if ($maestro -and (Test-Path -LiteralPath $maestroDir)) {
            Invoke-Stage '4. Maestro end-to-end flows' $maestro @('test', $maestroDir) $projectRoot
        } else {
            Write-Host 'Skipping Maestro: CLI or maestro\ directory not found.' -ForegroundColor Yellow
        }
    }

    if (-not $SkipSimulator) {
        $simulator = Resolve-AndroidTool 'adb'
        if (-not $simulator) { $simulator = Resolve-AndroidTool 'emulator' }
        if ($simulator) {
            Invoke-Stage '5. Connected simulator/device smoke check' $flutter @('devices') $projectRoot
            $deviceArgs = @('test','integration_test','-d',$cfg.deviceId)
            if ($cfg.deviceId -and $cfg.deviceId -ne 'auto') { Invoke-Stage '6. Device-targeted smoke tests' $flutter $deviceArgs $projectRoot }
        } else {
            Write-Host 'Skipping simulator stage: adb/emulator not found.' -ForegroundColor Yellow
        }
    }

    if (-not $SkipMonkey -and $cfg.monkey.package) {
        if (-not $AllowConnectedDevice) { throw 'Monkey testing is disabled by default. Re-run with -AllowConnectedDevice after confirming the target device.' }
        $adb = Resolve-AndroidTool 'adb'
        if (-not $adb) { throw 'Android adb.exe was not found. Set ANDROID_HOME/ANDROID_SDK_ROOT or install Android SDK Platform-Tools.' }
        $monkeyArgs = @('shell','monkey','-p',$cfg.monkey.package,'-s',[string]$cfg.monkey.seed,'--throttle',[string]$cfg.monkey.throttleMs,'-v',[string]$cfg.monkey.events)
        Invoke-Stage '7. Bounded Android monkey test' $adb $monkeyArgs $projectRoot
    }

    $failed = @($script:Results | Where-Object Status -eq 'failed')
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    $script:Results | Format-Table -AutoSize
    Write-Host "Logs: $logRoot"
    if ($failed.Count -gt 0) { exit 1 }
} finally {
    Stop-Transcript | Out-Null
}
