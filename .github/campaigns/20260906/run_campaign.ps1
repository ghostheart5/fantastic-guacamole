param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$expected = '43b7065507e41f11e6cb31628f928e985e4307d2'
$output = Join-Path $source 'test-results/hosted-campaign'
if (Test-Path -LiteralPath $output) { throw 'Evidence directory already exists' }
New-Item -ItemType Directory -Path $output | Out-Null
New-Item -ItemType Directory -Path (Join-Path $output 'controls') | Out-Null
foreach ($control in @('run_campaign.ps1','verify_campaign.py','baseline.json','expanded.json','run_journeys.ps1','prepare_flow.py')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $control) -Destination (Join-Path $output 'controls') }
$manifest = [ordered]@{schemaVersion=1; status='running'; sourceCommit=$expected; harnessCommit=$env:GITHUB_SHA; runId=$env:GITHUB_RUN_ID; attempt=$env:GITHUB_RUN_ATTEMPT; startedAt=(Get-Date).ToUniversalTime().ToString('o'); steps=@(); apk=$null; error=$null; finishedAt=$null; sourceCleanAfter=$false}
$exitCode = 1
function Save-Manifest { $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $output 'campaign-manifest.json') -Encoding utf8 }
function Run-Stage([string]$Name, [string[]]$Arguments) {
  $began = (Get-Date).ToUniversalTime().ToString('o')
  & pwsh -NoProfile @Arguments 2>&1 | Tee-Object -FilePath (Join-Path $output ($Name + '.log'))
  $code = $LASTEXITCODE
  $manifest.steps += [ordered]@{name=$Name; exitCode=$code; startedAt=$began; finishedAt=(Get-Date).ToUniversalTime().ToString('o'); status=$(if ($code -eq 0) {'passed'} else {'failed'})}
  Save-Manifest
  if ($code -ne 0) { throw "Required stage failed: $Name (exit $code)" }
}
function Snapshot([string]$Label) {
  & python3 (Join-Path $PSScriptRoot 'verify_campaign.py') --snapshot $output $Label
  if ($LASTEXITCODE -ne 0) { Write-Warning "Optional UI snapshot unavailable: $Label" }
}
Push-Location -LiteralPath $source
try {
  $head = & git rev-parse HEAD
  if ($LASTEXITCODE -ne 0 -or $head -ne $expected) { throw 'Application source commit mismatch' }
  $dirty = @(& git status --porcelain=v1 --untracked-files=all)
  if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) { throw 'Application checkout is not clean' }
  $api = & adb -s emulator-5554 shell getprop ro.build.version.sdk
  if ($LASTEXITCODE -ne 0 -or $api.Trim() -ne '35') { throw 'Expected API35 emulator' }
  & adb -s emulator-5554 shell getprop | Set-Content -LiteralPath (Join-Path $output 'emulator-properties.txt')
  & adb -s emulator-5554 shell cat /proc/meminfo | Set-Content -LiteralPath (Join-Path $output 'guest-memory.txt')
  & free -m | Set-Content -LiteralPath (Join-Path $output 'host-memory.txt')
  Save-Manifest
  Run-Stage 'journeys' @('-File',(Join-Path $PSScriptRoot 'run_journeys.ps1'),'-SourceRoot',$source)
  $apk = Join-Path $source 'build/app/outputs/flutter-apk/app-debug.apk'
  $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
  Copy-Item -LiteralPath $apk -Destination (Join-Path $output 'qa.apk')
  $manifest.apk = [ordered]@{path='qa.apk'; sha256=$hash; bytes=(Get-Item -LiteralPath $apk).Length}
  Save-Manifest
  Snapshot 'before-baseline'
  Run-Stage 'baseline-monkey' @('-File','./scripts/run_android_monkey_matrix.ps1','-Config',(Join-Path $PSScriptRoot 'baseline.json'),'-DeviceSerial','emulator-5554','-ApkPath',$apk,'-ExpectedApkSha256',$hash,'-AllowConnectedDevice','-VariantTimeoutSeconds','300','-ArtifactsRoot','test-results/hosted-campaign/baseline-monkey')
  Snapshot 'after-baseline'
  Run-Stage 'expanded-monkey' @('-File','./scripts/run_android_monkey_matrix.ps1','-Config',(Join-Path $PSScriptRoot 'expanded.json'),'-DeviceSerial','emulator-5554','-ApkPath',$apk,'-ExpectedApkSha256',$hash,'-AllowConnectedDevice','-VariantTimeoutSeconds','300','-ArtifactsRoot','test-results/hosted-campaign/expanded-monkey')
  Snapshot 'after-expanded'
  Run-Stage 'welcome' @('-File','./scripts/run_maestro_android_evidence.ps1','-Suite','custom','-BuildProfile','qa','-Flow','.maestro/flows/03-onboarding-tutorial.yaml','-DeviceSerial','emulator-5554','-SkipBuild','-ApkPath',$apk,'-ExpectedApkSha256',$hash,'-ExpectedCommit',$expected,'-ExecutionTimeoutSeconds','300','-KeepRawLogcat','-ArtifactsRoot','test-results/hosted-campaign/welcome')
  $manifest.status = 'passed'
  $exitCode = 0
} catch {
  $manifest.status = 'failed'
  $manifest.error = $_.Exception.Message
  [Console]::Error.WriteLine($manifest.error)
} finally {
  $builtApk = Join-Path $source 'build/app/outputs/flutter-apk/app-debug.apk'
  if (-not $manifest.apk -and (Test-Path -LiteralPath $builtApk -PathType Leaf)) {
    Copy-Item -LiteralPath $builtApk -Destination (Join-Path $output 'qa.apk')
    $manifest.apk = [ordered]@{path='qa.apk'; sha256=(Get-FileHash -LiteralPath $builtApk -Algorithm SHA256).Hash.ToLowerInvariant(); bytes=(Get-Item -LiteralPath $builtApk).Length}
  }
  $after = @(& git status --porcelain=v1 --untracked-files=all)
  $manifest.sourceCleanAfter = $LASTEXITCODE -eq 0 -and $after.Count -eq 0
  $afterHead = & git rev-parse HEAD
  $manifest.sourceCleanAfter = $manifest.sourceCleanAfter -and $LASTEXITCODE -eq 0 -and $afterHead -eq $expected
  if (-not $manifest.sourceCleanAfter) { $manifest.status='failed'; $exitCode=1 }
  $manifest.finishedAt = (Get-Date).ToUniversalTime().ToString('o')
  Save-Manifest
  Pop-Location
}
exit $exitCode
