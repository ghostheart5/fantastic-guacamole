param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$expected = '43b7065507e41f11e6cb31628f928e985e4307d2'
$apkHash = 'af2f8d4ffb8b2af3e80f4b06b873ed4b40d3fb5e333af35bf1c8e53cad899d38'
$output = Join-Path $source 'test-results/hosted-campaign'
if (Test-Path -LiteralPath $output) { throw 'Evidence directory already exists' }
New-Item -ItemType Directory -Path (Join-Path $output 'controls') | Out-Null
$controlNames = @('run_authenticated.ps1','prepare_authenticated_runner.py','bootstrap_authenticated.py','verify_authenticated.py','authenticated.json','verify_campaign.py')
foreach ($control in $controlNames) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $control) -Destination (Join-Path $output 'controls') }
$manifest = [ordered]@{schemaVersion=1;kind='authenticated-start-stress';status='running';sourceCommit=$expected;harnessCommit=$env:GITHUB_SHA;runId=$env:GITHUB_RUN_ID;attempt=$env:GITHUB_RUN_ATTEMPT;startedAt=(Get-Date).ToUniversalTime().ToString('o');steps=@();apk=$null;error=$null;finishedAt=$null;sourceCleanAfter=$false}
function Save-Manifest { $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $output 'campaign-manifest.json') -Encoding utf8 }
$exitCode=1
Push-Location -LiteralPath $source
try {
  $head = & git rev-parse HEAD
  if ($LASTEXITCODE -ne 0 -or $head -ne $expected) { throw 'Frozen source mismatch' }
  $dirty = @(& git status --porcelain=v1 --untracked-files=all)
  if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) { throw 'Frozen application checkout is not clean' }
  $apk = Join-Path $source 'build/app/outputs/flutter-apk/app-debug.apk'
  if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant() -ne $apkHash) { throw 'Retained APK mismatch' }
  Copy-Item -LiteralPath $apk -Destination (Join-Path $output 'qa.apk')
  $manifest.apk = [ordered]@{path='qa.apk';sha256=$apkHash;bytes=(Get-Item -LiteralPath $apk).Length;fromPassingRun=34060313595}
  Save-Manifest
  & adb -s emulator-5554 shell getprop | Set-Content -LiteralPath (Join-Path $output 'emulator-properties.txt')
  & adb -s emulator-5554 shell ime list -s | Set-Content -LiteralPath (Join-Path $output 'input-methods.txt')
  & free -m | Set-Content -LiteralPath (Join-Path $output 'host-memory.txt')
  & python3 (Join-Path $PSScriptRoot 'prepare_authenticated_runner.py') $source
  if ($LASTEXITCODE -ne 0) { throw 'Authenticated runner preparation failed' }
  $env:CHRONOSPARK_FROZEN_SOURCE=$source
  $env:CHRONOSPARK_STRESS_BOOTSTRAP=(Join-Path $PSScriptRoot 'bootstrap_authenticated.py')
  $start=(Get-Date).ToUniversalTime().ToString('o')
  & pwsh -NoProfile -File './test-results/authenticated-runner/scripts/run_android_monkey_matrix.ps1' `
    -Config (Join-Path $PSScriptRoot 'authenticated.json') -DeviceSerial emulator-5554 `
    -ApkPath $apk -ExpectedApkSha256 $apkHash -AllowConnectedDevice -VariantTimeoutSeconds 300 `
    -ArtifactsRoot 'test-results/hosted-campaign/authenticated-monkey' 2>&1 | Tee-Object -FilePath (Join-Path $output 'authenticated-monkey.log')
  $code=$LASTEXITCODE
  $manifest.steps += [ordered]@{name='authenticated-monkey';exitCode=$code;startedAt=$start;finishedAt=(Get-Date).ToUniversalTime().ToString('o')}
  Save-Manifest
  if ($code -ne 0) { throw 'Authenticated Monkey matrix failed' }
  $start=(Get-Date).ToUniversalTime().ToString('o')
  & python3 $env:CHRONOSPARK_STRESS_BOOTSTRAP --source $source --output $output --name final-readback --serial emulator-5554
  $code=$LASTEXITCODE
  $manifest.steps += [ordered]@{name='final-nexus-readback';exitCode=$code;startedAt=$start;finishedAt=(Get-Date).ToUniversalTime().ToString('o')}
  if ($code -ne 0) { throw 'Final signed-in Nexus readback failed' }
  $manifest.status='passed'
  $exitCode=0
} catch {
  $manifest.status='failed'
  $manifest.error=$_.Exception.Message
  [Console]::Error.WriteLine($manifest.error)
} finally {
  $dirty = @(& git status --porcelain=v1 --untracked-files=all)
  $manifest.sourceCleanAfter=$LASTEXITCODE -eq 0 -and $dirty.Count -eq 0
  $head = & git rev-parse HEAD
  $manifest.sourceCleanAfter=$manifest.sourceCleanAfter -and $LASTEXITCODE -eq 0 -and $head -eq $expected
  if (-not $manifest.sourceCleanAfter) { $manifest.status='failed';$exitCode=1 }
  $manifest.finishedAt=(Get-Date).ToUniversalTime().ToString('o')
  Save-Manifest
  Pop-Location
}
exit $exitCode
