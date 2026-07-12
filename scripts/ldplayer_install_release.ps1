param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$DeviceId = "127.0.0.1:5555",
    [switch]$SkipUninstall,
    [switch]$SkipLaunch
)

$ErrorActionPreference = "Stop"

Set-Location $ProjectRoot

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $FilePath $($Arguments -join ' ')"
    }
}

$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"),
    "C:\Android\Sdk\platform-tools\adb.exe"
)

$adb = $adbCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $adb) {
    throw "adb.exe not found. Install Android platform-tools or update this script's adb path."
}

$bundletoolDir = Join-Path $HOME "tools\bundletool"
$bundletoolJar = Join-Path $bundletoolDir "bundletool-all-1.18.2.jar"
if (-not (Test-Path $bundletoolJar)) {
    New-Item -ItemType Directory -Force -Path $bundletoolDir | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/google/bundletool/releases/download/1.18.2/bundletool-all-1.18.2.jar" -OutFile $bundletoolJar
}

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    throw "Java runtime not found. Install JDK 17+ and retry."
}

$aab = "build/app/outputs/bundle/release/app-release.aab"
$apks = "build/app/outputs/bundle/release/app-release.apks"
$keyPropsPath = "android/key.properties"
$keystorePath = "android/app/key.jks"
$packageName = "com.ghostheart5.chronospark"

if (-not (Test-Path $aab)) {
    throw "AAB not found at $aab. Run flutter build appbundle --release first."
}

if (-not (Test-Path $keyPropsPath)) {
    throw "Missing $keyPropsPath."
}

if (-not (Test-Path $keystorePath)) {
    throw "Missing $keystorePath."
}

$props = @{}
Get-Content $keyPropsPath | ForEach-Object {
    $parts = $_ -split "=", 2
    if ($parts.Length -eq 2) {
        $props[$parts[0].Trim()] = $parts[1].Trim()
    }
}

foreach ($required in @("storePassword", "keyPassword", "keyAlias")) {
    if (-not $props.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($props[$required])) {
        throw "Missing $required in $keyPropsPath."
    }
}

Invoke-External $adb "kill-server"
Invoke-External $adb "start-server"
Invoke-External $adb "connect" $DeviceId

$devices = & $adb devices
if (-not ($devices | Select-String -SimpleMatch "$DeviceId`tdevice")) {
    throw "Device $DeviceId is not online. Open LDPlayer first, then rerun."
}

if (Test-Path $apks) {
    Remove-Item -Force $apks
}

Invoke-External java "-jar" $bundletoolJar "build-apks" `
    --bundle=$aab `
    --output=$apks `
    --mode=universal `
    --ks=$keystorePath `
    --ks-key-alias=$($props["keyAlias"]) `
    --ks-pass=pass:$($props["storePassword"]) `
    --key-pass=pass:$($props["keyPassword"])

if (-not $SkipUninstall) {
    & $adb -s $DeviceId uninstall $packageName | Out-Null
}

Invoke-External java "-jar" $bundletoolJar "install-apks" "--apks=$apks" "--adb=$adb" "--device-id=$DeviceId"

if (-not $SkipLaunch) {
    & $adb -s $DeviceId shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 | Out-Null
}

Write-Host "Installed successfully on $DeviceId"
Write-Host "APKS: $apks"
