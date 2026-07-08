$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path logs | Out-Null
$ts = Get-Date -Format yyyyMMdd-HHmmss
$file = Join-Path logs ("flutter-apk-debug-$ts.log")

function Invoke-ReleaseBuildLocks {
    Write-Host 'Releasing potential APK file locks (adb/gradle/java)...'
    & adb kill-server | Out-Null
    Push-Location android
    try {
        & .\gradlew.bat --stop | Out-Null
    }
    finally {
        Pop-Location
    }
    Get-Process java, adb -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Invoke-DebugBuild {
    param(
        [string]$LogFile,
        [switch]$Append
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        if ($Append) {
            return (& flutter build apk --debug -v 2>&1 | Tee-Object -FilePath $LogFile -Append)
        }

        return (& flutter build apk --debug -v 2>&1 | Tee-Object -FilePath $LogFile)
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

Write-Host "Writing build log to: $file"
$buildOutput = Invoke-DebugBuild -LogFile $file
$buildExitCode = $LASTEXITCODE

if ($buildExitCode -ne 0 -and ($buildOutput -match 'Unable to delete directory' -or $buildOutput -match 'app-debug\.apk')) {
    Write-Host 'Detected locked APK output. Retrying once after lock cleanup...'
    Invoke-ReleaseBuildLocks
    $buildOutput = Invoke-DebugBuild -LogFile $file -Append
    $buildExitCode = $LASTEXITCODE
}

exit $buildExitCode
