param(
    [string]$BuildName,
    [int]$BuildNumber,
    [string]$SigningPropertiesPath,
    [string]$SigningKeystorePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-EnvValue {
    param([string]$Name)

    $processValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if (-not [string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue
    }

    $userValue = [Environment]::GetEnvironmentVariable($Name, 'User')
    if (-not [string]::IsNullOrWhiteSpace($userValue)) {
        return $userValue
    }

    $machineValue = [Environment]::GetEnvironmentVariable($Name, 'Machine')
    if (-not [string]::IsNullOrWhiteSpace($machineValue)) {
        return $machineValue
    }

    return $null
}

function Load-DotEnvFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{}
    }

    $values = @{}
    foreach ($line in Get-Content -Path $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $equalsIndex = $trimmed.IndexOf('=')
        if ($equalsIndex -lt 1) {
            continue
        }

        $key = $trimmed.Substring(0, $equalsIndex).Trim()
        $value = $trimmed.Substring($equalsIndex + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $values[$key] = $value
        }
    }

    return $values
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$sourceCommit = (& git rev-parse HEAD).Trim()
$dirtyEntries = @(& git status --porcelain=v1 --untracked-files=all)
if ($dirtyEntries.Count -gt 0) {
    throw "Production AAB build requires a clean source snapshot. Found $($dirtyEntries.Count) dirty path(s)."
}

if ([string]::IsNullOrWhiteSpace($SigningPropertiesPath) -or [string]::IsNullOrWhiteSpace($SigningKeystorePath)) {
    throw 'External signing properties and keystore paths are required.'
}

$resolvedSigningPropertiesPath = (Resolve-Path -LiteralPath $SigningPropertiesPath).Path
$resolvedSigningKeystorePath = (Resolve-Path -LiteralPath $SigningKeystorePath).Path
$repoPrefix = $repoRoot.TrimEnd('\') + '\'
if ($resolvedSigningPropertiesPath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    $resolvedSigningKeystorePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Signing source files must remain outside the repository.'
}

$signingPropertiesContent = Get-Content -LiteralPath $resolvedSigningPropertiesPath -Raw
if ($signingPropertiesContent -notmatch '(?m)^\s*storeFile\s*=\s*app[/\\]upload-keystore\.jks\s*$') {
    throw 'External key.properties must reference app/upload-keystore.jks.'
}

$temporarySigningPropertiesPath = Join-Path $repoRoot 'android/key.properties'
$temporarySigningKeystorePath = Join-Path $repoRoot 'android/app/upload-keystore.jks'
if ((Test-Path -LiteralPath $temporarySigningPropertiesPath) -or
    (Test-Path -LiteralPath $temporarySigningKeystorePath)) {
    throw 'Temporary signing files already exist in the repository. Remove them before building.'
}

$dotEnvValues = Load-DotEnvFile -Path (Join-Path $repoRoot '.env')

$requiredEnv = @(
    'CHRONOSPARK_SUPABASE_URL',
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    'CHRONOSPARK_ANDROID_SHA256_CERT'
)

$envValues = @{}
$missing = New-Object System.Collections.Generic.List[string]

foreach ($key in $requiredEnv) {
    $value = Get-EnvValue -Name $key
    if ([string]::IsNullOrWhiteSpace($value) -and $dotEnvValues.ContainsKey($key)) {
        $value = $dotEnvValues[$key]
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missing.Add($key)
    }
    else {
        $envValues[$key] = $value
    }
}

if ($missing.Count -gt 0) {
    Write-Host 'Missing required environment variables for production build:' -ForegroundColor Red
    foreach ($key in $missing) {
        Write-Host " - $key" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Set these vars and rerun this script. No bundle was produced.' -ForegroundColor Yellow
    exit 1
}

$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}

$pubspecContent = Get-Content -Path $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspecContent, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
if (-not $versionMatch.Success) {
    throw 'Could not parse version from pubspec.yaml'
}

$currentBuildName = $versionMatch.Groups[1].Value
$currentBuildNumber = [int]$versionMatch.Groups[2].Value

$androidGradlePropsPath = Join-Path $repoRoot 'android/gradle.properties'
if (-not (Test-Path $androidGradlePropsPath)) {
    throw "android/gradle.properties not found at $androidGradlePropsPath"
}

$androidGradlePropsContent = Get-Content -Path $androidGradlePropsPath -Raw
$gradleVersionCodeMatch = [regex]::Match($androidGradlePropsContent, '(?m)^CHRONOSPARK_VERSION_CODE=(\d+)\s*$')
$gradleVersionNameMatch = [regex]::Match($androidGradlePropsContent, '(?m)^CHRONOSPARK_VERSION_NAME=([0-9]+\.[0-9]+\.[0-9]+)\s*$')
if (-not $gradleVersionCodeMatch.Success -or -not $gradleVersionNameMatch.Success) {
    throw 'Could not parse the locked Android release version.'
}

$currentGradleBuildNumber = [int]$gradleVersionCodeMatch.Groups[1].Value
$currentGradleBuildName = $gradleVersionNameMatch.Groups[1].Value
if ($currentGradleBuildName -ne $currentBuildName -or $currentGradleBuildNumber -ne $currentBuildNumber) {
    throw "Release version mismatch: pubspec=$currentBuildName+$currentBuildNumber android=$currentGradleBuildName+$currentGradleBuildNumber"
}

if ([string]::IsNullOrWhiteSpace($BuildName)) {
    $BuildName = $currentBuildName
}
elseif ($BuildName -ne $currentBuildName) {
    throw "Requested build name $BuildName does not match committed version $currentBuildName."
}

if ($BuildNumber -le 0) {
    $BuildNumber = $currentBuildNumber
}
elseif ($BuildNumber -ne $currentBuildNumber) {
    throw "Requested build number $BuildNumber does not match committed version $currentBuildNumber."
}

Write-Host "Building production AAB (versionName=$BuildName, versionCode=$BuildNumber)..."
Write-Host "Source commit: $sourceCommit"

$dartDefineFile = Join-Path $env:TEMP ("chronospark-dart-defines-{0}.json" -f $BuildNumber)
$dartDefines = [ordered]@{
    CHRONOSPARK_APP_FLAVOR = 'prod'
    CHRONOSPARK_ENFORCE_PROD_READINESS = 'true'
    CHRONOSPARK_VERBOSE_LOGS = 'false'
    CHRONOSPARK_ENABLE_MOCK_LOGIN = 'false'
    CHRONOSPARK_ENABLE_MOCK_MODE = 'false'
    CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS = 'false'
    CHRONOSPARK_PAYWALL_DISABLED = 'false'
    CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS = 'false'
    CHRONOSPARK_ENABLE_CLOUD_SYNC = 'false'
    CHRONOSPARK_ENABLE_ANALYTICS = 'false'
    CHRONOSPARK_ENABLE_CRASH_REPORTING = 'false'
    CHRONOSPARK_SUPABASE_URL = $envValues['CHRONOSPARK_SUPABASE_URL']
    CHRONOSPARK_SUPABASE_ANON_KEY = $envValues['CHRONOSPARK_SUPABASE_ANON_KEY']
    CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT = $envValues['CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT']
    CHRONOSPARK_AI_PROXY_ENDPOINT = $envValues['CHRONOSPARK_AI_PROXY_ENDPOINT']
    CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT = $envValues['CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT']
    CHRONOSPARK_ANDROID_SHA256_CERT = $envValues['CHRONOSPARK_ANDROID_SHA256_CERT']
}

$flutterArgs = @(
    'build',
    'appbundle',
    '--release',
    "--build-name=$BuildName",
    "--build-number=$BuildNumber",
    "--dart-define-from-file=$dartDefineFile"
)

$flutterExitCode = 1
try {
    $dartDefines | ConvertTo-Json | Set-Content -Path $dartDefineFile -Encoding UTF8 -NoNewline
    Copy-Item -LiteralPath $resolvedSigningPropertiesPath -Destination $temporarySigningPropertiesPath -ErrorAction Stop
    Copy-Item -LiteralPath $resolvedSigningKeystorePath -Destination $temporarySigningKeystorePath -ErrorAction Stop
    & flutter @flutterArgs
    $flutterExitCode = $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $dartDefineFile) {
        Remove-Item -LiteralPath $dartDefineFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporarySigningPropertiesPath) {
        Remove-Item -LiteralPath $temporarySigningPropertiesPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporarySigningKeystorePath) {
        Remove-Item -LiteralPath $temporarySigningKeystorePath -Force -ErrorAction SilentlyContinue
    }
}

if ($flutterExitCode -ne 0) {
    exit $flutterExitCode
}

$postBuildCommit = (& git rev-parse HEAD).Trim()
$postBuildDirtyEntries = @(& git status --porcelain=v1 --untracked-files=all)
if ($postBuildCommit -ne $sourceCommit -or $postBuildDirtyEntries.Count -gt 0) {
    throw 'Source changed while building the production AAB. Discard the artifact and create a new candidate.'
}

$outputAab = Join-Path $repoRoot 'build/app/outputs/bundle/release/app-release.aab'
if (-not (Test-Path $outputAab)) {
    throw "Expected output AAB missing: $outputAab"
}

$versionedAab = Join-Path $repoRoot ("build/app/outputs/bundle/release/app-release-prod-vc{0}.aab" -f $BuildNumber)
Copy-Item -Path $outputAab -Destination $versionedAab -Force

$aabInfo = Get-Item -Path $versionedAab
Write-Host ''
Write-Host 'Production AAB build complete.' -ForegroundColor Green
Write-Host "Source commit: $sourceCommit"
Write-Host "Output: $($aabInfo.FullName)"
Write-Host "Size: $($aabInfo.Length) bytes"
Write-Host "LastWriteTime: $($aabInfo.LastWriteTime.ToString('s'))"
