param(
  [ValidateSet('production', 'staging', 'tester')]
  [string]$Profile = 'production',
  [switch]$ValidateEnv,
  [switch]$AllowAnalyzeInfos,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$SkipReleaseGuard,
  [switch]$SkipSecretGuard,
  [switch]$SkipUploadKeyCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

function Get-EnvValue {
  param([string]$Name)

  $processValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if (-not [string]::IsNullOrWhiteSpace($processValue)) {
    return $processValue
  }

  $userValue = [Environment]::GetEnvironmentVariable($Name, 'User')
  if (-not [string]::IsNullOrWhiteSpace($userValue)) {
    return $userValue
  }

  $machineValue = [Environment]::GetEnvironmentVariable($Name, 'Machine')
  if (-not [string]::IsNullOrWhiteSpace($machineValue)) {
    return $machineValue
  }

  return $null
}

function Load-DotEnvFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @{}
  }

  $values = @{}
  foreach ($line in Get-Content -Path $Path) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
      continue
    }

    $equalsIndex = $trimmed.IndexOf('=')
    if ($equalsIndex -lt 1) {
      continue
    }

    $key = $trimmed.Substring(0, $equalsIndex).Trim()
    $value = $trimmed.Substring($equalsIndex + 1).Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    if (-not [string]::IsNullOrWhiteSpace($key)) {
      $values[$key] = $value
    }
  }

  return $values
}

function Resolve-EnvValue {
  param(
    [string]$Name,
    [hashtable]$DotEnv
  )

  $value = Get-EnvValue -Name $Name
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    return $value
  }

  if ($DotEnv.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace($DotEnv[$Name])) {
    return $DotEnv[$Name]
  }

  return $null
}

function Resolve-ProfileEnvValue {
  param(
    [string]$BaseName,
    [string]$ProfileName,
    [hashtable]$DotEnv
  )

  $stagingKeyMap = @{
    'CHRONOSPARK_SUPABASE_URL' = 'CHRONOSPARK_STAGING_SUPABASE_URL'
    'CHRONOSPARK_SUPABASE_ANON_KEY' = 'CHRONOSPARK_STAGING_SUPABASE_ANON_KEY'
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT' = 'CHRONOSPARK_STAGING_RECEIPT_VERIFY_ENDPOINT'
    'CHRONOSPARK_AI_PROXY_ENDPOINT' = 'CHRONOSPARK_STAGING_AI_PROXY_ENDPOINT'
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT' = 'CHRONOSPARK_STAGING_ACCOUNT_DELETE_ENDPOINT'
    'CHRONOSPARK_ANDROID_SHA256_CERT' = 'CHRONOSPARK_STAGING_ANDROID_SHA256_CERT'
    'CHRONOSPARK_IOS_TEAM_ID' = 'CHRONOSPARK_STAGING_IOS_TEAM_ID'
  }

  if ($ProfileName -eq 'staging' -and $stagingKeyMap.ContainsKey($BaseName)) {
    $stagingKey = $stagingKeyMap[$BaseName]
    $stagingValue = Resolve-EnvValue -Name $stagingKey -DotEnv $DotEnv
    if (-not [string]::IsNullOrWhiteSpace($stagingValue)) {
      return @{ Name = $stagingKey; Value = $stagingValue; UsedFallback = $false }
    }

    $fallbackValue = Resolve-EnvValue -Name $BaseName -DotEnv $DotEnv
    if (-not [string]::IsNullOrWhiteSpace($fallbackValue)) {
      return @{ Name = $BaseName; Value = $fallbackValue; UsedFallback = $true }
    }

    return @{ Name = $stagingKey; Value = $null; UsedFallback = $false }
  }

  return @{ Name = $BaseName; Value = (Resolve-EnvValue -Name $BaseName -DotEnv $DotEnv); UsedFallback = $false }
}

