param(
  [switch]$RunTests,
  [ValidateRange(1, 3600)]
  [int]$StageTimeoutSeconds = 300,
  [ValidateRange(1, 3600)]
  [int]$TestTimeoutSeconds = 300,
  [string]$RepositoryRoot = '',
  [string]$TestReportPath = 'coverage/edge-function-tests.junit.xml'
)

$ErrorActionPreference = 'Stop'
$root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  Split-Path -Parent $PSScriptRoot
} else {
  [System.IO.Path]::GetFullPath($RepositoryRoot)
}

function Convert-ToProcessArgument {
  param([string]$Argument)

  if ($Argument -notmatch '[\s"]') {
    return $Argument
  }
  return '"' + $Argument.Replace('"', '\"') + '"'
}

function Invoke-DenoStage {
  param(
    [string]$Name,
    [string[]]$Arguments,
    [int]$TimeoutSeconds,
    [string]$FailureMessage
  )

  $deno = Get-Command deno -ErrorAction Stop
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $deno.Source
  $startInfo.WorkingDirectory = $root
  $startInfo.UseShellExecute = $false

  if ($startInfo.PSObject.Properties.Name -contains 'ArgumentList') {
    foreach ($argument in $Arguments) {
      $startInfo.ArgumentList.Add($argument)
    }
  } else {
    $startInfo.Arguments = ($Arguments | ForEach-Object {
      Convert-ToProcessArgument $_
    }) -join ' '
  }

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    throw "Unable to start $Name."
  }

  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try {
      $process.Kill($true)
    } catch {
      $process.Kill()
    }
    if (-not $process.WaitForExit(5000)) {
      throw "$Name timed out and could not be terminated within 5 seconds."
    }
    throw "$Name timed out after $TimeoutSeconds seconds."
  }

  if ($process.ExitCode -ne 0) {
    throw "$FailureMessage Exit code: $($process.ExitCode)."
  }
}

function Read-DenoTestReport {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Deno test completed without the required JUnit report: $Path"
  }
  if ((Get-Item -LiteralPath $Path).Length -eq 0) {
    throw "Deno test JUnit report is empty: $Path"
  }

  try {
    [xml]$report = Get-Content -LiteralPath $Path -Raw
  } catch {
    throw "Deno test JUnit report is incomplete or invalid: $Path. $($_.Exception.Message)"
  }

  if ($report.DocumentElement.LocalName -ne 'testsuites') {
    throw "Deno test JUnit report has an unexpected root element: $($report.DocumentElement.LocalName)"
  }

  $testCases = @($report.SelectNodes("//*[local-name()='testcase']"))
  $failures = @($report.SelectNodes("//*[local-name()='testcase']/*[local-name()='failure']"))
  $errors = @($report.SelectNodes("//*[local-name()='testcase']/*[local-name()='error']"))
  $skipped = @($report.SelectNodes("//*[local-name()='testcase']/*[local-name()='skipped']"))
  $completed = $testCases.Count - $skipped.Count

  if ($testCases.Count -eq 0) {
    throw 'Deno test JUnit report contains no test cases.'
  }
  if ($failures.Count -gt 0 -or $errors.Count -gt 0) {
    throw "Deno test JUnit report records $($failures.Count) failures and $($errors.Count) errors."
  }
  if ($skipped.Count -gt 0) {
    throw "Deno test JUnit report records $($skipped.Count) skipped test(s); skips are not allowed."
  }
  if ($completed -le 0) {
    throw 'Deno test JUnit report contains no completed tests.'
  }

  return [pscustomobject]@{
    TestCases = $testCases.Count
    Completed = $completed
    Failures = $failures.Count
    Errors = $errors.Count
    Skipped = $skipped.Count
  }
}

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
  Invoke-DenoStage `
    -Name 'Deno format check' `
    -Arguments @('fmt', '--check', $functionsRoot) `
    -TimeoutSeconds $StageTimeoutSeconds `
    -FailureMessage 'Deno formatting check failed for Supabase Edge Functions.'

  Write-Host "Linting $($sourceFiles.Count) Supabase Edge Function source files..."
  Invoke-DenoStage `
    -Name 'Deno lint' `
    -Arguments @('lint', $functionsRoot) `
    -TimeoutSeconds $StageTimeoutSeconds `
    -FailureMessage 'Deno lint failed for Supabase Edge Functions.'

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
    Invoke-DenoStage `
      -Name "Deno type check for $entrypoint" `
      -Arguments @('check', $entrypoint) `
      -TimeoutSeconds $StageTimeoutSeconds `
      -FailureMessage "Deno type check failed: $entrypoint"
  }

  if ($RunTests) {
    $tests = @(Get-ChildItem -Path $functionsRoot -Recurse -File -Filter '*_test.ts' | Sort-Object FullName)
    if ($tests.Count -eq 0) {
      throw 'RunTests was requested, but no Supabase Edge Function tests were found.'
    }

    Write-Host "Running $($tests.Count) Supabase Edge Function test files..."
    $declaredTestCount = 0
    foreach ($test in $tests) {
      Write-Host " - $($test.FullName.Substring($root.Length + 1))"
      $declarations = [regex]::Matches(
        (Get-Content -LiteralPath $test.FullName -Raw),
        '\bDeno\.test\s*\('
      ).Count
      if ($declarations -le 0) {
        throw "Edge Function test file declares no Deno.test cases: $($test.FullName)"
      }
      $declaredTestCount += $declarations
    }

    $resolvedTestReportPath = if ([System.IO.Path]::IsPathRooted($TestReportPath)) {
      [System.IO.Path]::GetFullPath($TestReportPath)
    } else {
      [System.IO.Path]::GetFullPath((Join-Path $root $TestReportPath))
    }
    $testReportDirectory = Split-Path -Parent $resolvedTestReportPath
    if (-not [string]::IsNullOrWhiteSpace($testReportDirectory)) {
      New-Item -ItemType Directory -Path $testReportDirectory -Force | Out-Null
    }
    if (Test-Path -LiteralPath $resolvedTestReportPath) {
      Remove-Item -LiteralPath $resolvedTestReportPath -Force
    }

    $testArguments = @(
      'test'
      '--fail-fast=1'
      "--junit-path=$resolvedTestReportPath"
    ) + @($tests | ForEach-Object { $_.FullName })
    Invoke-DenoStage `
      -Name 'Deno test' `
      -Arguments $testArguments `
      -TimeoutSeconds $TestTimeoutSeconds `
      -FailureMessage 'Deno test failed for Supabase Edge Functions.'

    $testEvidence = Read-DenoTestReport -Path $resolvedTestReportPath
    if ($testEvidence.TestCases -lt $tests.Count -or
      $testEvidence.TestCases -lt $declaredTestCount) {
      throw "Deno test JUnit report has $($testEvidence.TestCases) cases for $($tests.Count) files and $declaredTestCount declared Deno.test calls."
    }
    Write-Host (
      'Deno test completion evidence: {0} files, {1} test cases, {2} completed, {3} failures, {4} errors, {5} skipped. JUnit: {6}' -f
        $tests.Count,
        $testEvidence.TestCases,
        $testEvidence.Completed,
        $testEvidence.Failures,
        $testEvidence.Errors,
        $testEvidence.Skipped,
        $resolvedTestReportPath
    )
  }

  Write-Host 'Supabase Edge Function gate passed.' -ForegroundColor Green
} finally {
  Pop-Location
}
