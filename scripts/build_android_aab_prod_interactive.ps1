param(
    [string]$BuildName,
    [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$requiredEnv = @(
    'CHRONOSPARK_SUPABASE_URL',
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    'CHRONOSPARK_ANDROID_SHA256_CERT'
)

foreach ($key in $requiredEnv) {
    $value = [Environment]::GetEnvironmentVariable($key, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = Read-Host "Enter $key"
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "$key is required"
        }
        Set-Item -Path "Env:$key" -Value $value
    }
}

$guardedScript = Join-Path $PSScriptRoot 'build_android_aab_prod_guarded.ps1'
if (-not (Test-Path $guardedScript)) {
    throw "Guarded script missing: $guardedScript"
}

$guardedArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $guardedScript)
if (-not [string]::IsNullOrWhiteSpace($BuildName)) {
    $guardedArgs += @('-BuildName', $BuildName)
}
if ($BuildNumber -gt 0) {
    $guardedArgs += @('-BuildNumber', "$BuildNumber")
}

& powershell @guardedArgs
exit $LASTEXITCODE
