[CmdletBinding()]
param([string]$BaselineScannerPath)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$scannerDirectory = Join-Path $repositoryRoot 'scripts'
. (Join-Path $scannerDirectory 'android_runtime_fatal_patterns.ps1')
$patterns = @(Get-ChronoSparkFatalDiagnosticPatterns)
$diagnostic = '09-05 22:36:42.123 1234 1234 I flutter : [ERROR][logger.categorized_error] [Riverpod Errors] Provider failure -> FutureProvider<void> | Bad state: Account-owned preference storage is not writable.'
$cases = @(
    @{ Name = 'observed account preference failure'; Text = $diagnostic; Fatal = $true },
    @{ Name = 'different provider and exception'; Text = 'I/flutter: [ERROR][logger.categorized_error] [Riverpod Errors] Provider failure -> NamedProvider | StateError'; Fatal = $true },
    @{ Name = 'release code only'; Text = 'I/flutter: [ERROR][logger.categorized_error]'; Fatal = $true },
    @{ Name = 'release CRLF and whitespace'; Text = "I/flutter: [ERROR][logger.categorized_error] `t`r`n"; Fatal = $true },
    @{ Name = 'case insensitive diagnostics'; Text = 'I/flutter: [error][logger.categorized_error] [riverpod errors] provider failure -> provider'; Fatal = $true },
    @{ Name = 'provider lifecycle information'; Text = 'I/flutter: [Riverpod] DISPOSE -> FutureProvider<void>'; Fatal = $false },
    @{ Name = 'categorized warning'; Text = 'I/flutter: [WARN][logger.categorized_error] [Riverpod Errors] Provider failure -> ignored text'; Fatal = $false },
    @{ Name = 'categorized information'; Text = 'I/flutter: [INFO][logger.categorized_error]'; Fatal = $false },
    @{ Name = 'unrelated detailed error category'; Text = 'I/flutter: [ERROR][logger.categorized_error] [Audio] optional initialization unavailable'; Fatal = $false },
    @{ Name = 'ordinary text'; Text = 'I/flutter: Provider failure is mentioned in fixture instructions'; Fatal = $false },
    @{ Name = 'stack is not counted again'; Text = 'I/flutter: [STACK][logger.categorized_error] stack detail'; Fatal = $false }
)
$results = [System.Collections.Generic.List[object]]::new()
foreach ($case in $cases) {
    # Maestro/diagnose use Select-String; monkey uses Regex.Matches over the
    # complete log. Exercise both real matching forms, including CRLF input.
    $lineMatch = @($case.Text -split "`n" | Select-String -Pattern $patterns -CaseSensitive:$false).Count -gt 0
    $wholeLogMatch = $false
    foreach ($pattern in $patterns) {
        if ([regex]::Matches($case.Text, $pattern).Count -gt 0) { $wholeLogMatch = $true }
    }
    if ($lineMatch -ne $case.Fatal -or $wholeLogMatch -ne $case.Fatal) {
        throw "Scanner behavior failed: $($case.Name)"
    }
    $results.Add([ordered]@{ name = $case.Name; passed = $true })
}

$temporaryParent = [System.IO.Path]::GetTempPath()
$temporaryRoot = Join-Path $temporaryParent ('chronospark-fatal-scanner-' + [guid]::NewGuid().ToString('N'))
$logsDirectory = Join-Path $temporaryRoot 'logs'
[void](New-Item -ItemType Directory -Path $logsDirectory)
$fixtureLog = Join-Path $logsDirectory 'android-logcat-fixture.log'
function Invoke-ScannerFixture {
    param([string]$ScannerPath, [string]$LogText)
    [System.IO.File]::WriteAllText($fixtureLog, $LogText, [System.Text.UTF8Encoding]::new($false))
    $process = [System.Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = (Get-Process -Id $PID).Path
        $process.StartInfo.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $ScannerPath + '"'
        $process.StartInfo.WorkingDirectory = $temporaryRoot
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start()) { throw 'Scanner fixture did not start.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            [void]$process.WaitForExit(5000)
            throw 'Scanner fixture timed out.'
        }
        [void]$stdout.GetAwaiter().GetResult()
        $errorText = $stderr.GetAwaiter().GetResult()
        if ($errorText) { throw 'Scanner fixture emitted unexpected stderr.' }
        return $process.ExitCode
    }
    finally { $process.Dispose() }
}

try {
    $scanner = Join-Path $scannerDirectory 'android_logcat_scan_latest.ps1'
    $cliCases = @(
        @{ Name = 'CLI rejects categorized provider error'; Text = $diagnostic; Exit = 1 },
        @{ Name = 'CLI rejects code-only release error'; Text = 'I/flutter: [ERROR][logger.categorized_error]'; Exit = 1 },
        @{ Name = 'CLI preserves existing fatal marker rejection'; Text = 'E/flutter: Failed assertion'; Exit = 1 },
        @{ Name = 'CLI accepts benign provider lifecycle'; Text = 'I/flutter: [Riverpod] DISPOSE -> FutureProvider<void>'; Exit = 0 }
    )
    foreach ($case in $cliCases) {
        $actual = Invoke-ScannerFixture -ScannerPath $scanner -LogText $case.Text
        if ($actual -ne $case.Exit) { throw "Scanner exit contract failed: $($case.Name); exit=$actual" }
        $results.Add([ordered]@{ name = $case.Name; passed = $true })
    }
    $baselineMisses = $null
    if ($BaselineScannerPath) {
        $baseline = (Resolve-Path -LiteralPath $BaselineScannerPath).Path
        $baselineMisses = 0
        foreach ($case in $cliCases | Where-Object { $_.Exit -eq 1 }) {
            if ((Invoke-ScannerFixture -ScannerPath $baseline -LogText $case.Text) -eq 0) { $baselineMisses++ }
        }
        if ($baselineMisses -ne 3) { throw 'Preserved baseline did not reproduce all three false-green exit cases.' }
    }
    [ordered]@{
        status = 'passed'
        passed = $results.Count
        failed = 0
        baselineFalseGreenCasesReproduced = $baselineMisses
        cases = @($results)
    } | ConvertTo-Json -Depth 5
}
finally {
    $resolvedTemporaryRoot = (Resolve-Path -LiteralPath $temporaryRoot).Path
    $expectedParent = [System.IO.Path]::GetFullPath($temporaryParent).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTemporaryRoot.StartsWith($expectedParent, [System.StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolvedTemporaryRoot) -notlike 'chronospark-fatal-scanner-*') {
        throw 'Refusing fixture cleanup outside its exact temporary directory.'
    }
    Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
}
