[CmdletBinding()]
param(
    [ValidateSet('qa-smoke', 'safe', 'custom', 'destructive')]
    [string]$Suite = 'qa-smoke',

    [ValidateSet('qa', 'debug', 'release')]
    [string]$BuildProfile = 'qa',

    [string[]]$Flow,
    [string]$DeviceSerial,
    [string]$ApkPath,
    [switch]$SkipBuild,
    [switch]$AllowDirtyTree,
    [switch]$KeepRawLogcat,
    [switch]$PreflightOnly,
    [string]$DestructiveConfirmation,
    [string]$ExpectedCommit,
    [string]$ExpectedApkSha256,
    [string]$PackageName = 'com.ghostheart5.chronospark',
    [ValidateRange(1, 3600)]
    [int]$ExecutionTimeoutSeconds = 900,
    [string]$ValidateJUnitOnlyPath,
    [string]$ArtifactsRoot = 'artifacts/maestro'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

function Resolve-CommandPath {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string[]]$Candidates = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Required command '$Name' was not found."
}

function Invoke-NativeLogged {
    param(
        [Parameter(Mandatory)]
        [string]$Executable,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$LogPath,
        [string]$FailureMessage = 'Native command failed.',
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 120
    )

    $result = Invoke-NativeTimedLogged `
        -Executable $Executable `
        -Arguments $Arguments `
        -LogPath $LogPath `
        -TimeoutSeconds $TimeoutSeconds
    if ($result.TimedOut) {
        throw "$FailureMessage Timed out after $TimeoutSeconds seconds. Log: $LogPath"
    }
    if ($result.ExitCode -ne 0) {
        throw "$FailureMessage Exit code: $($result.ExitCode). Log: $LogPath"
    }
    return $result
}

function Get-SelectedFlows {
    param([string]$SelectedSuite, [string[]]$CustomFlows)

    switch ($SelectedSuite) {
        'qa-smoke' {
            return @(
                '.maestro/flows/04-smart-planner.yaml',
                '.maestro/flows/05-creator.yaml',
                '.maestro/flows/06-si-console.yaml',
                '.maestro/flows/07-timeline.yaml',
                '.maestro/flows/08-progression.yaml'
            )
        }
        'safe' {
            return @(Get-ChildItem -LiteralPath '.maestro/flows' -Filter '*.yaml' |
                Where-Object { $_.Name -ne '12-account-deletion.yaml' } |
                Sort-Object Name |
                ForEach-Object { $_.FullName })
        }
        'destructive' {
            return @('.maestro/flows/12-account-deletion.yaml')
        }
        'custom' {
            if (-not $CustomFlows -or $CustomFlows.Count -eq 0) {
                throw '-Flow is required when -Suite custom is selected.'
            }
            return @($CustomFlows)
        }
    }
}

function ConvertTo-SanitizedLog {
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Destination,
        [string[]]$SecretValues
    )

    $emailPattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    $bearerPattern = '(?i)Bearer\s+[A-Za-z0-9._~+/=-]+'
    $jwtPattern = '\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'
    $credentialPattern = '(?i)(password|passwd|token|api[_-]?key|authorization)(\s*[:=]\s*)([^\s,;]+)'

    $writer = [System.IO.StreamWriter]::new($Destination, $false, [System.Text.UTF8Encoding]::new($false))
    try {
        foreach ($line in [System.IO.File]::ReadLines($Source)) {
            $sanitized = $line
            foreach ($secret in $SecretValues) {
                if (-not [string]::IsNullOrWhiteSpace($secret)) {
                    $sanitized = $sanitized -replace [regex]::Escape($secret), '<redacted-secret>'
                }
            }
            $sanitized = $sanitized -replace $bearerPattern, 'Bearer <redacted>'
            $sanitized = $sanitized -replace $jwtPattern, '<redacted-jwt>'
            $sanitized = $sanitized -replace $emailPattern, '<redacted-email>'
            $sanitized = $sanitized -replace $credentialPattern, '$1$2<redacted>'
            $writer.WriteLine($sanitized)
        }
    }
    finally {
        $writer.Dispose()
    }
}

