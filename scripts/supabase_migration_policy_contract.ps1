$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migrationsRoot = Join-Path $root 'supabase/migrations'
$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $migrationsRoot -PathType Container)) {
  Write-Host "Supabase migrations directory is missing: $migrationsRoot" -ForegroundColor Red
  exit 1
}

$migrationFiles = @(Get-ChildItem -LiteralPath $migrationsRoot -Filter '*.sql' -File | Sort-Object Name)
if ($migrationFiles.Count -eq 0) {
  Write-Host "No Supabase migrations were found in $migrationsRoot" -ForegroundColor Red
  exit 1
}

# Track policy state in the same filename order used by Supabase migration
# replay. A repeated CREATE POLICY without an intervening DROP POLICY makes a
# clean database bootstrap fail before later migrations can repair the state.
$policyPattern = '(?im)^[\t ]*(?<verb>create|drop)[\t ]+policy(?:[\t ]+if[\t ]+exists)?[\t ]+(?:"(?<quotedPolicy>[^"]+)"|(?<barePolicy>[a-z_][a-z0-9_$]*))[\t\r\n ]+on[\t ]+(?:(?<schema>[a-z_][a-z0-9_$]*)\.)?(?<table>[a-z_][a-z0-9_$]*)'
$activePolicies = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)

foreach ($migrationFile in $migrationFiles) {
  $sql = Get-Content -LiteralPath $migrationFile.FullName -Raw
  if ([string]::IsNullOrEmpty($sql)) {
    continue
  }

  foreach ($match in [regex]::Matches($sql, $policyPattern)) {
    $policyName = if ($match.Groups['quotedPolicy'].Success) {
      $match.Groups['quotedPolicy'].Value
    } else {
      $match.Groups['barePolicy'].Value
    }
    $schemaName = if ($match.Groups['schema'].Success) {
      $match.Groups['schema'].Value
    } else {
      'public'
    }
    $key = "$schemaName.$($match.Groups['table'].Value)::$policyName"
    $line = 1 + ([regex]::Matches($sql.Substring(0, $match.Index), "`n")).Count
    $location = "$($migrationFile.Name):$line"

    if ($match.Groups['verb'].Value -ieq 'drop') {
      $activePolicies.Remove($key) | Out-Null
      continue
    }

    if ($activePolicies.ContainsKey($key)) {
      $failures.Add(
        "Duplicate CREATE POLICY for $key at $location; previous active definition: $($activePolicies[$key])."
      )
      continue
    }

    $activePolicies[$key] = $location
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Supabase migration policy replay contract failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "Supabase migration policy replay contract passed ($($migrationFiles.Count) migrations checked)." -ForegroundColor Green
