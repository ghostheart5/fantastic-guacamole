Param(
    [string]$ExpectedSha1 = "8A:24:D7:BA:AC:AB:52:F0:A3:77:7D:D0:47:C9:07:96:2E:82:FA:A5",
    [string]$KeyPropertiesPath = "android/key.properties"
)

$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptDirectory
$resolvedKeyPropertiesPath = if ([IO.Path]::IsPathRooted($KeyPropertiesPath)) {
    [IO.Path]::GetFullPath($KeyPropertiesPath)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $KeyPropertiesPath))
}

if (-not (Test-Path -LiteralPath $resolvedKeyPropertiesPath)) {
    throw "Missing $resolvedKeyPropertiesPath. Create it from android/key.properties.example."
}

$props = @{}
Get-Content -LiteralPath $resolvedKeyPropertiesPath | ForEach-Object {
    if ($_ -match '^(\w+)=(.*)$') {
        $props[$matches[1]] = $matches[2]
    }
}

$required = @('storePassword', 'keyAlias', 'storeFile')
foreach ($name in $required) {
    if (-not $props.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($props[$name])) {
        throw "Missing '$name' in $resolvedKeyPropertiesPath"
    }
}

$androidRoot = Join-Path $projectRoot 'android'
$keystorePath = if ([IO.Path]::IsPathRooted($props['storeFile'])) {
    [IO.Path]::GetFullPath($props['storeFile'])
} else {
    [IO.Path]::GetFullPath((Join-Path $androidRoot $props['storeFile']))
}
if (-not (Test-Path -LiteralPath $keystorePath)) {
    throw "Configured keystore not found: $keystorePath"
}

$normalizedExpectedSha1 = ($ExpectedSha1 -replace '\s', '').ToUpperInvariant()
if ($normalizedExpectedSha1 -notmatch '^(?:[0-9A-F]{2}:){19}[0-9A-F]{2}$') {
    throw "Invalid expected SHA1 fingerprint: $ExpectedSha1"
}

$keytool = Get-Command keytool -ErrorAction Stop
$storePasswordEnvironmentName = "CHRONOSPARK_KEYTOOL_STORE_PASSWORD_$PID"
Set-Item -LiteralPath "Env:$storePasswordEnvironmentName" -Value $props['storePassword']
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $keytoolOutput = (& $keytool.Source -list -v -keystore $keystorePath '-storepass:env' $storePasswordEnvironmentName -alias $props['keyAlias'] 2>&1) | Out-String
    $keytoolExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorAction
    Remove-Item -LiteralPath "Env:$storePasswordEnvironmentName" -ErrorAction SilentlyContinue
}
if ($keytoolExitCode -ne 0) {
    throw "keytool failed to read upload certificate from $keystorePath"
}

$shaMatch = [regex]::Match($keytoolOutput, 'SHA1:\s*([0-9A-F:]{59})')
if (-not $shaMatch.Success) {
    throw "Unable to resolve SHA1 fingerprint from $keystorePath"
}

$actualSha1 = $shaMatch.Groups[1].Value.Trim().ToUpperInvariant()
Write-Host "Expected SHA1: $normalizedExpectedSha1"
Write-Host "Actual SHA1:   $actualSha1"

if ($actualSha1 -ne $normalizedExpectedSha1) {
    throw "Upload key fingerprint mismatch. Expected $normalizedExpectedSha1 but found $actualSha1"
}

Write-Host "Upload key fingerprint verified."