function Stop-NativeProcessTree {
    param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

    $isWindowsHost = $env:OS -eq 'Windows_NT'
    $isWindowsVariable = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
    if ($isWindowsVariable) {
        $isWindowsHost = [bool]$isWindowsVariable.Value
    }
    if ($isWindowsHost) {
        $killer = [System.Diagnostics.Process]::new()
        try {
            $killer.StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $killer.StartInfo.FileName = 'taskkill.exe'
            $killer.StartInfo.Arguments = "/PID $($Process.Id) /T /F"
            $killer.StartInfo.UseShellExecute = $false
            $killer.StartInfo.CreateNoWindow = $true
            if ($killer.Start() -and -not $killer.WaitForExit(5000)) {
                $killer.Kill()
                [void]$killer.WaitForExit(2000)
            }
        }
        catch {
            # The direct process kill below remains the bounded fallback.
        }
        finally {
            $killer.Dispose()
        }
    }
    else {
        try { $Process.Kill($true) } catch { $Process.Kill() }
    }
    if (-not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-NativeTimedLogged {
    param(
        [Parameter(Mandatory)]
        [string]$Executable,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$LogPath,
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds
    )

    $process = $null
    try {
        $powerShellPath = (Get-Process -Id $PID).Path
        $payloadJson = [ordered]@{
            executable = $Executable
            arguments = @($Arguments)
        } | ConvertTo-Json -Compress
        $payloadBase64 = [Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
        )
        $invokeCommand = @"
`$payloadJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$payloadBase64'))
`$payload = `$payloadJson | ConvertFrom-Json
`$target = [string]`$payload.executable
`$targetArguments = @(`$payload.arguments | ForEach-Object { [string]`$_ })
& `$target @targetArguments
exit `$LASTEXITCODE
"@
        $encodedCommand = [Convert]::ToBase64String(
            [System.Text.Encoding]::Unicode.GetBytes($invokeCommand)
        )
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $powerShellPath
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCommand"

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw "Unable to start native command: $Executable"
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            Stop-NativeProcessTree -Process $process
            if (-not $process.WaitForExit(5000)) {
                throw "Timed-out native command could not be terminated: $Executable"
            }
        }
        else {
            $process.WaitForExit()
        }
        if (-not $stdoutTask.Wait(5000) -or -not $stderrTask.Wait(5000)) {
            throw "Native command output pipes did not close after termination: $Executable"
        }
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $combined = @($stdout, $stderr) | Where-Object { -not [string]::IsNullOrEmpty($_) }
        [System.IO.File]::WriteAllText(
            $LogPath,
            ($combined -join [Environment]::NewLine),
            [System.Text.UTF8Encoding]::new($false)
        )

        return [pscustomobject]@{
            ExitCode = if ($completed) { $process.ExitCode } else { -1 }
            TimedOut = -not $completed
            Output = @(
                $combined |
                    ForEach-Object { $_ -split '\r?\n' } |
                    Where-Object { $_ -ne '' }
            )
        }
    }
    finally {
        if ($process) {
            $process.Dispose()
        }
    }
}

