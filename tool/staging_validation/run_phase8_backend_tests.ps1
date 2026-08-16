throw 'Retired staging harness: execution is disabled. GhostHeart5 production must use reviewed Supabase migrations and functions, never this historical test tooling.'

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$manifestPath = Join-Path $PSScriptRoot 'phase8_backend_test_manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$requiredAreas = @(
    'authentication',
    'session-refresh-and-expiry',
    'two-user-row-isolation',
    'spoofed-user-ids',
    'unauthorized-reads',
    'unauthorized-writes',
    'privileged-rpc-denial',
    'profile-provisioning-and-repair',
    'global-metrics-authorization',
    'rate-limiting',
    'storage-isolation',
    'synchronization',
    'schema-compatibility',
    'migrations',
    'edge-function-validation',
    'malformed-requests',
    'monetization-credits',
    'purchase-verification',
    'entitlement-isolation',
    'restore-behavior',
    'account-deletion-boundaries'
)

if ($manifest.schemaVersion -ne 1 -or
    $manifest.expectedStagingHost -ne 'retired-staging-project.invalid' -or
    $manifest.networkPolicy -ne 'forbidden-by-default' -or
    $manifest.clientPrivilegedSecretsAllowed -ne $false) {
    throw 'PHASE8_MANIFEST_SAFETY_CONTRACT_INVALID'
}

$actualAreas = @($manifest.cases | ForEach-Object { $_.area })
$duplicates = @($actualAreas | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) {
    throw 'PHASE8_MANIFEST_DUPLICATE_AREA'
}
$missingAreas = @($requiredAreas | Where-Object { $_ -notin $actualAreas })
$unexpectedAreas = @($actualAreas | Where-Object { $_ -notin $requiredAreas })
if ($missingAreas.Count -gt 0 -or $unexpectedAreas.Count -gt 0) {
    throw 'PHASE8_MANIFEST_AREA_COVERAGE_INVALID'
}

$missingAssets = @()
foreach ($case in $manifest.cases) {
    if ($case.mode -match 'staging' -and $case.status -notmatch '^pending-') {
        throw "PHASE8_STAGING_CASE_NOT_PENDING:$($case.area)"
    }
    foreach ($asset in $case.assets) {
        $assetPath = Join-Path $repoRoot ([string]$asset)
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
            $missingAssets += [string]$asset
        }
    }
}
if ($missingAssets.Count -gt 0) {
    throw "PHASE8_MANIFEST_MISSING_ASSET:$($missingAssets -join ',')"
}

$parseErrors = @()
$powerShellFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -Filter '*.ps1'
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    if ($errors.Count -gt 0) {
        $parseErrors += $file.FullName
    }
}
if ($parseErrors.Count -gt 0) {
    throw "PHASE8_POWERSHELL_PARSE_FAILURE:$($parseErrors -join ',')"
}

$sqlFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase/tests') -File -Filter '*.sql'
foreach ($file in $sqlFiles) {
    $sql = Get-Content -LiteralPath $file.FullName -Raw
    if ($sql -notmatch '(?is)^\s*begin\s*;' -or $sql -notmatch '(?is)rollback\s*;\s*$') {
        throw "PHASE8_SQL_TRANSACTION_GUARD_MISSING:$($file.Name)"
    }
    if ($sql -notmatch '(?i)select\s+plan\s*\(') {
        throw "PHASE8_SQL_PLAN_MISSING:$($file.Name)"
    }
}

$forbiddenRunnerPatterns = @(
    '(?i)supabase\s+db\s+(push|reset)',
    '(?i)supabase\s+migration\s+(up|repair)',
    '(?i)supabase\s+functions\s+deploy',
    '(?i)delete\s+from\s+auth\.users'
)
$runnerSource = Get-Content -LiteralPath $PSCommandPath -Raw
foreach ($pattern in $forbiddenRunnerPatterns) {
    if ($runnerSource -match $pattern) {
        throw 'PHASE8_LOCAL_RUNNER_CONTAINS_REMOTE_MUTATION_COMMAND'
    }
}

Write-Host 'PASS  Phase 8 manifest covers all required backend areas.' -ForegroundColor Green
Write-Host "PASS  $($manifest.cases.Count) cases reference existing test assets." -ForegroundColor Green
Write-Host "PASS  $($powerShellFiles.Count) staging PowerShell files parse." -ForegroundColor Green
Write-Host "PASS  $($sqlFiles.Count) pgTAP files are transaction-wrapped." -ForegroundColor Green
Write-Host 'PENDING  All staging and sandbox cases require current-head approval and exact-host confirmation.' -ForegroundColor Yellow
Write-Host 'No network request, database reset, migration deployment, or Edge Function deployment was executed.' -ForegroundColor Cyan