Write-Host 'Running SAFE release preflight checks (non-destructive)...'
Write-Host "Profile: $Profile"

if ($ValidateEnv) {
  $dotEnvValues = Load-DotEnvFile -Path (Join-Path $root '.env')

  $requiredKeys = switch ($Profile) {
    'tester' {
      @(
        'CHRONOSPARK_SUPABASE_URL',
        'CHRONOSPARK_SUPABASE_ANON_KEY'
      )
    }
    default {
      @(
        'CHRONOSPARK_SUPABASE_URL',
        'CHRONOSPARK_SUPABASE_ANON_KEY',
        'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
        'CHRONOSPARK_AI_PROXY_ENDPOINT',
        'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
        'CHRONOSPARK_ANDROID_SHA256_CERT'
      )
    }
  }

  $missing = New-Object System.Collections.Generic.List[string]
  foreach ($requiredKey in $requiredKeys) {
    $resolved = Resolve-ProfileEnvValue -BaseName $requiredKey -ProfileName $Profile -DotEnv $dotEnvValues
    if ([string]::IsNullOrWhiteSpace($resolved.Value)) {
      $missing.Add($resolved.Name)
      continue
    }

    if ($Profile -eq 'staging' -and $resolved.UsedFallback) {
      Write-Host "Staging fallback in use for $requiredKey (using $($resolved.Name))." -ForegroundColor Yellow
    }
  }

  if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Host 'Environment validation failed. Missing values:' -ForegroundColor Red
    foreach ($name in $missing) {
      Write-Host " - $name" -ForegroundColor Red
    }
    throw 'SAFE release preflight environment validation failed.'
  }

  Write-Host 'Environment validation passed.' -ForegroundColor Green
}

if (-not $SkipSecretGuard) {
  Run-Step -Name 'Security secret guard' -Action {
    & (Join-Path $root 'scripts/security_secret_guard.ps1')
  }
} else {
  Write-Host 'Skipping security secret guard.' -ForegroundColor Yellow
}

if (-not $SkipReleaseGuard) {
  Run-Step -Name 'Release guard' -Action {
    & (Join-Path $root 'scripts/release_guard.ps1')
  }
} else {
  Write-Host 'Skipping release guard.' -ForegroundColor Yellow
}

if (-not $SkipAnalyze) {
  Run-Step -Name 'Flutter analyze' -Action {
    if ($AllowAnalyzeInfos) {
      flutter analyze --no-fatal-infos
    } else {
      flutter analyze
    }
  }
} else {
  Write-Host 'Skipping flutter analyze.' -ForegroundColor Yellow
}

if (-not $SkipTests) {
  Run-Step -Name 'Flutter test' -Action {
    flutter test --concurrency=1
  }
} else {
  Write-Host 'Skipping flutter test.' -ForegroundColor Yellow
}

$keyPropertiesPath = Join-Path $root 'android/key.properties'
if (-not $SkipUploadKeyCheck) {
  if (Test-Path $keyPropertiesPath) {
    $keyPropsContent = Get-Content -Path $keyPropertiesPath -Raw
    $hasPlaceholderSecrets =
      ($keyPropsContent -match '(?im)^\s*storePassword\s*=\s*YOUR_') -or
      ($keyPropsContent -match '(?im)^\s*keyPassword\s*=\s*YOUR_')

    if ($hasPlaceholderSecrets) {
      Write-Host 'Skipping upload key check (android/key.properties contains placeholder credentials).' -ForegroundColor Yellow
    } else {
      Run-Step -Name 'Upload key fingerprint verify' -Action {
        & (Join-Path $root 'scripts/verify_android_upload_key.ps1')
      }
    }
  } else {
    Write-Host 'Skipping upload key check (android/key.properties not found on this machine).' -ForegroundColor Yellow
  }
} else {
  Write-Host 'Skipping upload key fingerprint verify.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'SAFE RELEASE PREFLIGHT PASSED' -ForegroundColor Green
