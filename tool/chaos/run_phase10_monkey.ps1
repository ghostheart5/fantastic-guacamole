[CmdletBinding()]
param(
  [ValidateSet('pr-smoke', 'nightly', 'pre-release')]
  [string]$Level = 'pr-smoke',
  [Parameter(Mandatory)]
  [string]$ApkPath,
  [Parameter(Mandatory)]
  [string]$DeviceId,
  [int]$Seed,
  [ValidateRange(1000, 100000)]
  [int]$EventCount,
  [switch]$Execute,
  [switch]$Replay,
  [string]$ArtifactRoot = 'artifacts/monkey'
)

$ErrorActionPreference = 'Stop'
$profilesPath = Join-Path $PSScriptRoot 'phase10_monkey_profiles.json'
$profiles = Get-Content -Raw $profilesPath | ConvertFrom-Json
$profile = $profiles.levels.$Level
if (-not $profile) { throw "Unknown Monkey level: $Level" }
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
  throw "APK not found: $ApkPath"
}

function Resolve-Tool([string]$name, [string[]]$candidates) {
  $command = Get-Command $name -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  return $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

$adb = Resolve-Tool 'adb' @(
  (if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe' }),
  (if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe' })
)
$aapt = Resolve-Tool 'aapt' @(
  (if ($env:ANDROID_SDK_ROOT) { Get-ChildItem (Join-Path $env:ANDROID_SDK_ROOT 'build-tools/*/aapt.exe') -ErrorAction SilentlyContinue | Select-Object -Last 1 -ExpandProperty FullName }),
  (if ($env:ANDROID_HOME) { Get-ChildItem (Join-Path $env:ANDROID_HOME 'build-tools/*/aapt.exe') -ErrorAction SilentlyContinue | Select-Object -Last 1 -ExpandProperty FullName })
)
if (-not $adb -or -not $aapt) { throw 'adb and aapt are required; no device command was run.' }

$badging = & $aapt dump badging $ApkPath
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect APK package ID.' }
$match = [regex]::Match(($badging -join [Environment]::NewLine), "package: name='([^']+)'")
if (-not $match.Success) { throw 'APK package ID was not found.' }
$appId = $match.Groups[1].Value
if ($appId -notmatch '\.(maestro|staging|debug|test)$') {
  throw "Refusing Monkey target '$appId': only isolated non-production package IDs are allowed."
}

$actualCount = if ($PSBoundParameters.ContainsKey('EventCount')) { $EventCount } else { [int]$profile.eventCount }
$actualSeed = if ($PSBoundParameters.ContainsKey('Seed')) { $Seed } else { [int]$profile.seeds[0] }
$runId = 'phase10-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-s' + $actualSeed
$runDir = Join-Path $ArtifactRoot $runId
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$apkHash = (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant()
$distribution = $profile.distribution
$metadata = [ordered]@{
  runId = $runId
  level = $Level
  seed = $actualSeed
  eventCount = $actualCount
  applicationId = $appId
  binarySha256 = $apkHash
  device = $DeviceId
  os = $null
  eventDistribution = $distribution
  crash = $null
  anr = $null
  nativeCrash = $null
  droppedEvents = $null
  finalState = 'planned'
  replay = [bool]$Replay
}
if (-not $Execute) {
  $metadata.finalState = 'planned-not-executed'
  $metadata | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $runDir 'metadata.json')
  Write-Host "Monkey plan created at $runDir. Re-run with -Execute to launch events."
  exit 0
}

& $adb -s $DeviceId get-state | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Device '$DeviceId' is unavailable; no fallback device is used." }
$metadata.os = ((& $adb -s $DeviceId shell getprop ro.build.version.release) -join '').Trim()
$logPath = Join-Path $runDir 'monkey.log'
$command = @(
  'shell', 'monkey', '-p', $appId, '--throttle', '40',
  '--pct-touch', $distribution.touch,
  '--pct-motion', $distribution.motion,
  '--pct-nav', $distribution.nav,
  '--pct-majornav', $distribution.majorNav,
  '--pct-appswitch', $distribution.appSwitch,
  '--pct-syskeys', $distribution.systemKeys,
  '--pct-anyevent', $distribution.anyEvent,
  '--monitor-native-crashes', '--kill-process-after-error', '-v', '-v',
  '-s', $actualSeed, $actualCount
)
& $adb -s $DeviceId @command 2>&1 | Tee-Object -FilePath $logPath
$exitCode = $LASTEXITCODE
$log = Get-Content -Raw $logPath
$metadata.crash = [bool]($log -match 'CRASH:|FATAL EXCEPTION|Process .* has died')
$metadata.anr = [bool]($log -match 'ANR in|NOT RESPONDING')
$metadata.nativeCrash = [bool]($log -match 'Native crash|Fatal signal')
$drop = [regex]::Match($log, 'Dropped: (\d+)')
$metadata.droppedEvents = if ($drop.Success) { [int]$drop.Groups[1].Value } else { 0 }
$metadata.finalState = if ($exitCode -eq 0 -and -not $metadata.crash -and -not $metadata.anr -and -not $metadata.nativeCrash) { 'completed' } else { 'failed-replay-required' }
$metadata | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $runDir 'metadata.json')
if ($metadata.finalState -eq 'failed-replay-required') {
  $replay = '.\tool\chaos\run_phase10_monkey.ps1 -Level ' + $Level + ' -ApkPath "' + $ApkPath + '" -DeviceId ' + $DeviceId + ' -Seed ' + $actualSeed + ' -EventCount ' + $actualCount + ' -Replay -Execute'
  Set-Content -Encoding utf8 -Path (Join-Path $runDir 'replay-command.txt') -Value $replay
  throw "Monkey failure captured. Replay the exact failing seed using $runDir\replay-command.txt"
}
Write-Host "Monkey completed with seed $actualSeed. Evidence: $runDir"
