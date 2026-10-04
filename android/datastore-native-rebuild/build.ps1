param(
    [string]$AndroidSdkRoot = $(if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { $env:ANDROID_HOME }),
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")
$sourceRoot = Join-Path $scriptRoot "src\main\cpp"
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    throw "Set ANDROID_SDK_ROOT or pass -AndroidSdkRoot."
}
$ndkVersion = "28.2.13676358"
$cmakeVersion = "3.22.1"
$officialAarSha256 = "adca1d7cde73406fcca2a0eeabac63459adc9d1fe201b79ba08711fa2e331984"
$officialPomSha256 = "c85fbe122a236c82a2babe68e3ea862c49b7b38db336c1929ca8352ec9025646"
$rebuiltAarSha256 = "65de9d0ab996b6da98ed109f20da65b5d973a8a2f3e3fa299462cb0d360f434b"
$ndkRoot = Join-Path $AndroidSdkRoot "ndk\$ndkVersion"
$cmakeRoot = Join-Path $AndroidSdkRoot "cmake\$cmakeVersion"
$cmake = Join-Path $cmakeRoot "bin\cmake.exe"
$ninja = Join-Path $cmakeRoot "bin\ninja.exe"
$toolchain = Join-Path $ndkRoot "build\cmake\android.toolchain.cmake"

foreach ($required in @($ndkRoot, $cmake, $ninja, $toolchain, $sourceRoot)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required pinned Android build input is missing: $required"
    }
}

$work = Join-Path $env:TEMP "axiomara-datastore-symbol-build-1.1.7"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$officialAar = Join-Path $work "datastore-core-android-1.1.7.aar"
$officialPom = Join-Path $work "datastore-core-android-1.1.7.pom"
$baseUrl = "https://dl.google.com/dl/android/maven2/androidx/datastore/datastore-core-android/1.1.7"
Invoke-WebRequest -Uri "$baseUrl/datastore-core-android-1.1.7.aar" -OutFile $officialAar
Invoke-WebRequest -Uri "$baseUrl/datastore-core-android-1.1.7.pom" -OutFile $officialPom
$actualAarHash = (Get-FileHash -LiteralPath $officialAar -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualAarHash -ne $officialAarSha256) {
    throw "Official DataStore 1.1.7 AAR digest mismatch: $actualAarHash"
}
$actualPomHash = (Get-FileHash -LiteralPath $officialPom -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualPomHash -ne $officialPomSha256) {
    throw "Official DataStore 1.1.7 POM digest mismatch: $actualPomHash"
}

$abis = @("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
$builtLibraries = Join-Path $work "libraries"
New-Item -ItemType Directory -Force -Path $builtLibraries | Out-Null
foreach ($abi in $abis) {
    $buildDir = Join-Path $work "build-$abi"
    $configureArgs = @(
        "-G", "Ninja",
        "-S", $sourceRoot,
        "-B", $buildDir,
        "-DCMAKE_MAKE_PROGRAM=$ninja",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
        "-DANDROID_NDK:PATH=$ndkRoot",
        "-DANDROID_ABI=$abi",
        "-DANDROID_PLATFORM=android-21",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DANDROID_STL=c++_static"
    )
    & $cmake @configureArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed for $abi" }
    & $cmake --build $buildDir --target datastore_shared_counter
    if ($LASTEXITCODE -ne 0) { throw "DataStore native build failed for $abi" }
    Copy-Item -LiteralPath (Join-Path $buildDir "libdatastore_shared_counter.so") -Destination (Join-Path $builtLibraries "$abi.so") -Force
}

$aarPath = Join-Path $repoRoot "android\local-maven\com\ghostheart5\rebuilt\datastore-core-android-symbolized\1.1.7-gh1"
New-Item -ItemType Directory -Force -Path $aarPath | Out-Null
& $PythonPath (Join-Path $scriptRoot "aar-pack.py") --official-aar $officialAar --official-pom $officialPom --libraries $builtLibraries --output $aarPath
if ($LASTEXITCODE -ne 0) { throw "Deterministic AAR packaging failed" }
$rebuiltAar = Join-Path $aarPath "datastore-core-android-symbolized-1.1.7-gh1.aar"
$actualRebuiltAarHash = (Get-FileHash -LiteralPath $rebuiltAar -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualRebuiltAarHash -ne $rebuiltAarSha256) {
    throw "Rebuilt DataStore AAR digest mismatch: $actualRebuiltAarHash"
}

Write-Output "Built and verified symbolized DataStore AAR $actualRebuiltAarHash from pinned AndroidX 1.1.7 inputs at $aarPath"
