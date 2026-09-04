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
$script:OverallStatus = 'failed'
$script:FinalExitCode = 1
$script:UnhandledError = $null
$script:ProjectRoot = $PSScriptRoot
$script:TranscriptStarted = $false

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

function Get-GitEvidenceValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$GitArguments
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $Root @GitArguments 2>$null)
        if ($LASTEXITCODE -eq 0) {
            return ($output -join "`n").Trim()
        }
    }
    catch {
        # Missing Git evidence is represented as null in the manifest.
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    return $null
}

function Write-OrchestratorManifest {
    param([Parameter(Mandatory)][string]$Destination)

    $root = $script:ProjectRoot
    $commit = Get-GitEvidenceValue -Root $root -GitArguments @('rev-parse', 'HEAD')
    $branch = Get-GitEvidenceValue -Root $root -GitArguments @('branch', '--show-current')
    $dirtyText = Get-GitEvidenceValue `
        -Root $root `
        -GitArguments @('status', '--porcelain=v1', '--untracked-files=all')
    $manifest = [ordered]@{
        schemaVersion = 1
        status = $script:OverallStatus
        exitCode = $script:FinalExitCode
        preflightOnly = [bool]$PreflightOnly
        source = [ordered]@{
            projectRoot = $root
            commit = $commit
            branch = $branch
            dirty = -not [string]::IsNullOrWhiteSpace($dirtyText)
        }
        startedAt = $script:Started.ToUniversalTime().ToString('o')
        finishedAt = (Get-Date).ToUniversalTime().ToString('o')
        durationSeconds = [math]::Round(((Get-Date) - $script:Started).TotalSeconds, 3)
        error = $script:UnhandledError
        stages = @($script:Results)
    }
    $manifest | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $Destination -Encoding utf8
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

$logRoot = Join-Path $PSScriptRoot ("test-results\orchestrator-" + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + "-$PID")
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
Start-Transcript -LiteralPath (Join-Path $logRoot 'run.log') -Force | Out-Null
$script:TranscriptStarted = $true

try {
    $cfg = Read-Config
    $projectRoot = Find-FlutterProject $cfg.projectRoot
    $script:ProjectRoot = $projectRoot
    $dirtyEntries = @(git -C $projectRoot status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git status.' }
    if ($dirtyEntries.Count -gt 0 -and -not $AllowDirtyTree) {
        throw "The orchestrator requires a frozen source snapshot. Found $($dirtyEntries.Count) dirty path(s)."
    }
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
        $script:OverallStatus = 'preflight-passed'
        $script:FinalExitCode = 0
    }
    else {

    Invoke-Stage '1. Dependency resolution' $flutter @('pub','get') $projectRoot
    Invoke-Stage '2. Format verification' $dart @('format','--output=none','--set-exit-if-changed','lib','test','integration_test','tool','scripts') $projectRoot
    Invoke-Stage '3. Security secret guard' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\security_secret_guard.ps1')) $projectRoot
    Invoke-Stage '4. Secret content guard' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\secret_content_guard.ps1')) $projectRoot
    Invoke-Stage '5. Flutter analysis' $flutter @('analyze','--fatal-infos') $projectRoot
    Invoke-Stage '6. Maestro contract validation' $dart @('run','tool\validate_maestro_flows.dart') $projectRoot
    Invoke-Stage '7. Edge Function gate' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\edge_function_gate.ps1'),'-RunTests') $projectRoot
    Invoke-Stage '8. Robot tests with coverage' $dart @(
        'run','tool\run_flutter_tests.dart',
        '--report',(Join-Path $logRoot 'robot-tests.report.jsonl'),
        '--manifest',(Join-Path $logRoot 'robot-tests.manifest.json'),
        '--timeout-seconds','3600',
        '--allowed-skips','0',
        '--','test','--no-pub','--coverage','--concurrency=1'
    ) $projectRoot
    Invoke-Stage '9. Coverage guard' $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $projectRoot 'scripts\coverage_guard.ps1'),'-Mode','ratchet') $projectRoot

    $integrationDir = Join-Path $projectRoot 'integration_test'
    if ($SkipSimulator) {
        Add-NotRunStage '10. Flutter integration tests' '-SkipSimulator was selected.'
    } elseif (-not $AllowConnectedDevice) {
        Add-NotRunStage '10. Flutter integration tests' '-AllowConnectedDevice was not selected.'
    } elseif (Test-Path -LiteralPath $integrationDir) {
        Invoke-Stage '10. Flutter integration tests' $dart @(
            'run','tool\run_flutter_tests.dart',
            '--report',(Join-Path $logRoot 'integration-tests.report.jsonl'),
            '--manifest',(Join-Path $logRoot 'integration-tests.manifest.json'),
            '--timeout-seconds','3600',
            '--allowed-skips','0',
            '--','integration_test','--no-pub','-d',[string]$cfg.deviceId
        ) $projectRoot
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
    if ($failed.Count -gt 0) {
        $script:OverallStatus = 'failed'
        $script:FinalExitCode = 1
    }
    elseif ($notRun.Count -gt 0) {
        Write-Host 'Overall result: PARTIAL. One or more stages were not run.' -ForegroundColor Yellow
        $script:OverallStatus = 'partial'
        $script:FinalExitCode = 2
    }
    else {
        Write-Host 'Overall result: PASS. Every configured stage ran and passed.' -ForegroundColor Green
        $script:OverallStatus = 'passed'
        $script:FinalExitCode = 0
    }
    }
}
catch {
    $script:UnhandledError = $_.Exception.Message
    $script:OverallStatus = 'failed'
    $script:FinalExitCode = 1
    Write-Host $_ -ForegroundColor Red
}
finally {
    try {
        Write-OrchestratorManifest -Destination (Join-Path $logRoot 'orchestrator-manifest.json')
    }
    catch {
        $script:FinalExitCode = 1
        Write-Host "Unable to write orchestrator manifest: $_" -ForegroundColor Red
    }
    if ($script:TranscriptStarted) {
        Stop-Transcript | Out-Null
    }
}

exit $script:FinalExitCode
