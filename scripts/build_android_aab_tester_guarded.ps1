param(
    [string]$BuildName,
    [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$qaDefinesRelativePath = 'tool/qa_defines.json'
$qaDefinesPath = Join-Path $repoRoot $qaDefinesRelativePath
if (-not (Test-Path -LiteralPath $qaDefinesPath)) {
    throw "Missing isolated QA configuration: $qaDefinesPath"
}

try {
    $qaDefines = Get-Content -LiteralPath $qaDefinesPath -Raw | ConvertFrom-Json
}
catch {
    throw "Invalid isolated QA configuration: $($_.Exception.Message)"
}

$expectedQaDefines = [ordered]@{
    CHRONOSPARK_APP_FLAVOR = 'qa'
    CHRONOSPARK_ENABLE_MOCK_LOGIN = $true
    CHRONOSPARK_ENABLE_MOCK_MODE = $true
    CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS = $true
    CHRONOSPARK_PAYWALL_DISABLED = $true
    CHRONOSPARK_ENABLE_CLOUD_SYNC = $false
    CHRONOSPARK_ENABLE_ANALYTICS = $false
    CHRONOSPARK_ENABLE_CRASH_REPORTING = $false
    CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS = $false
    CHRONOSPARK_VERBOSE_LOGS = $false
}

foreach ($key in $expectedQaDefines.Keys) {
    $property = $qaDefines.PSObject.Properties[$key]
    if ($null -eq $property -or $property.Value -ne $expectedQaDefines[$key]) {
        throw "Isolated QA configuration has an unsafe or missing value for $key."
    }
}

$forbiddenQaDefines = @(
    'CHRONOSPARK_SUPABASE_URL',
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_AI_REPORT_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT'
)

foreach ($key in $forbiddenQaDefines) {
    if ($null -ne $qaDefines.PSObject.Properties[$key]) {
        throw "Isolated QA configuration must not define production-facing service key $key."
    }
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

Write-Host "Building tester AAB (versionName=$BuildName, versionCode=$BuildNumber)..."

$flutterArgs = @(
    'build',
    'appbundle',
    '--release',
    "--build-name=$BuildName",
    "--build-number=$BuildNumber",
    '--dart-define-from-file=tool/qa_defines.json'
)

& flutter @flutterArgs

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$outputAab = Join-Path $repoRoot 'build/app/outputs/bundle/release/app-release.aab'
if (-not (Test-Path $outputAab)) {
    throw "Expected output AAB missing: $outputAab"
}

$versionedAab = Join-Path $repoRoot ("build/app/outputs/bundle/release/app-release-qa-mock-vc{0}.aab" -f $BuildNumber)
Copy-Item -Path $outputAab -Destination $versionedAab -Force

$aabInfo = Get-Item -Path $versionedAab
Write-Host ''
Write-Host 'Tester AAB build complete.' -ForegroundColor Green
Write-Host "Output: $($aabInfo.FullName)"
Write-Host "Size: $($aabInfo.Length) bytes"
Write-Host "LastWriteTime: $($aabInfo.LastWriteTime.ToString('s'))"
