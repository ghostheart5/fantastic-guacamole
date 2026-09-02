[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$contracts = @(
    [ordered]@{
        Test = 'test/features/auth/login_screen_golden_test.dart'
        GoldenDirectory = 'test/features/auth/goldens'
        Files = @(
            'login_screen_compact_320.png'
            'login_screen_regular_500.png'
        )
    }
    [ordered]@{
        Test = 'test/features/nexus/nexus_screen_golden_test.dart'
        GoldenDirectory = 'test/features/nexus/goldens'
        Files = @(
            'nexus_screen_ultraCompact_320.png'
            'nexus_screen_compact_375.png'
            'nexus_screen_regular_500.png'
        )
    }
)

$platforms = @('windows', 'linux')
$logicalComparisonCount = 0
$masterCount = 0
$matcherDeclarationCount = 0

foreach ($contract in $contracts) {
    $testPath = [string]$contract.Test
    if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
        throw "Golden test is missing: $testPath"
    }

    $source = Get-Content -Raw -LiteralPath $testPath
    $matchers = [regex]::Matches($source, 'matchesGoldenFile\s*\(').Count
    if ($matchers -lt 1) {
        throw "Golden test performs zero comparisons: $testPath"
    }
    $matcherDeclarationCount += $matchers

    foreach ($file in $contract.Files) {
        $fileName = [string]$file
        $singleQuotedCall = "platformGoldenFile('$fileName')"
        $doubleQuotedCall = 'platformGoldenFile("' + $fileName + '")'
        $mappingCount = [regex]::Matches(
            $source,
            [regex]::Escape($singleQuotedCall)
        ).Count + [regex]::Matches(
            $source,
            [regex]::Escape($doubleQuotedCall)
        ).Count
        if ($mappingCount -ne 1) {
            throw "Golden file needs exactly one platform-routed declaration: $fileName"
        }
        $logicalComparisonCount++

        foreach ($platform in $platforms) {
            $platformDirectory = Join-Path ([string]$contract.GoldenDirectory) $platform
            $masterPath = Join-Path $platformDirectory $fileName
            if (-not (Test-Path -LiteralPath $masterPath -PathType Leaf)) {
                throw "Golden platform master is missing: $masterPath"
            }
            $masterCount++
        }
    }
}

if (
    $logicalComparisonCount -lt 1 -or
    $matcherDeclarationCount -ne $logicalComparisonCount -or
    $masterCount -ne ($logicalComparisonCount * $platforms.Count)
) {
    throw (
        'Golden comparison contract needs one matcher per logical comparison ' +
        'and one master per supported platform; ' +
        "found $matcherDeclarationCount matchers, $logicalComparisonCount " +
        "logical comparisons, and $masterCount platform masters."
    )
}

Write-Output (
    "Golden comparison contract: {0} exact logical comparisons and {1} platform masters across {2} test files." -f
        $logicalComparisonCount,
        $masterCount,
        $contracts.Count
)
