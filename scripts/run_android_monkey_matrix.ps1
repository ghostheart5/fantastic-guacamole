[CmdletBinding()]
param(
    [string]$Config = "$PSScriptRoot\..\test-orchestrator.json",
    [string]$DeviceSerial,
    [string]$ApkPath,
    [string]$ExpectedApkSha256,
    [switch]$AllowConnectedDevice,
    [switch]$AllowDirtyTree,
    [string]$ArtifactsRoot = 'artifacts/monkey'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot

function Resolve-AdbPath {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
    throw 'Android adb.exe was not found.'
}

function Invoke-Adb {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $script:Adb @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    return [pscustomobject]@{ Output = @($output); ExitCode = $exitCode }
}

function Wait-ForPackageFocus {
    param(
        [Parameter(Mandatory)][string]$Serial,
        [Parameter(Mandatory)][string]$PackageName,
        [ValidateRange(1, 120)][int]$TimeoutSeconds = 30,
        [ValidateRange(1, 10)][int]$RequiredStableSamples = 2,
        [ValidateRange(100, 5000)][int]$PollMilliseconds = 500
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $focusPattern = '(?i)\bmCurrentFocus=.*\bu\d+\s+' +
        [regex]::Escape($PackageName) + '(?:/|\.)'
    $stableSamples = 0
    $stablePid = ''
    $lastPid = ''
    $lastFocus = ''

    do {
        $pidResult = Invoke-Adb -Arguments @(
            '-s', $Serial, 'shell', 'pidof', $PackageName
        )
        $windowResult = Invoke-Adb -Arguments @(
            '-s', $Serial, 'shell', 'dumpsys', 'window', 'displays'
        )

        $lastPid = ($pidResult.Output -join '').Trim()
        $lastFocus = @(
            $windowResult.Output |
                ForEach-Object { [string]$_ } |
                Where-Object { $_ -match 'mCurrentFocus=' } |
                Select-Object -Last 1
        ) -join ''

        $ownsFocus =
            $pidResult.ExitCode -eq 0 -and
            -not [string]::IsNullOrWhiteSpace($lastPid) -and
            $windowResult.ExitCode -eq 0 -and
            $lastFocus -match $focusPattern

        if ($ownsFocus) {
            if ($lastPid -eq $stablePid) {
                $stableSamples++
            } else {
                $stablePid = $lastPid
                $stableSamples = 1
            }

            if ($stableSamples -ge $RequiredStableSamples) {
                return [pscustomobject]@{
                    Ready = $true
                    ElapsedSeconds = [math]::Round(
                        $timer.Elapsed.TotalSeconds,
                        3
                    )
                    LastPid = $lastPid
                    LastFocus = $lastFocus.Trim()
                }
            }
        } else {
            $stableSamples = 0
            $stablePid = ''
        }

        if ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Milliseconds $PollMilliseconds
        }
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    return [pscustomobject]@{
        Ready = $false
        ElapsedSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
        LastPid = $lastPid
        LastFocus = $lastFocus.Trim()
    }
}

if (-not $AllowConnectedDevice) {
    throw 'Monkey testing requires -AllowConnectedDevice and an explicitly selected disposable emulator.'
}
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    throw "Config file not found: $Config"
}

$configData = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$packageName = [string]$configData.monkey.package
$variants = @($configData.monkey.variants)
if ([string]::IsNullOrWhiteSpace($packageName)) {
    throw 'monkey.package is required in the orchestrator config.'
}
if ($variants.Count -eq 0) {
    throw 'At least one monkey variant is required.'
}

$dirtyEntries = @(git status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git status.' }
if ($dirtyEntries.Count -gt 0 -and -not $AllowDirtyTree) {
    throw "Monkey evidence requires a frozen source snapshot. Found $($dirtyEntries.Count) dirty path(s)."
}

$script:Adb = Resolve-AdbPath
$serial = if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
    [string]$configData.deviceId
} else {
    $DeviceSerial.Trim()
}
if ([string]::IsNullOrWhiteSpace($serial) -or $serial -eq 'auto') {
    throw 'An explicit emulator serial is required.'
}

$deviceRows = @(& $script:Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
$selectedRow = @($deviceRows | Where-Object { $_ -match ('^' + [regex]::Escape($serial) + '\s+device(?:\s|$)') })
if ($selectedRow.Count -ne 1) {
    throw "Selected Android target is not connected and authorized: $serial"
}
if ($serial -notmatch '^emulator-\d+$') {
    throw "Monkey matrix is restricted to disposable emulators; received '$serial'."
}

$apiResult = Invoke-Adb -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.build.version.sdk')
$modelResult = Invoke-Adb -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.product.model')
$avdResult = Invoke-Adb -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.boot.qemu.avd_name')
$api = ($apiResult.Output -join '').Trim()
$model = ($modelResult.Output -join '').Trim()
$avdName = ($avdResult.Output -join '').Trim()
if ($apiResult.ExitCode -ne 0 -or $modelResult.ExitCode -ne 0) {
    throw 'Unable to identify the selected emulator.'
}
$expectedApi = [string]$configData.expectedAndroidApi
if ($expectedApi -and $api -ne $expectedApi) {
    throw "Expected Android API $expectedApi but selected target reports API $api."
}

$packageResult = Invoke-Adb -Arguments @('-s', $serial, 'shell', 'pm', 'path', $packageName)
if ($packageResult.ExitCode -ne 0 -or -not (($packageResult.Output -join "`n") -match '^package:')) {
    throw "Package is not installed on ${serial}: $packageName"
}

$resolvedApk = $null
$apkHash = $null
if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    $candidateApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
        $ApkPath
    } else {
        Join-Path $projectRoot $ApkPath
    }
    if (-not (Test-Path -LiteralPath $candidateApk -PathType Leaf)) {
        throw "APK evidence file not found: $candidateApk"
    }
    $resolvedApk = (Resolve-Path -LiteralPath $candidateApk).Path
    $apkHash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash
    if ($ExpectedApkSha256 -and $apkHash -ne $ExpectedApkSha256.Trim()) {
        throw 'APK hash does not match -ExpectedApkSha256.'
    }
}