function Get-MaestroJUnitSummary {
    param([Parameter(Mandatory)][string]$Path)

    $failed = {
        param([string]$Reason)
        return [pscustomobject]@{
            TerminalParsed = $false
            Status = 'failed'
            TestCases = 0
            Failures = 0
            Errors = 0
            Skipped = 0
            FailureReason = $Reason
        }
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return & $failed 'missing-junit'
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return & $failed 'empty-junit'
    }

    try {
        [xml]$document = $raw
    }
    catch {
        return & $failed 'invalid-junit-xml'
    }

    if ($document.DocumentElement.LocalName -notin @('testsuite', 'testsuites')) {
        return & $failed 'invalid-junit-root'
    }

    $testCases = @($document.SelectNodes("//*[local-name()='testcase']"))
    $actualFailures = @($document.SelectNodes("//*[local-name()='testcase']/*[local-name()='failure']")).Count
    $actualErrors = @($document.SelectNodes("//*[local-name()='testcase']/*[local-name()='error']")).Count
    $actualSkipped = @($document.SelectNodes("//*[local-name()='testcase']/*[local-name()='skipped']")).Count
    $suiteNodes = @($document.SelectNodes("//*[local-name()='testsuite' or local-name()='testsuites']"))

    $invalidMetric = $false
    foreach ($suiteNode in $suiteNodes) {
        foreach ($metric in @('tests', 'failures', 'errors', 'skipped')) {
            $attribute = $suiteNode.Attributes[$metric]
            $value = 0
            if ($attribute -and
                (-not [int]::TryParse($attribute.Value, [ref]$value) -or $value -lt 0)) {
                $invalidMetric = $true
            }
        }
    }

    if ($invalidMetric) {
        return [pscustomobject]@{
            TerminalParsed = $true
            Status = 'failed'
            TestCases = $testCases.Count
            Failures = $actualFailures
            Errors = $actualErrors
            Skipped = $actualSkipped
            FailureReason = 'invalid-junit-count'
        }
    }

    $leafSuiteNodes = @($document.SelectNodes(
        "//*[local-name()='testsuite' and not(.//*[local-name()='testsuite'])]"
    ))
    $getDeclaredTotals = {
        param([string]$Metric)

        $totals = [System.Collections.Generic.List[int]]::new()
        $rootAttribute = $document.DocumentElement.Attributes[$Metric]
        if ($rootAttribute) {
            $totals.Add([int]$rootAttribute.Value)
        }
        $leafAttributes = @($leafSuiteNodes | ForEach-Object {
            if ($_.Attributes[$Metric]) {
                $_.Attributes[$Metric]
            }
        })
        if ($leafAttributes.Count -gt 0) {
            $leafTotal = ($leafAttributes |
                ForEach-Object { [int]$_.Value } |
                Measure-Object -Sum).Sum
            $totals.Add([int]$leafTotal)
        }
        return @($totals)
    }

    $declaredTestTotals = @(& $getDeclaredTotals 'tests')
    $testCountMismatch = @($declaredTestTotals | Where-Object {
        $_ -ne $testCases.Count
    }).Count -gt 0
    $declaredFailureTotals = @(& $getDeclaredTotals 'failures')
    $declaredErrorTotals = @(& $getDeclaredTotals 'errors')
    $declaredSkippedTotals = @(& $getDeclaredTotals 'skipped')
    $failures = @($actualFailures) + $declaredFailureTotals |
        Measure-Object -Maximum |
        Select-Object -ExpandProperty Maximum
    $errors = @($actualErrors) + $declaredErrorTotals |
        Measure-Object -Maximum |
        Select-Object -ExpandProperty Maximum
    $skipped = @($actualSkipped) + $declaredSkippedTotals |
        Measure-Object -Maximum |
        Select-Object -ExpandProperty Maximum

    $failureReason = if ($testCountMismatch) {
        'junit-test-count-mismatch'
    }
    elseif ($testCases.Count -eq 0) {
        'zero-testcases'
    }
    elseif ($failures -gt 0 -or $errors -gt 0 -or $skipped -gt 0) {
        'non-passing-testcases'
    }
    else {
        $null
    }

    return [pscustomobject]@{
        TerminalParsed = $true
        Status = if ($failureReason) { 'failed' } else { 'passed' }
        TestCases = $testCases.Count
        Failures = $failures
        Errors = $errors
        Skipped = $skipped
        FailureReason = $failureReason
    }
}

if (-not [string]::IsNullOrWhiteSpace($ValidateJUnitOnlyPath)) {
    $junitValidation = Get-MaestroJUnitSummary -Path $ValidateJUnitOnlyPath
    $junitValidation | ConvertTo-Json -Depth 3
    if ($junitValidation.Status -ne 'passed') {
        exit 1
    }
    exit 0
}

