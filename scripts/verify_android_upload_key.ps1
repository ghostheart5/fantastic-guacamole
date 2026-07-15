Param(
    [string]$ExpectedSha1 = "13:60:98:6B:E3:45:4F:75:52:56:2E:9A:97:CE:CE:37:74:E2:FD:46",
    [string]$KeyPropertiesPath = "android/key.properties"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $KeyPropertiesPath)) {
    throw "Missing $KeyPropertiesPath. Create it from android/key.properties.example."
}

$props = @{}
Get-Content $KeyPropertiesPath | ForEach-Object {
    if ($_ -match '^(\w+)=(.*)$') {
        $props[$matches[1]] = $matches[2]
    }
}

$required = @('storePassword', 'keyAlias', 'storeFile')
foreach ($name in $required) {
    if (-not $props.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($props[$name])) {
        throw "Missing '$name' in $KeyPropertiesPath"
    }
}

$keystorePath = Join-Path "android" $props['storeFile']
if (-not (Test-Path $keystorePath)) {
    throw "Configured keystore not found: $keystorePath"
}

$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$keytoolOutput = (& keytool -list -v -keystore $keystorePath -storepass $props['storePassword'] -alias $props['keyAlias'] 2>&1) | Out-String
$ErrorActionPreference = $previousErrorAction
$shaMatch = [regex]::Match($keytoolOutput, 'SHA1:\s*([0-9A-F:]{59})')
if (-not $shaMatch.Success) {
    throw "Unable to resolve SHA1 fingerprint from $keystorePath"
}

$actualSha1 = $shaMatch.Groups[1].Value.Trim()
Write-Host "Expected SHA1: $ExpectedSha1"
Write-Host "Actual SHA1:   $actualSha1"

if ($actualSha1 -ne $ExpectedSha1) {
    throw "Upload key fingerprint mismatch. Expected $ExpectedSha1 but found $actualSha1"
}

Write-Host "Upload key fingerprint verified."