$commit = (git rev-parse HEAD).Trim()
$branch = (git branch --show-current).Trim()
$startedAt = (Get-Date).ToUniversalTime()
$runId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $commit.Substring(0, 8)
$runRoot = Join-Path $projectRoot (Join-Path $ArtifactsRoot $runId)
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$allowedPercentages = @('touch', 'motion', 'trackball', 'nav', 'majornav', 'syskeys', 'appswitch', 'anyevent')
$results = [System.Collections.Generic.List[object]]::new()
$matrixFailed = $false

Write-Host "Monkey target: $serial / $avdName / $model / API $api"
Write-Host "Package: $packageName"
Write-Host "Commit: $commit (dirty entries: $($dirtyEntries.Count))"
Write-Host "Variants: $($variants.Count)"
Write-Host "Evidence directory: $runRoot"

foreach ($variant in $variants) {
    $name = ([string]$variant.name).Trim()
    if ($name -notmatch '^[a-z0-9][a-z0-9-]*$') {
        throw "Invalid monkey variant name: $name"
    }
    $seed = [int64]$variant.seed
    $throttleMs = [int]$variant.throttleMs
    $events = [int]$variant.events
    if ($seed -le 0 -or $throttleMs -lt 0 -or $events -le 0 -or $events -gt 1000) {
        throw "Invalid bounded monkey settings for variant '$name'."
    }

    $percentageTotal = 0
    $percentageArgs = [System.Collections.Generic.List[string]]::new()
    foreach ($property in @($variant.percentages.PSObject.Properties)) {
        $percentageName = [string]$property.Name
        $percentageValue = [int]$property.Value
        if ($allowedPercentages -notcontains $percentageName) {
            throw "Unsupported monkey percentage '$percentageName' in '$name'."
        }
        if ($percentageValue -lt 0 -or $percentageValue -gt 100) {
            throw "Invalid percentage for '$percentageName' in '$name'."
        }
        $percentageTotal += $percentageValue
        $percentageArgs.Add("--pct-$percentageName")
        $percentageArgs.Add([string]$percentageValue)
    }
    if ($percentageTotal -gt 100) {
        throw "Monkey percentages exceed 100 for '$name'."
    }

    $variantStart = Get-Date
    $logcatStart = $variantStart.ToString('MM-dd HH:mm:ss.fff')
    $variantLog = Join-Path $runRoot "$name-monkey.log"
    $runtimeEvidence = Join-Path $runRoot "$name-runtime-evidence.log"

    $stopResult = Invoke-Adb -Arguments @('-s', $serial, 'shell', 'am', 'force-stop', $packageName)
    if ($stopResult.ExitCode -ne 0) {
        throw "Unable to stop the app before variant '$name'."
    }
    $launchResult = Invoke-Adb -Arguments @(
        '-s', $serial, 'shell', 'monkey', '-p', $packageName,
        '-c', 'android.intent.category.LAUNCHER', '1'
    )
    if ($launchResult.ExitCode -ne 0) {
        throw "Unable to launch the app before variant '$name'."
    }

    $startupReadiness = Wait-ForPackageFocus `
        -Serial $serial `
        -PackageName $packageName

    $monkeyArgs = [System.Collections.Generic.List[string]]::new()
    foreach ($value in @('-s', $serial, 'shell', 'monkey', '-p', $packageName, '-s', [string]$seed, '--throttle', [string]$throttleMs, '--monitor-native-crashes')) {
        $monkeyArgs.Add($value)
    }
    foreach ($value in $percentageArgs) { $monkeyArgs.Add($value) }
    $monkeyArgs.Add('-v')
    $monkeyArgs.Add([string]$events)

    $stressMonkeyStarted = $startupReadiness.Ready
    $monkeyExitCode = $null
    if ($stressMonkeyStarted) {
        Write-Host "Running ${name}: seed=$seed events=$events throttle=${throttleMs}ms"
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $script:Adb @monkeyArgs 2>&1 | Tee-Object -FilePath $variantLog | Out-Null
            $monkeyExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }
    } else {
        @(
            'Stress Monkey was not started because ChronoSpark did not acquire a stable focused window.'
            "Startup wait seconds: $($startupReadiness.ElapsedSeconds)"
            "Last PID: $($startupReadiness.LastPid)"
            "Last focus: $($startupReadiness.LastFocus)"
        ) | Set-Content -LiteralPath $variantLog -Encoding utf8
    }

    $logcatResult = Invoke-Adb -Arguments @('-s', $serial, 'logcat', '-d', '-v', 'threadtime', '-T', $logcatStart)
    $logcatText = $logcatResult.Output -join "`n"
    $escapedPackage = [regex]::Escape($packageName)
    $fatalPatterns = @(
        "(?im)^.*// (?:CRASH|ANR):\s*$escapedPackage.*$",
        "(?im)^.*ANR in\s+$escapedPackage(?:\s|$).*$",
        "(?im)^.*(?:am_crash|am_anr).*$escapedPackage.*$",
        "(?is)FATAL EXCEPTION.{0,1200}Process:\s*$escapedPackage(?:,|\s)",
        "(?im)^.*Fatal signal.*$escapedPackage.*$"
    )
    $fatalEvidence = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $fatalPatterns) {
        foreach ($match in [regex]::Matches($logcatText, $pattern)) {
            $fatalEvidence.Add($match.Value.Trim())
        }
    }
    $monkeyText = Get-Content -LiteralPath $variantLog -Raw
    foreach ($match in [regex]::Matches($monkeyText, "(?im)^.*(?:// CRASH:|// ANR:|System appears to have crashed|Monkey aborted).*$")) {
        $fatalEvidence.Add($match.Value.Trim())
    }
    if ($fatalEvidence.Count -eq 0) {
        'No ChronoSpark crash or ANR markers found.' | Set-Content -LiteralPath $runtimeEvidence -Encoding utf8
    } else {
        $fatalEvidence | Select-Object -Unique | Set-Content -LiteralPath $runtimeEvidence -Encoding utf8
    }

    $relaunchResult = Invoke-Adb -Arguments @(
        '-s', $serial, 'shell', 'monkey', '-p', $packageName,
        '-c', 'android.intent.category.LAUNCHER', '1'
    )
    $pidResult = Invoke-Adb -Arguments @('-s', $serial, 'shell', 'pidof', $packageName)
    $relaunchSucceeded = $relaunchResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($pidResult.Output -join '').Trim())
    $passed = $startupReadiness.Ready -and $monkeyExitCode -eq 0 -and $fatalEvidence.Count -eq 0 -and $relaunchSucceeded

    $result = [pscustomobject]@{
        name = $name
        status = if ($passed) { 'passed' } else { 'failed' }
        seed = $seed
        events = $events
        throttleMs = $throttleMs
        percentages = $variant.percentages
        startupReady = $startupReadiness.Ready
        startupWaitSeconds = $startupReadiness.ElapsedSeconds
        startupLastPid = $startupReadiness.LastPid
        startupLastFocus = $startupReadiness.LastFocus
        stressMonkeyStarted = $stressMonkeyStarted
        monkeyExitCode = $monkeyExitCode
        fatalMarkerCount = $fatalEvidence.Count
        relaunchSucceeded = $relaunchSucceeded
        durationSeconds = [math]::Round(((Get-Date) - $variantStart).TotalSeconds, 3)
        monkeyLog = $variantLog
        runtimeEvidence = $runtimeEvidence
    }
    $results.Add($result)
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot "$name-result.json") -Encoding utf8

    Write-Host "$name result: $($result.status); fatal markers=$($result.fatalMarkerCount); relaunch=$relaunchSucceeded"
    if (-not $passed) {
        $matrixFailed = $true
        Write-Host 'Stopping the matrix at the first failed variant to preserve time and evidence.' -ForegroundColor Yellow
        break
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    git = [ordered]@{
        commit = $commit
        branch = $branch
        dirty = $dirtyEntries.Count -gt 0
        dirtyEntryCount = $dirtyEntries.Count
    }
    device = [ordered]@{
        serial = $serial
        avd = $avdName
        model = $model
        androidApi = $api
    }
    package = $packageName
    apk = [ordered]@{
        path = $resolvedApk
        sha256 = $apkHash
    }
    startedAt = $startedAt.ToString('o')
    finishedAt = (Get-Date).ToUniversalTime().ToString('o')
    status = if ($matrixFailed -or $results.Count -ne $variants.Count) { 'failed' } else { 'passed' }
    requestedVariantCount = $variants.Count
    completedVariantCount = $results.Count
    results = @($results)
}
$manifestPath = Join-Path $runRoot 'manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Host "Manifest: $manifestPath"
if ($manifest.status -ne 'passed') { exit 1 }
Write-Host "Monkey matrix passed: $($results.Count)/$($variants.Count) variants." -ForegroundColor Green
