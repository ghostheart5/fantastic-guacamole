param(
  [switch]$RunTests
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $functionsRoot = Join-Path $root 'supabase/functions'
  if (-not (Test-Path $functionsRoot)) {
    throw "Missing Supabase Edge Functions directory: $functionsRoot"
  }

  $sourceFiles = @(Get-ChildItem -Path $functionsRoot -Recurse -File -Filter '*.ts' | Sort-Object FullName)
  if ($sourceFiles.Count -eq 0) {
    throw 'No Supabase Edge Function TypeScript files were found.'
  }

  Write-Host "Checking formatting for $($sourceFiles.Count) Supabase Edge Function source files..."
  & deno fmt --check $functionsRoot
  if ($LASTEXITCODE -ne 0) {
    throw 'Deno formatting check failed for Supabase Edge Functions.'
  }

  Write-Host "Linting $($sourceFiles.Count) Supabase Edge Function source files..."
  & deno lint $functionsRoot
  if ($LASTEXITCODE -ne 0) {
    throw 'Deno lint failed for Supabase Edge Functions.'
  }

  $entrypoints = @(Get-ChildItem -Path $functionsRoot -Directory |
    ForEach-Object { Join-Path $_.FullName 'index.ts' } |
    Where-Object { Test-Path $_ } |
    Sort-Object)

  if ($entrypoints.Count -eq 0) {
    throw 'No Supabase Edge Function index.ts files were found.'
  }

  Write-Host "Type-checking $($entrypoints.Count) Supabase Edge Functions..."
  foreach ($entrypoint in $entrypoints) {
    Write-Host " - $($entrypoint.Substring($root.Length + 1))"
    & deno check $entrypoint
    if ($LASTEXITCODE -ne 0) {
      throw "Deno type check failed: $entrypoint"
    }
  }

  if ($RunTests) {
    $tests = @(Get-ChildItem -Path $functionsRoot -Recurse -File -Filter '*_test.ts' | Sort-Object FullName)
    if ($tests.Count -eq 0) {
      throw 'RunTests was requested, but no Supabase Edge Function tests were found.'
    }

    foreach ($test in $tests) {
      Write-Host " - $($test.FullName.Substring($root.Length + 1))"
      & deno test $test.FullName
      if ($LASTEXITCODE -ne 0) {
        throw "Deno test failed: $($test.FullName)"
      }
    }
  }

  Write-Host 'Supabase Edge Function gate passed.' -ForegroundColor Green
} finally {
  Pop-Location
}
