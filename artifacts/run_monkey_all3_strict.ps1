param(
  [string]$Package = "com.ghostheart5.chronospark",
  [string]$ApkPath = "build/app/outputs/flutter-apk/app-debug.apk"
)

$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$root = Join-Path "artifacts" ("monkey_campaign_" + $ts)
$null = New-Item -ItemType Directory -Force -Path $root
$null = New-Item -ItemType Directory -Force -Path (Join-Path $root "logs")
$null = New-Item -ItemType Directory -Force -Path (Join-Path $root "logcat")
$null = New-Item -ItemType Directory -Force -Path (Join-Path $root "meta")

function Save-Section {
  param([string]$Path, [string]$Content)
  $Content | Out-File -FilePath $Path -Encoding utf8 -Append
}

function Run-MonkeyProfile {
  param(
    [string]$Name,
    [string]$MonkeyArgs,
    [string]$Seed,
    [string]$Count
  )

  $start = Get-Date
  $logFile = Join-Path (Join-Path $root "logs") ("$Name`_seed$Seed`_count$Count.log")
  $logcatFile = Join-Path (Join-Path $root "logcat") ("$Name`_seed$Seed`_count$Count.logcat.txt")
  $metaFile = Join-Path (Join-Path $root "meta") ("$Name`_seed$Seed`_count$Count.meta.txt")

  Save-Section -Path $metaFile -Content ("START=" + $start.ToString("o"))
  Save-Section -Path $metaFile -Content ("PROFILE=" + $Name)
  Save-Section -Path $metaFile -Content ("PACKAGE=" + $Package)
  Save-Section -Path $metaFile -Content ("SEED=" + $Seed)
  Save-Section -Path $metaFile -Content ("COUNT=" + $Count)

  adb logcat -c | Out-Null
  adb shell am force-stop $Package | Out-Null

  $cmd = "adb shell monkey -p $Package $MonkeyArgs -s $Seed $Count"
  Save-Section -Path $metaFile -Content ("COMMAND=" + $cmd)

  # Use cmd /c to preserve complete monkey stdout+stderr output in log.
  cmd /c "$cmd 2>&1" | Tee-Object -FilePath $logFile
  $exitCode = $LASTEXITCODE

  adb logcat -d > $logcatFile

  $end = Get-Date
  Save-Section -Path $metaFile -Content ("END=" + $end.ToString("o"))
  Save-Section -Path $metaFile -Content ("EXIT_CODE=" + $exitCode)

  if ($exitCode -ne 0) {
    Save-Section -Path $metaFile -Content "RESULT=FAILED"
  } else {
    Save-Section -Path $metaFile -Content "RESULT=OK"
  }

  return $exitCode
}

Write-Host "Preparing app install state..."
adb shell "pkill -f com.android.commands.monkey || killall com.android.commands.monkey || true" | Out-Null

function Run-ProfileSafely {
  param(
    [string]$Name,
    [string]$MonkeyArgs,
    [string]$Seed,
    [string]$Count
  )

  try {
    $code = Run-MonkeyProfile -Name $Name -MonkeyArgs $MonkeyArgs -Seed $Seed -Count $Count
    if ($code -ne 0) {
      Write-Host ("Profile failed (non-zero exit): " + $Name + " seed=" + $Seed + " exit=" + $code)
    }
  } catch {
    Write-Host ("Profile threw exception but campaign will continue: " + $Name + " seed=" + $Seed)
    Write-Host $_
  }
}

$installed = adb shell pm list packages | Select-String -Pattern $Package -SimpleMatch
if (-not $installed) {
  if (-not (Test-Path $ApkPath)) {
    throw "APK not found at $ApkPath"
  }
  Write-Host "Installing APK: $ApkPath"
  adb install -t -r $ApkPath | Out-Host
}

# 1) Single-seed ultra profile.
$singleArgs = "--throttle 30 --pct-touch 55 --pct-motion 20 --pct-nav 10 --pct-majornav 5 --pct-appswitch 3 --pct-syskeys 0 --pct-anyevent 0 --monitor-native-crashes --kill-process-after-error --bugreport -v -v"
Run-ProfileSafely -Name "single_ultra" -MonkeyArgs $singleArgs -Seed "260726" -Count "1000000"

# 2) Multi-seed campaign profile.
$multiArgs = "--throttle 40 --pct-touch 50 --pct-motion 18 --pct-nav 14 --pct-majornav 8 --pct-appswitch 6 --pct-syskeys 0 --pct-anyevent 0 --monitor-native-crashes --kill-process-after-error --bugreport -v -v"
$seeds = @("260801", "260802", "260803", "260804", "260805")
foreach ($s in $seeds) {
  Run-ProfileSafely -Name "multi_seed" -MonkeyArgs $multiArgs -Seed $s -Count "300000"
}

# 3) Navigation-heavy ultra campaign.
$navArgs = "--throttle 35 --pct-touch 28 --pct-motion 12 --pct-nav 35 --pct-majornav 18 --pct-appswitch 7 --pct-syskeys 0 --pct-anyevent 0 --monitor-native-crashes --kill-process-after-error --bugreport -v -v"
$navSeeds = @("261001", "261002", "261003")
foreach ($s in $navSeeds) {
  Run-ProfileSafely -Name "nav_heavy_ultra" -MonkeyArgs $navArgs -Seed $s -Count "500000"
}

Write-Host "All campaigns finished."
Write-Host ("Output folder: " + $root)