$adbCandidates = @(
    $(if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe' }),
    $(if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe' }),
    $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe' }),
    'C:/Android/Sdk/platform-tools/adb.exe'
) | Where-Object { $_ }

$flutter = Resolve-CommandPath -Name 'flutter'
$dart = Resolve-CommandPath -Name 'dart'
$maestro = Resolve-CommandPath -Name 'maestro'
$adb = Resolve-CommandPath -Name 'adb' -Candidates $adbCandidates

$selectedFlows = @(Get-SelectedFlows -SelectedSuite $Suite -CustomFlows $Flow)
$resolvedFlows = @()
foreach ($selectedFlow in $selectedFlows) {
    if (-not (Test-Path -LiteralPath $selectedFlow -PathType Leaf)) {
        throw "Maestro flow not found: $selectedFlow"
    }
    $resolvedFlows += (Resolve-Path -LiteralPath $selectedFlow).Path
}

$deletionFlow = '12-account-deletion.yaml'
$containsDeletion = [bool]($resolvedFlows | Where-Object { (Split-Path -Leaf $_) -eq $deletionFlow })
if ($containsDeletion) {
    if ($Suite -ne 'destructive') {
        throw 'Account deletion can run only with -Suite destructive.'
    }
    if ($DestructiveConfirmation -cne 'DELETE DISPOSABLE ACCOUNT') {
        throw "Destructive execution requires -DestructiveConfirmation 'DELETE DISPOSABLE ACCOUNT'."
    }
    if ($BuildProfile -eq 'qa') {
        throw 'Destructive execution cannot use the QA mock-login build.'
    }
}

$flowNames = @($resolvedFlows | ForEach-Object { Split-Path -Leaf $_ })
$needsPrimaryCredentials = $BuildProfile -ne 'qa' -and [bool]($flowNames | Where-Object { $_ -ne '03-onboarding-tutorial.yaml' -and $_ -ne '02-signup.yaml' })
$needsPrimaryCredentials = $needsPrimaryCredentials -or ($flowNames -contains '01-login.yaml') -or $containsDeletion
$needsSignupCredentials = $flowNames -contains '02-signup.yaml'

$requiredEnvironment = @()
if ($needsPrimaryCredentials) {
    $requiredEnvironment += @('MAESTRO_TEST_EMAIL', 'MAESTRO_TEST_PASSWORD')
}
if ($needsSignupCredentials) {
    $requiredEnvironment += @('MAESTRO_SIGNUP_EMAIL', 'MAESTRO_SIGNUP_PASSWORD')
}

$missingEnvironment = @($requiredEnvironment | Sort-Object -Unique | Where-Object {
    [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
})
if ($missingEnvironment.Count -gt 0) {
    throw "Missing required environment variable(s): $($missingEnvironment -join ', '). Values were not read or printed."
}

$commit = (& git rev-parse HEAD).Trim()
$shortCommit = (& git rev-parse --short HEAD).Trim()
$branch = (& git branch --show-current).Trim()
$dirtyEntries = @(& git status --porcelain=v1)
if (-not $AllowDirtyTree -and $dirtyEntries.Count -gt 0) {
    throw "Maestro evidence requires a clean source snapshot. Found $($dirtyEntries.Count) dirty path(s)."
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedCommit) -and $commit -ne $ExpectedCommit.Trim()) {
    throw "Source commit $commit does not match expected commit $ExpectedCommit."
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $ArtifactsRoot "$timestamp-$shortCommit-$Suite"
$runRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $runRoot))
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

[void](Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('start-server') `
    -LogPath (Join-Path $runRoot 'adb-start-server.log') `
    -TimeoutSeconds 60 `
    -FailureMessage 'ADB server startup failed.')
$devicesResult = Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('devices', '-l') `
    -LogPath (Join-Path $runRoot 'adb-devices.log') `
    -TimeoutSeconds 60 `
    -FailureMessage 'ADB device inventory failed.'
$deviceRows = @($devicesResult.Output | Select-Object -Skip 1 | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
if ($DeviceSerial) {
    if (-not ($deviceRows | Where-Object { ($_ -split '\s+')[0] -eq $DeviceSerial })) {
        throw "Requested Android device is not connected and authorized: $DeviceSerial"
    }
    $serial = $DeviceSerial
}
else {
    if ($deviceRows.Count -eq 0) {
        throw 'No connected and authorized Android device or emulator was found.'
    }
    if ($deviceRows.Count -gt 1) {
        $serials = @($deviceRows | ForEach-Object { ($_ -split '\s+')[0] }) -join ', '
        throw "Multiple Android devices are connected. Select one with -DeviceSerial. Devices: $serials"
    }
    $serial = ($deviceRows[0] -split '\s+')[0]
}

$deviceModelResult = Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.product.model') `
    -LogPath (Join-Path $runRoot 'adb-device-model.log') `
    -TimeoutSeconds 30 `
    -FailureMessage 'ADB device model lookup failed.'
$androidVersionResult = Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.build.version.release') `
    -LogPath (Join-Path $runRoot 'adb-android-version.log') `
    -TimeoutSeconds 30 `
    -FailureMessage 'ADB Android version lookup failed.'
$androidApiResult = Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.build.version.sdk') `
    -LogPath (Join-Path $runRoot 'adb-android-api.log') `
    -TimeoutSeconds 30 `
    -FailureMessage 'ADB Android API lookup failed.'

$preflight = [ordered]@{
    schemaVersion = 1
    suite = $Suite
    buildProfile = $BuildProfile
    gitCommit = $commit
    gitBranch = $branch
    gitDirty = ($dirtyEntries.Count -gt 0)
    gitDirtyEntryCount = $dirtyEntries.Count
    deviceSerial = $serial
    deviceModel = ($deviceModelResult.Output -join '').Trim()
    androidVersion = ($androidVersionResult.Output -join '').Trim()
    androidApi = ($androidApiResult.Output -join '').Trim()
    flows = $flowNames
    destructive = $containsDeletion
    credentialsRequired = @($requiredEnvironment | Sort-Object -Unique)
    credentialValuesRecorded = $false
    adbPath = $adb
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
}
$preflight | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'preflight.json') -Encoding utf8

Write-Host "Suite: $Suite"
Write-Host "Commit: $commit"
Write-Host "Dirty checkout: $($preflight.gitDirty) ($($preflight.gitDirtyEntryCount) entries)"
Write-Host "Device: $serial / $($preflight.deviceModel) / Android $($preflight.androidVersion) API $($preflight.androidApi)"
Write-Host "Flows: $($flowNames -join ', ')"
Write-Host "Evidence directory: $runRoot"

$validatorLog = Join-Path $runRoot 'maestro-contract-validation.log'
[void](Invoke-NativeLogged -Executable $dart -Arguments @('run', 'tool/validate_maestro_flows.dart') -LogPath $validatorLog -TimeoutSeconds 120 -FailureMessage 'Maestro contract validation failed.')

if ($PreflightOnly) {
    Write-Host 'Preflight and Maestro contract validation completed. No build, install, app launch, or Maestro execution was performed.' -ForegroundColor Green
    exit 0
}

$buildLog = Join-Path $runRoot 'flutter-build.log'
if (-not $SkipBuild) {
    $buildArguments = @('build', 'apk')
    switch ($BuildProfile) {
        'qa' {
            # Device automation does not need the protected production signing
            # path or non-emulator ABIs. Keep QA features while producing a
            # smaller installable APK for the explicitly selected x86_64 AVD.
            $buildArguments += @(
                '--debug',
                '--target-platform=android-x64',
                '--dart-define-from-file=tool/qa_defines.json'
            )
            $resolvedApk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
        }
        'debug' {
            $buildArguments += '--debug'
            $resolvedApk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
        }
        'release' {
            $buildArguments += '--release'
            $resolvedApk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
        }
    }
    [void](Invoke-NativeLogged -Executable $flutter -Arguments $buildArguments -LogPath $buildLog -TimeoutSeconds 1200 -FailureMessage 'Flutter APK build failed.')
}
else {
    if ([string]::IsNullOrWhiteSpace($ApkPath)) {
        throw '-ApkPath is required with -SkipBuild.'
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedApkSha256) -or
        $ExpectedApkSha256.Trim() -notmatch '^[A-Fa-f0-9]{64}$') {
        throw '-ExpectedApkSha256 is required with -SkipBuild and must be an exact SHA-256.'
    }
    $resolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
        [System.IO.Path]::GetFullPath($ApkPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $projectRoot $ApkPath))
    }
    'Build skipped by request.' | Set-Content -LiteralPath $buildLog -Encoding utf8
}

