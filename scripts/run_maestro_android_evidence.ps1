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
        [string]$FailureMessage = 'Native command failed.'
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Executable @Arguments *>&1 | Tee-Object -FilePath $LogPath
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        throw "$FailureMessage Exit code: $exitCode. Log: $LogPath"
    }
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

& $adb start-server | Out-Null
$deviceRows = @(& $adb devices -l | Select-Object -Skip 1 | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
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

$preflight = [ordered]@{
    schemaVersion = 1
    suite = $Suite
    buildProfile = $BuildProfile
    gitCommit = $commit
    gitBranch = $branch
    gitDirty = ($dirtyEntries.Count -gt 0)
    gitDirtyEntryCount = $dirtyEntries.Count
    deviceSerial = $serial
    deviceModel = (& $adb -s $serial shell getprop ro.product.model).Trim()
    androidVersion = (& $adb -s $serial shell getprop ro.build.version.release).Trim()
    androidApi = (& $adb -s $serial shell getprop ro.build.version.sdk).Trim()
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
Invoke-NativeLogged -Executable $dart -Arguments @('run', 'tool/validate_maestro_flows.dart') -LogPath $validatorLog -FailureMessage 'Maestro contract validation failed.'

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
    Invoke-NativeLogged -Executable $flutter -Arguments $buildArguments -LogPath $buildLog -FailureMessage 'Flutter APK build failed.'
}
else {
    if ([string]::IsNullOrWhiteSpace($ApkPath)) {
        throw '-ApkPath is required with -SkipBuild.'
    }
    $resolvedApk = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $ApkPath))
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
Invoke-NativeLogged -Executable $adb -Arguments @('-s', $serial, 'install', '--no-streaming', '-r', '-t', $resolvedApk) -LogPath $installLog -FailureMessage 'ADB APK install failed.'

$packagePath = @(& $adb -s $serial shell pm path $PackageName)
if (-not $packagePath -or -not ($packagePath -match '^package:')) {
    throw "Installed package could not be verified: $PackageName"
}
$packageDump = @(& $adb -s $serial shell dumpsys package $PackageName)
$versionName = (($packageDump | Select-String 'versionName=' | Select-Object -First 1).Line -replace '^\s*versionName=', '').Trim()
$versionCodeLine = (($packageDump | Select-String 'versionCode=' | Select-Object -First 1).Line).Trim()

$rawLogcat = Join-Path $runRoot 'adb-logcat-raw.log'
$logcatError = Join-Path $runRoot 'adb-logcat-stderr.log'
$logcatProcess = Start-Process -FilePath $adb -ArgumentList @('-s', $serial, 'logcat', '-T', '1', '-v', 'threadtime') -RedirectStandardOutput $rawLogcat -RedirectStandardError $logcatError -WindowStyle Hidden -PassThru

$maestroLog = Join-Path $runRoot 'maestro-console.log'
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
try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $maestro @maestroArguments *>&1 | Tee-Object -FilePath $maestroLog
    $maestroExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
}
finally {
    if ($logcatProcess -and -not $logcatProcess.HasExited) {
        Stop-Process -Id $logcatProcess.Id -Force
        $logcatProcess.WaitForExit()
    }
}
$finishedAt = (Get-Date).ToUniversalTime()

$sanitizedLogcat = Join-Path $runRoot 'adb-logcat-sanitized.log'
$secretValues = @(
    [Environment]::GetEnvironmentVariable('MAESTRO_TEST_EMAIL'),
    [Environment]::GetEnvironmentVariable('MAESTRO_TEST_PASSWORD'),
    [Environment]::GetEnvironmentVariable('MAESTRO_SIGNUP_EMAIL'),
    [Environment]::GetEnvironmentVariable('MAESTRO_SIGNUP_PASSWORD')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
ConvertTo-SanitizedLog -Source $rawLogcat -Destination $sanitizedLogcat -SecretValues $secretValues

$fatalPatterns = @(
    'FATAL EXCEPTION',
    'E/flutter',
    'ANR in',
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

$manifest = [ordered]@{
    schemaVersion = 1
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
Write-Host "Fatal marker count: $($fatalHits.Count)"
Write-Host "APK SHA-256: $apkHash"
Write-Host "Manifest: $manifestPath"
Write-Host "Sanitized Logcat: $sanitizedLogcat"
if (-not $KeepRawLogcat) {
    Write-Host 'Raw Logcat was removed after sanitization.'
}

if ($maestroExitCode -ne 0 -or $fatalHits.Count -gt 0) {
    exit 1
}

Write-Host 'ChronoSpark Android Maestro evidence run passed.' -ForegroundColor Green
exit 0
