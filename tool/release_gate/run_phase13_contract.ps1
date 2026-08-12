$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptPath = Join-Path $root 'scripts/authoritative_release_gate.ps1'
$templatePath = Join-Path $root 'tool/release_gate/phase13_evidence_template.json'

[void][scriptblock]::Create((Get-Content -Raw -LiteralPath $scriptPath))
$template = Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json
if (@($template.stages).Count -ne 19) { throw 'Phase 13 template must contain 19 stages.' }
for ($index = 0; $index -lt 19; $index += 1) {
  if ([int]$template.stages[$index].stageId -ne ($index + 1)) { throw 'Phase 13 stage order is invalid.' }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Mode ValidateContract
if ($LASTEXITCODE -ne 0) { throw 'Authoritative release-gate contract validation failed.' }

$android = Get-Content -Raw -LiteralPath (Join-Path $root '.github/workflows/android-release.yml')
$web = Get-Content -Raw -LiteralPath (Join-Path $root '.github/workflows/main.yml')
$gate = Get-Content -Raw -LiteralPath (Join-Path $root '.github/workflows/authoritative-release-gate.yml')
if ($android -notmatch 'resolve-authoritative-gate') { throw 'Android release does not depend on the authoritative gate.' }
if ($web -notmatch 'resolve-authoritative-gate') { throw 'Web deployment does not depend on the authoritative gate.' }
if ($android -match 'flutter build appbundle') { throw 'Android release must publish the gated binary, not rebuild it.' }
if ($web -match 'flutter build web') { throw 'Web deployment must publish the gated binary, not rebuild it.' }
if ($gate -notmatch 'workflow_dispatch') { throw 'Authoritative gate must be explicitly invoked.' }
if ($gate -match 'flutter build|actions/deploy-pages|action-gh-release|gh release') { throw 'Authoritative gate must not build, deploy, or release.' }
foreach ($workflow in @($android, $web, $gate)) {
  if ($workflow -match "`t") { throw 'Workflow YAML must not contain tab indentation.' }
}

Write-Host 'Phase 13 workflow and script contract validation passed.'