if (-not (Test-Path -LiteralPath $resolvedApk -PathType Leaf)) {
    throw "APK was not found: $resolvedApk"
}

$apkHash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash
if (-not [string]::IsNullOrWhiteSpace($ExpectedApkSha256) -and
    $apkHash -ne $ExpectedApkSha256.Trim()) {
    throw "APK SHA-256 $apkHash does not match expected SHA-256 $ExpectedApkSha256."
}
$installLog = Join-Path $runRoot 'adb-install.log'
[void](Invoke-NativeLogged -Executable $adb -Arguments @('-s', $serial, 'install', '--no-streaming', '-r', '-t', $resolvedApk) -LogPath $installLog -TimeoutSeconds 180 -FailureMessage 'ADB APK install failed.')

$packagePathResult = Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('-s', $serial, 'shell', 'pm', 'path', $PackageName) `
    -LogPath (Join-Path $runRoot 'adb-package-path.log') `
    -TimeoutSeconds 30 `
    -FailureMessage 'ADB installed package path lookup failed.'
$packagePath = @($packagePathResult.Output)
if (-not $packagePath -or -not ($packagePath -match '^package:')) {
    throw "Installed package could not be verified: $PackageName"
}
$packageDumpResult = Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('-s', $serial, 'shell', 'dumpsys', 'package', $PackageName) `
    -LogPath (Join-Path $runRoot 'adb-package-dump.log') `
    -TimeoutSeconds 60 `
    -FailureMessage 'ADB installed package metadata lookup failed.'
