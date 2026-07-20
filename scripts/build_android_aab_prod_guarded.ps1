param(
    [string]$BuildName,
    [int]$BuildNumber
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

$dotEnvValues = Load-DotEnvFile -Path (Join-Path $repoRoot '.env')

$requiredEnv = @(
    'CHRONOSPARK_SUPABASE_URL',
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    'CHRONOSPARK_ANDROID_SHA256_CERT'
)

$optionalEnv = @(
    'CHRONOSPARK_IOS_TEAM_ID'
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

foreach ($key in $optionalEnv) {
    $value = Get-EnvValue -Name $key
    if ([string]::IsNullOrWhiteSpace($value) -and $dotEnvValues.ContainsKey($key)) {
        $value = $dotEnvValues[$key]
    }
    if (-not [string]::IsNullOrWhiteSpace($value)) {
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
$currentGradleBuildNumber = if ($gradleVersionCodeMatch.Success) { [int]$gradleVersionCodeMatch.Groups[1].Value } else { 0 }

if ([string]::IsNullOrWhiteSpace($BuildName)) {
    $BuildName = $currentBuildName
}

if ($BuildNumber -le 0) {
    $BuildNumber = [Math]::Max($currentBuildNumber, $currentGradleBuildNumber) + 1
}

$newVersion = "$BuildName+$BuildNumber"
$updatedPubspec = [regex]::Replace(
    $pubspecContent,
    '(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\s*$',
    "version: $newVersion",
    1
)
Set-Content -Path $pubspecPath -Value $updatedPubspec -NoNewline
Write-Host "Updated pubspec version to $newVersion"

if ($androidGradlePropsContent -match '(?m)^CHRONOSPARK_VERSION_CODE=') {
    $androidGradlePropsContent = [regex]::Replace(
        $androidGradlePropsContent,
        '(?m)^CHRONOSPARK_VERSION_CODE=.*$',
        "CHRONOSPARK_VERSION_CODE=$BuildNumber",
        1
    )
}
else {
    $androidGradlePropsContent = $androidGradlePropsContent.TrimEnd() + "`r`nCHRONOSPARK_VERSION_CODE=$BuildNumber`r`n"
}

if ($androidGradlePropsContent -match '(?m)^CHRONOSPARK_VERSION_NAME=') {
    $androidGradlePropsContent = [regex]::Replace(
        $androidGradlePropsContent,
        '(?m)^CHRONOSPARK_VERSION_NAME=.*$',
        "CHRONOSPARK_VERSION_NAME=$BuildName",
        1
    )
}
else {
    $androidGradlePropsContent = $androidGradlePropsContent.TrimEnd() + "`r`nCHRONOSPARK_VERSION_NAME=$BuildName`r`n"
}

Set-Content -Path $androidGradlePropsPath -Value $androidGradlePropsContent -NoNewline
Write-Host "Synced android/gradle.properties release version to $BuildName+$BuildNumber"

Write-Host "Building production AAB (versionName=$BuildName, versionCode=$BuildNumber)..."

$dartDefineFile = Join-Path $env:TEMP ("chronospark-dart-defines-{0}.json" -f $BuildNumber)
$dartDefines = [ordered]@{
    CHRONOSPARK_APP_FLAVOR = 'prod'
    CHRONOSPARK_ENFORCE_PROD_READINESS = 'true'
    CHRONOSPARK_SUPABASE_URL = $envValues['CHRONOSPARK_SUPABASE_URL']
    CHRONOSPARK_SUPABASE_ANON_KEY = $envValues['CHRONOSPARK_SUPABASE_ANON_KEY']
    CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT = $envValues['CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT']
    CHRONOSPARK_AI_PROXY_ENDPOINT = $envValues['CHRONOSPARK_AI_PROXY_ENDPOINT']
    CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT = $envValues['CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT']
    CHRONOSPARK_ANDROID_SHA256_CERT = $envValues['CHRONOSPARK_ANDROID_SHA256_CERT']
}

if ($envValues.ContainsKey('CHRONOSPARK_IOS_TEAM_ID')) {
    $dartDefines['CHRONOSPARK_IOS_TEAM_ID'] = $envValues['CHRONOSPARK_IOS_TEAM_ID']
}

$dartDefines | ConvertTo-Json | Set-Content -Path $dartDefineFile -Encoding UTF8 -NoNewline

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
    & flutter @flutterArgs
    $flutterExitCode = $LASTEXITCODE
}
finally {
    if (Test-Path $dartDefineFile) {
        Remove-Item -Path $dartDefineFile -Force -ErrorAction SilentlyContinue
    }
}

if ($flutterExitCode -ne 0) {
    exit $flutterExitCode
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
Write-Host "Output: $($aabInfo.FullName)"
Write-Host "Size: $($aabInfo.Length) bytes"
Write-Host "LastWriteTime: $($aabInfo.LastWriteTime.ToString('s'))"
