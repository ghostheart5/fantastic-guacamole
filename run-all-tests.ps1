[CmdletBinding()]
param(
    [string]$Config,
    [switch]$AllowConnectedDevice,
    [switch]$SkipMonkey,
    [switch]$SkipMaestro,
    [switch]$SkipSimulator,
    [switch]$KeepGoing,
    [switch]$AllowDirtyTree,
    [switch]$PreflightOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:Started = Get-Date
$script:Results = [System.Collections.Generic.List[object]]::new()

if ([string]::IsNullOrWhiteSpace($Config)) {
    $Config = Join-Path $PSScriptRoot 'test-orchestrator.json'
}

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

function Add-NotRunStage([string]$Name, [string]$Reason) {
    Write-Host "Stage not run: $Name - $Reason" -ForegroundColor Yellow
    $script:Results.Add([pscustomobject]@{
        Stage = $Name; Status = 'not-run'; ExitCode = $null
        Duration = '00:00:00'; Reason = $Reason
    })
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
$dirtyEntries = @(git -C $projectRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git status.' }
if ($dirtyEntries.Count -gt 0 -and -not $AllowDirtyTree) {
    throw "The orchestrator requires a frozen source snapshot. Found $($dirtyEntries.Count) dirty path(s)."
}
$logRoot = Join-Path $projectRoot ("test-results\orchestrator-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
Start-Transcript -LiteralPath (Join-Path $logRoot 'run.log') -Force | Out-Null

try {
    $flutter = Require-Tool 'flutter'
    $dart = Require-Tool 'dart'
    $powerShell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

    if ($PreflightOnly) {
        $plannedStages = @(
            'Dependency resolution',
            'Format verification',
            'Security guards',
            'Flutter analysis',
            'Maestro contract validation',
            'Edge Function gate',
            'Robot tests and coverage guard',
            'Flutter integration tests',
            'Maestro QA smoke',
            'Android monkey matrix'
        )
        Write-Host 'Preflight passed. No test, build, install, or device-input stage was executed.' -ForegroundColor Green
        Write-Host "Configured device: $($cfg.deviceId)"
        Write-Host "Configured package: $($cfg.monkey.package)"
        Write-Host "Configured monkey variants: $(@($cfg.monkey.variants).Count)"
        $plannedStages | ForEach-Object { Write-Host " - $_" }
        exit 0
    }

    Invoke-Stage '1. Dependency resolution' $flutter @('pub','get') $projectRoot
    Invoke-Stage '2. Format verification' $dart @('format','--output=none','--set-exit-if-changed','lib','test','integration_test') $projectRoot
    Invoke-Stage '3. Security secret guard' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\security_secret_guard.ps1')) $projectRoot
    Invoke-Stage '4. Secret content guard' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\secret_content_guard.ps1')) $projectRoot
    Invoke-Stage '5. Flutter analysis' $flutter @('analyze','--fatal-infos') $projectRoot
    Invoke-Stage '6. Maestro contract validation' $dart @('run','tool\validate_maestro_flows.dart') $projectRoot
    Invoke-Stage '7. Edge Function gate' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\edge_function_gate.ps1'),'-RunTests') $projectRoot
    Invoke-Stage '8. Robot tests with coverage' $flutter @('test','test','--no-pub','--coverage','--concurrency=1') $projectRoot
    Invoke-Stage '9. Coverage guard' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\coverage_guard.ps1'),'-Mode','ratchet') $projectRoot

    $integrationDir = Join-Path $projectRoot 'integration_test'
    if ($SkipSimulator) {
        Add-NotRunStage '10. Flutter integration tests' '-SkipSimulator was selected.'
    } elseif (-not $AllowConnectedDevice) {
        Add-NotRunStage '10. Flutter integration tests' '-AllowConnectedDevice was not selected.'
    } elseif (Test-Path -LiteralPath $integrationDir) {
        Invoke-Stage '10. Flutter integration tests' $flutter @('test','integration_test','--no-pub','-d',[string]$cfg.deviceId) $projectRoot
    } else {
        Add-NotRunStage '10. Flutter integration tests' 'integration_test\ was not found.'
    }

    $maestroPassed = $false
    if ($SkipMaestro) {
        Add-NotRunStage '11. Maestro QA smoke' '-SkipMaestro was selected.'
    } elseif (-not $AllowConnectedDevice) {
        Add-NotRunStage '11. Maestro QA smoke' '-AllowConnectedDevice was not selected.'
    } else {
        $maestro = Resolve-CommandPath 'maestro'
        $maestroDir = if ($cfg.maestroDirectory) { Join-Path $projectRoot $cfg.maestroDirectory } else { Join-Path $projectRoot 'maestro' }
        if ($maestro -and (Test-Path -LiteralPath $maestroDir)) {
            $maestroArguments = @(
                '-NoProfile','-ExecutionPolicy','Bypass','-File',
                (Join-Path $projectRoot 'scripts\run_maestro_android_evidence.ps1'),
                '-Suite','qa-smoke','-BuildProfile','qa',
                '-DeviceSerial',[string]$cfg.deviceId
            )
            if ($AllowDirtyTree) { $maestroArguments += '-AllowDirtyTree' }
            Invoke-Stage '11. Maestro QA smoke' $powerShell $maestroArguments $projectRoot
            $maestroPassed = $script:Results[$script:Results.Count - 1].Status -eq 'passed'
        } else {
            Add-NotRunStage '11. Maestro QA smoke' 'Maestro CLI or configured flow directory was not found.'
        }
    }

    if ($SkipMonkey) {
        Add-NotRunStage '12. Android monkey matrix' '-SkipMonkey was selected.'
    } elseif (-not $AllowConnectedDevice) {
        Add-NotRunStage '12. Android monkey matrix' '-AllowConnectedDevice was not selected.'
    } elseif (-not $maestroPassed) {
        Add-NotRunStage '12. Android monkey matrix' 'No exact QA APK was built and installed by the Maestro stage.'
    } else {
        $apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
        if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
            throw "QA APK not found after Maestro: $apkPath"
        }
        $apkHash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
        $monkeyArguments = @(
            '-NoProfile','-ExecutionPolicy','Bypass','-File',
            (Join-Path $projectRoot 'scripts\run_android_monkey_matrix.ps1'),
            '-Config',$Config,'-DeviceSerial',[string]$cfg.deviceId,
            '-ApkPath',$apkPath,'-ExpectedApkSha256',$apkHash,
            '-AllowConnectedDevice'
        )
        if ($AllowDirtyTree) { $monkeyArguments += '-AllowDirtyTree' }
        Invoke-Stage '12. Android monkey matrix' $powerShell $monkeyArguments $projectRoot
    }

    $failed = @($script:Results | Where-Object Status -eq 'failed')
    $notRun = @($script:Results | Where-Object Status -eq 'not-run')
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    $script:Results | Format-Table -AutoSize
    Write-Host "Logs: $logRoot"
    if ($failed.Count -gt 0) { exit 1 }
    if ($notRun.Count -gt 0) {
        Write-Host 'Overall result: PARTIAL. One or more stages were not run.' -ForegroundColor Yellow
        exit 2
    }
    Write-Host 'Overall result: PASS. Every configured stage ran and passed.' -ForegroundColor Green
} finally {
    Stop-Transcript | Out-Null
}
