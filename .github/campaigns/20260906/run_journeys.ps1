param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
Set-Location -LiteralPath $source
& python3 (Join-Path $PSScriptRoot 'prepare_flow.py') $source
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$flowPaths = @(
  '.maestro/flows/04-smart-planner.yaml',
  '.maestro/flows/05-creator.yaml',
  '.maestro/flows/06-si-console.yaml',
  '.maestro/flows/07-timeline.yaml',
  '.maestro/flows/08-progression.yaml',
  '.maestro/qa/09-settings.yaml',
  '.maestro/qa/10-subscription-containment.yaml',
  '.maestro/qa/11-logout.yaml',
  '.maestro/flows/priority8-account-isolation.yaml',
  'test-results/hosted-overrides/flows/priority8-learned-lifecycle.yaml',
  '.maestro/flows/priority8-learned-lifecycle-readback.yaml'
)
& ./scripts/run_maestro_android_evidence.ps1 -Suite custom -BuildProfile qa -Flow $flowPaths `
  -DeviceSerial emulator-5554 -ExpectedCommit 43b7065507e41f11e6cb31628f928e985e4307d2 `
  -SkipBuild -ApkPath build/app/outputs/flutter-apk/app-debug.apk -ExpectedApkSha256 af2f8d4ffb8b2af3e80f4b06b873ed4b40d3fb5e333af35bf1c8e53cad899d38 `
  -ExecutionTimeoutSeconds 2400 -KeepRawLogcat -ArtifactsRoot test-results/hosted-campaign/maestro
exit $LASTEXITCODE
