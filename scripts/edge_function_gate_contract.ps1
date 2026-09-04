$ErrorActionPreference = 'Stop'

$gate = Join-Path $PSScriptRoot 'edge_function_gate.ps1'
$failures = New-Object System.Collections.Generic.List[string]
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  'pwsh'
} elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  'powershell'
} else {
  throw 'PowerShell is required to run the Edge Function gate contract.'
}
if (-not (Get-Command deno -ErrorAction SilentlyContinue)) {
  throw 'Deno is required to run the Edge Function gate contract.'
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "chronospark-edge-gate-$([guid]::NewGuid().ToString('N'))"

function Set-FixtureFile {
  param(
    [string]$CaseRoot,
    [string]$RelativePath,
    [string]$Content
  )

  $path = Join-Path $CaseRoot $RelativePath
  New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
  Set-Content -LiteralPath $path -Value $Content -NoNewline
}

function New-EdgeFixture {
  param(
    [string]$Name,
    [string[]]$TestContents
  )

  $caseRoot = Join-Path $fixtureRoot $Name
  Set-FixtureFile `
    -CaseRoot $caseRoot `
    -RelativePath 'supabase/functions/alpha/index.ts' `
    -Content "export const alpha = 1;`n"
  Set-FixtureFile `
    -CaseRoot $caseRoot `
    -RelativePath 'supabase/functions/beta/index.ts' `
    -Content "export const beta = 2;`n"
  for ($index = 0; $index -lt $TestContents.Count; $index++) {
    Set-FixtureFile `
      -CaseRoot $caseRoot `
      -RelativePath "supabase/functions/alpha/fixture_$($index + 1)_test.ts" `
      -Content $TestContents[$index]
  }
  return $caseRoot
}

function Invoke-ContractCase {
  param(
    [string]$Name,
    [string]$CaseRoot,
    [int]$ExpectedExitCode,
    [string[]]$ExpectedMessages,
    [int]$TestTimeoutSeconds = 30
  )

  $arguments = @('-NoProfile')
  if ($env:OS -eq 'Windows_NT') {
    $arguments += @('-ExecutionPolicy', 'Bypass')
  }
  $arguments += @(
    '-File', $gate,
    '-RunTests',
    '-RepositoryRoot', $CaseRoot,
    '-StageTimeoutSeconds', '30',
    '-TestTimeoutSeconds', $TestTimeoutSeconds.ToString()
  )

  $output = & $powerShellCommand @arguments 2>&1
  $exitCode = $LASTEXITCODE
  $outputText = $output -join "`n"
  if ($exitCode -ne $ExpectedExitCode) {
    $failures.Add(
      "$Name expected exit code $ExpectedExitCode but received $exitCode.`n$outputText"
    )
  }
  foreach ($expectedMessage in $ExpectedMessages) {
    if ($outputText -notmatch [regex]::Escape($expectedMessage)) {
      $failures.Add("$Name did not emit expected message '$expectedMessage'.`n$outputText")
    }
  }
}

try {
  $successful = New-EdgeFixture `
    -Name 'successful' `
    -TestContents @(
      "Deno.test(`"alpha passes`", () => {});`n",
      "Deno.test(`"beta passes`", () => {});`n"
    )
  Invoke-ContractCase `
    -Name 'Every discovered test file produces validated JUnit completion evidence' `
    -CaseRoot $successful `
    -ExpectedExitCode 0 `
    -ExpectedMessages @(
      'Type-checking 2 Supabase Edge Functions...',
      'Running 2 Supabase Edge Function test files...',
      'Deno test completion evidence: 2 files, 2 test cases, 2 completed, 0 failures, 0 errors, 0 skipped.',
      'Supabase Edge Function gate passed.'
    )

  $noCompletedTests = New-EdgeFixture `
    -Name 'no-completed-tests' `
    -TestContents @("// Discovered test file with no Deno.test declarations.`n")
  Invoke-ContractCase `
    -Name 'A discovered test file without completed tests fails closed' `
    -CaseRoot $noCompletedTests `
    -ExpectedExitCode 1 `
    -ExpectedMessages @('Edge Function test file declares no Deno.test cases:')

  $mixedEmptyTest = New-EdgeFixture `
    -Name 'mixed-empty-test-file' `
    -TestContents @(
      "Deno.test(`"completed test`", () => {});`n",
      "// Empty discovered test file must not borrow completion from its sibling.`n"
    )
  Invoke-ContractCase `
    -Name 'Every discovered Edge test file must declare a test' `
    -CaseRoot $mixedEmptyTest `
    -ExpectedExitCode 1 `
    -ExpectedMessages @('Edge Function test file declares no Deno.test cases:')

  $skippedTest = New-EdgeFixture `
    -Name 'skipped-test' `
    -TestContents @(
      "Deno.test(`"completed test`", () => {});`n",
      "Deno.test({ name: `"skipped test`", ignore: true, fn: () => {} });`n"
    )
  Invoke-ContractCase `
    -Name 'Skipped Edge Function tests fail closed' `
    -CaseRoot $skippedTest `
    -ExpectedExitCode 1 `
    -ExpectedMessages @('skipped test(s); skips are not allowed.')

  $timedOut = New-EdgeFixture `
    -Name 'timed-out' `
    -TestContents @(
      "Deno.test(`"never finishes in time`", async () => {`n  await new Promise((resolve) => setTimeout(resolve, 5000));`n});`n"
    )
  Invoke-ContractCase `
    -Name 'Deno test execution is bounded' `
    -CaseRoot $timedOut `
    -ExpectedExitCode 1 `
    -ExpectedMessages @('Deno test timed out after 1 seconds.') `
    -TestTimeoutSeconds 1

  $gateSource = Get-Content -LiteralPath $gate -Raw
  foreach ($requiredContract in @(
    "-Name 'Deno format check'",
    "-Name 'Deno lint'",
    '-Name "Deno type check for $entrypoint"',
    "-Name 'Deno test'",
    "'--fail-fast=1'",
    'Get-ChildItem -Path $functionsRoot -Recurse -File -Filter ''*_test.ts''',
    "ForEach-Object { Join-Path `$_.FullName 'index.ts' }"
  )) {
    if (-not $gateSource.Contains($requiredContract)) {
      $failures.Add("Gate source is missing required contract: $requiredContract")
    }
  }
} finally {
  $resolvedFixture = [System.IO.Path]::GetFullPath($fixtureRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedFixture.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Edge Function gate contract failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Edge Function gate contract passed.' -ForegroundColor Green
exit 0
