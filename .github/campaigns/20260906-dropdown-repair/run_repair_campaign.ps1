param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$expected = $env:GITHUB_SHA
if ($expected -notmatch '^[a-f0-9]{40}$') { throw 'Missing exact hosted source identity' }
$output = Join-Path $source 'test-results/hosted-campaign'
if (Test-Path -LiteralPath $output) { throw 'Evidence directory already exists' }
New-Item -ItemType Directory -Path (Join-Path $output 'controls') | Out-Null
$controls = @('run_repair_campaign.ps1','prepare_flow.py','prepare_authenticated_runner.py','bootstrap_authenticated.py','verify_repair_campaign.py','verify_campaign.py','authenticated.json','source-manifest.json')
foreach ($name in $controls) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $output 'controls') }
$manifest = [ordered]@{schemaVersion=1;kind='dialog-runtime-repair';status='running';sourceCommit=$expected;harnessCommit=$env:GITHUB_SHA;runId=$env:GITHUB_RUN_ID;attempt=$env:GITHUB_RUN_ATTEMPT;startedAt=(Get-Date).ToUniversalTime().ToString('o');steps=@();apk=$null;sourceCleanAfter=$false;error=$null}
function Save-Manifest { $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $output 'campaign-manifest.json') -Encoding utf8 }
function Run-Stage([string]$Name,[string[]]$Arguments) {
    $start=(Get-Date).ToUniversalTime().ToString('o')
    & pwsh -NoProfile @Arguments 2>&1 | Tee-Object -FilePath (Join-Path $output ($Name+'.log'))
    $code=$LASTEXITCODE
    $manifest.steps += [ordered]@{name=$Name;exitCode=$code;startedAt=$start;finishedAt=(Get-Date).ToUniversalTime().ToString('o')}
    Save-Manifest
    if ($code -ne 0) { throw "Required stage failed: $Name (exit $code)" }
}
$exitCode=1
Push-Location -LiteralPath $source
try {
    $head = & git rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $head -ne $expected) { throw 'Source commit mismatch' }
    $dirty=@(& git status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) { throw 'Application checkout is not clean' }
    $sourceManifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'source-manifest.json') -Raw | ConvertFrom-Json
    foreach ($entry in $sourceManifest.files) {
        $path=Join-Path $source $entry.path
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.canonicalSha256) { throw "Reviewed source file mismatch: $($entry.path)" }
        $proof=Join-Path $output ('source-proofs/'+$entry.path)
        New-Item -ItemType Directory -Path (Split-Path -Parent $proof) -Force | Out-Null
        Copy-Item -LiteralPath $path -Destination $proof
    }
    $apk=Join-Path $source 'build/app/outputs/flutter-apk/app-debug.apk'
    $hash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    Copy-Item -LiteralPath $apk -Destination (Join-Path $output 'qa.apk')
    $manifest.apk=[ordered]@{path='qa.apk';sha256=$hash;bytes=(Get-Item -LiteralPath $apk).Length;configuration='tool/qa_defines.json';rebuiltFromSource=$expected}
    Save-Manifest
    & adb -s emulator-5554 shell getprop | Set-Content -LiteralPath (Join-Path $output 'emulator-properties.txt')
    & free -m | Set-Content -LiteralPath (Join-Path $output 'host-memory.txt')
    & python3 (Join-Path $PSScriptRoot 'prepare_authenticated_runner.py') $source
    if ($LASTEXITCODE -ne 0) { throw 'Authenticated runner preparation failed' }
    $env:CHRONOSPARK_FROZEN_SOURCE=$source
    $env:CHRONOSPARK_STRESS_BOOTSTRAP=(Join-Path $PSScriptRoot 'bootstrap_authenticated.py')
    Run-Stage 'authenticated-monkey' @('-File','test-results/authenticated-runner/scripts/run_android_monkey_matrix.ps1','-Config',(Join-Path $PSScriptRoot 'authenticated.json'),'-DeviceSerial','emulator-5554','-ApkPath',$apk,'-ExpectedApkSha256',$hash,'-AllowConnectedDevice','-VariantTimeoutSeconds','300','-ArtifactsRoot','test-results/hosted-campaign/authenticated-monkey')
    & python3 (Join-Path $PSScriptRoot 'prepare_flow.py') $source
    if ($LASTEXITCODE -ne 0) { throw 'Anchored journey navigation preparation failed' }
    $flowPaths=@('.maestro/flows/04-smart-planner.yaml','.maestro/flows/05-creator.yaml','.maestro/flows/06-si-console.yaml','.maestro/flows/07-timeline.yaml','.maestro/flows/08-progression.yaml','.maestro/qa/09-settings.yaml','.maestro/qa/10-subscription-containment.yaml','.maestro/qa/11-logout.yaml','.maestro/flows/priority8-account-isolation.yaml','test-results/hosted-overrides/flows/priority8-learned-lifecycle.yaml','.maestro/flows/priority8-learned-lifecycle-readback.yaml')
    $start=(Get-Date).ToUniversalTime().ToString('o')
    & ./scripts/run_maestro_android_evidence.ps1 -Suite custom -BuildProfile qa -Flow $flowPaths -DeviceSerial emulator-5554 -ExpectedCommit $expected -SkipBuild -ApkPath $apk -ExpectedApkSha256 $hash -ExecutionTimeoutSeconds 2400 -KeepRawLogcat -ArtifactsRoot 'test-results/hosted-campaign/maestro' 2>&1 | Tee-Object -FilePath (Join-Path $output 'journeys.log')
    $code=$LASTEXITCODE
    $manifest.steps += [ordered]@{name='journeys';exitCode=$code;startedAt=$start;finishedAt=(Get-Date).ToUniversalTime().ToString('o')}
    Save-Manifest
    if ($code -ne 0) { throw 'Required journeys failed' }
    Run-Stage 'welcome' @('-File','scripts/run_maestro_android_evidence.ps1','-Suite','custom','-BuildProfile','qa','-Flow','.maestro/flows/03-onboarding-tutorial.yaml','-DeviceSerial','emulator-5554','-ExpectedCommit',$expected,'-SkipBuild','-ApkPath',$apk,'-ExpectedApkSha256',$hash,'-ExecutionTimeoutSeconds','300','-KeepRawLogcat','-ArtifactsRoot','test-results/hosted-campaign/welcome')
    $start=(Get-Date).ToUniversalTime().ToString('o')
    & python3 $env:CHRONOSPARK_STRESS_BOOTSTRAP --source $source --output $output --name final-readback --serial emulator-5554
    $code=$LASTEXITCODE
    $manifest.steps += [ordered]@{name='final-nexus-readback';exitCode=$code;startedAt=$start;finishedAt=(Get-Date).ToUniversalTime().ToString('o')}
    if ($code -ne 0) { throw 'Final Nexus readback failed' }
    $manifest.status='passed'
    $exitCode=0
} catch {
    $manifest.status='failed'
    $manifest.error=$_.Exception.Message
    [Console]::Error.WriteLine($manifest.error)
} finally {
    $dirty=@(& git status --porcelain=v1 --untracked-files=all)
    $manifest.sourceCleanAfter=$LASTEXITCODE -eq 0 -and $dirty.Count -eq 0
    $head=& git rev-parse HEAD
    $manifest.sourceCleanAfter=$manifest.sourceCleanAfter -and $LASTEXITCODE -eq 0 -and $head -eq $expected
    if (-not $manifest.sourceCleanAfter) { $manifest.status='failed';$exitCode=1 }
    $manifest.finishedAt=(Get-Date).ToUniversalTime().ToString('o')
    Save-Manifest
    Pop-Location
}
exit $exitCode