$packageDump = @($packageDumpResult.Output)
$versionName = (($packageDump | Select-String 'versionName=' | Select-Object -First 1).Line -replace '^\s*versionName=', '').Trim()
$versionCodeLine = (($packageDump | Select-String 'versionCode=' | Select-Object -First 1).Line).Trim()

$logcatClearLog = Join-Path $runRoot 'adb-logcat-clear.log'
[void](Invoke-NativeLogged `
    -Executable $adb `
    -Arguments @('-s', $serial, 'logcat', '-c') `
    -LogPath $logcatClearLog `
    -TimeoutSeconds 30 `
    -FailureMessage 'ADB logcat clear failed.')
$rawLogcat = Join-Path $runRoot 'adb-logcat-raw.log'
$logcatError = Join-Path $runRoot 'adb-logcat-stderr.log'
$logcatStartArguments = @{
    FilePath = $adb
    ArgumentList = @('-s', $serial, 'logcat', '-v', 'threadtime')
    RedirectStandardOutput = $rawLogcat
    RedirectStandardError = $logcatError
    PassThru = $true
}
$isWindowsHost = $env:OS -eq 'Windows_NT'
$isWindowsVariable = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
if ($isWindowsVariable) {
    $isWindowsHost = [bool]$isWindowsVariable.Value
}
if ($isWindowsHost) {
    $logcatStartArguments.WindowStyle = 'Hidden'
}
$logcatProcess = Start-Process @logcatStartArguments
Start-Sleep -Milliseconds 500
if ($logcatProcess.HasExited) {
    throw "ADB logcat capture exited before Maestro started with code $($logcatProcess.ExitCode)."
}

$maestroLog = Join-Path $runRoot 'maestro-console.log'
$rawMaestroLog = Join-Path $runRoot 'maestro-console-raw.log'
$junitPath = Join-Path $runRoot 'maestro-results.xml'
$maestroDebug = Join-Path $runRoot 'maestro-debug'
$maestroArtifacts = Join-Path $runRoot 'maestro-artifacts'
New-Item -ItemType Directory -Force -Path $maestroDebug, $maestroArtifacts | Out-Null

$maestroArguments = @(
    'test',
    '--udid', $serial,
    '--no-ansi',
    '--format', 'JUNIT',
    '--output', $junitPath,
    '--debug-output', $maestroDebug,
    '--test-output-dir', $maestroArtifacts,
    '--test-suite-name', "ChronoSpark $Suite $shortCommit"
)
if (-not $containsDeletion) {
    $maestroArguments += @('--exclude-tags', 'destructive')
}
$maestroArguments += $resolvedFlows

$startedAt = (Get-Date).ToUniversalTime()
$maestroExitCode = 1
$maestroTimedOut = $false
$logcatAliveThroughRun = $false
$logcatExitCode = $null
$secretValues = @(
    [Environment]::GetEnvironmentVariable('MAESTRO_TEST_EMAIL'),
    [Environment]::GetEnvironmentVariable('MAESTRO_TEST_PASSWORD'),
    [Environment]::GetEnvironmentVariable('MAESTRO_SIGNUP_EMAIL'),
    [Environment]::GetEnvironmentVariable('MAESTRO_SIGNUP_PASSWORD')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
try {
    $maestroResult = Invoke-NativeTimedLogged `
        -Executable $maestro `
        -Arguments $maestroArguments `
        -LogPath $rawMaestroLog `
        -TimeoutSeconds $ExecutionTimeoutSeconds
    $maestroExitCode = $maestroResult.ExitCode
    $maestroTimedOut = $maestroResult.TimedOut
}
finally {
    if ($logcatProcess) {
        $logcatAliveThroughRun = -not $logcatProcess.HasExited
        if ($logcatAliveThroughRun) {
            Stop-NativeProcessTree -Process $logcatProcess
            if (-not $logcatProcess.WaitForExit(5000)) {
                throw 'ADB logcat capture could not be terminated within 5 seconds.'
            }
        }
        $logcatExitCode = $logcatProcess.ExitCode
    }
}
$finishedAt = (Get-Date).ToUniversalTime()

$rawLogcatBytes = if (Test-Path -LiteralPath $rawLogcat -PathType Leaf) {
    (Get-Item -LiteralPath $rawLogcat).Length
} else { 0 }
$logcatErrorBytes = if (Test-Path -LiteralPath $logcatError -PathType Leaf) {
    (Get-Item -LiteralPath $logcatError).Length
} else { 0 }
$logcatCapturePassed = $logcatAliveThroughRun -and
    $rawLogcatBytes -gt 0 -and
    $logcatErrorBytes -eq 0

$junitSummary = Get-MaestroJUnitSummary -Path $junitPath
ConvertTo-SanitizedLog -Source $rawMaestroLog -Destination $maestroLog -SecretValues $secretValues
Remove-Item -LiteralPath $rawMaestroLog -Force

$sanitizedLogcat = Join-Path $runRoot 'adb-logcat-sanitized.log'
ConvertTo-SanitizedLog -Source $rawLogcat -Destination $sanitizedLogcat -SecretValues $secretValues

$fatalPatterns = @(
    'FATAL EXCEPTION',
    'E/flutter',
    'FLUTTER_ERROR_MARKER\s+>>>',
    'Tasks require authenticated account storage',
    ('ANR in\s+' + [regex]::Escape($PackageName)),
    ('Process\s+' + [regex]::Escape($PackageName) + '\s+has died'),
    'MissingPluginException',
    'Failed assertion',
    ('Unable to start.*' + [regex]::Escape($PackageName))
)
$fatalHits = @(Select-String -LiteralPath $sanitizedLogcat -Pattern $fatalPatterns -CaseSensitive:$false -Context 2, 4)
$scanPath = Join-Path $runRoot 'adb-logcat-scan.txt'
if ($fatalHits.Count -eq 0) {
    'No configured fatal runtime markers found.' | Set-Content -LiteralPath $scanPath -Encoding utf8
}
else {
    $fatalHits | Select-Object -First 100 | Out-String -Width 240 | Set-Content -LiteralPath $scanPath -Encoding utf8
}

if (-not $KeepRawLogcat) {
    Remove-Item -LiteralPath $rawLogcat -Force
}

$maestroPassed = -not $maestroTimedOut -and
    $maestroExitCode -eq 0 -and
    $junitSummary.TerminalParsed -and
    $junitSummary.Status -eq 'passed' -and
    $junitSummary.TestCases -eq $resolvedFlows.Count -and
    $logcatCapturePassed
$runPassed = $maestroPassed -and $fatalHits.Count -eq 0

$manifest = [ordered]@{
    schemaVersion = 1
    status = if ($runPassed) { 'passed' } else { 'failed' }
    suite = $Suite
    buildProfile = $BuildProfile
    git = [ordered]@{
        commit = $commit
        branch = $branch
        dirty = ($dirtyEntries.Count -gt 0)
        dirtyEntryCount = $dirtyEntries.Count
    }
    apk = [ordered]@{
        path = $resolvedApk
        sha256 = $apkHash
        builtFromCheckout = (-not [bool]$SkipBuild)
        externalHashVerified = [bool]$SkipBuild
    }
    installedPackage = [ordered]@{
        name = $PackageName
        paths = $packagePath
        versionName = $versionName
        versionCode = $versionCodeLine
    }
    device = [ordered]@{
        serial = $serial
        model = $preflight.deviceModel
        androidVersion = $preflight.androidVersion
        api = $preflight.androidApi
    }
    flows = $flowNames
    destructive = $containsDeletion
    startedAt = $startedAt.ToString('o')
    finishedAt = $finishedAt.ToString('o')
    durationSeconds = [math]::Round(($finishedAt - $startedAt).TotalSeconds, 3)
    maestroExitCode = $maestroExitCode
    maestro = [ordered]@{
        status = if ($maestroPassed) { 'passed' } else { 'failed' }
        exitCode = $maestroExitCode
        timedOut = $maestroTimedOut
        executionTimeoutSeconds = $ExecutionTimeoutSeconds
    }
    junit = [ordered]@{
        terminalParsed = $junitSummary.TerminalParsed
        status = $junitSummary.Status
        testCases = $junitSummary.TestCases
        failures = $junitSummary.Failures
        errors = $junitSummary.Errors
        skipped = $junitSummary.Skipped
        expectedTestCases = $resolvedFlows.Count
        testCaseCountMatchesFlows = ($junitSummary.TestCases -eq $resolvedFlows.Count)
        failureReason = $junitSummary.FailureReason
    }
    logcatCapture = [ordered]@{
        status = if ($logcatCapturePassed) { 'passed' } else { 'failed' }
        aliveThroughRun = $logcatAliveThroughRun
        exitCodeAfterTermination = $logcatExitCode
        outputBytes = $rawLogcatBytes
        stderrBytes = $logcatErrorBytes
        clearLog = $logcatClearLog
    }
    fatalMarkerCount = $fatalHits.Count
    rawLogcatRetained = [bool]$KeepRawLogcat
    credentialsRecorded = $false
    artifacts = [ordered]@{
        junit = $junitPath
        maestroConsole = $maestroLog
        maestroDebug = $maestroDebug
        maestroArtifacts = $maestroArtifacts
        sanitizedLogcat = $sanitizedLogcat
        logcatScan = $scanPath
        buildLog = $buildLog
        installLog = $installLog
    }
}
$manifestPath = Join-Path $runRoot 'manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Host ''
Write-Host "Maestro exit code: $maestroExitCode"
Write-Host "Maestro timed out: $maestroTimedOut (limit: $ExecutionTimeoutSeconds seconds)"
Write-Host "JUnit: status=$($junitSummary.Status); tests=$($junitSummary.TestCases); failures=$($junitSummary.Failures); errors=$($junitSummary.Errors); skipped=$($junitSummary.Skipped)"
Write-Host "Fatal marker count: $($fatalHits.Count)"
Write-Host "APK SHA-256: $apkHash"
Write-Host "Manifest: $manifestPath"
Write-Host "Sanitized Logcat: $sanitizedLogcat"
if (-not $KeepRawLogcat) {
    Write-Host 'Raw Logcat was removed after sanitization.'
}

if (-not $runPassed) {
    exit 1
}

Write-Host 'ChronoSpark Android Maestro evidence run passed.' -ForegroundColor Green
exit 0
