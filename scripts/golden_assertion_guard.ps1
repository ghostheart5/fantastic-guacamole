[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$contracts = @(
    [ordered]@{
        Test = 'test/features/auth/login_screen_golden_test.dart'
        Baselines = @(
            'test/features/auth/goldens/login_screen_compact_320.png'
            'test/features/auth/goldens/login_screen_regular_500.png'
        )
    }
    [ordered]@{
        Test = 'test/features/nexus/nexus_screen_golden_test.dart'
        Baselines = @(
            'test/features/nexus/goldens/nexus_screen_ultraCompact_320.png'
            'test/features/nexus/goldens/nexus_screen_compact_375.png'
            'test/features/nexus/goldens/nexus_screen_regular_500.png'
        )
    }
)

$baselineCount = 0
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

    foreach ($baseline in $contract.Baselines) {
        $baselinePath = [string]$baseline
        if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
            throw "Golden baseline is missing: $baselinePath"
        }
        $fileName = [System.IO.Path]::GetFileName($baselinePath)
        $relativeGolden = "goldens/$fileName"
        $singleQuotedCall = "matchesGoldenFile('$relativeGolden')"
        $doubleQuotedCall = 'matchesGoldenFile("' + $relativeGolden + '")'
        $mappingCount = [regex]::Matches(
            $source,
            [regex]::Escape($singleQuotedCall)
        ).Count + [regex]::Matches(
            $source,
            [regex]::Escape($doubleQuotedCall)
        ).Count
        if ($mappingCount -ne 1) {
            throw "Golden baseline needs exactly one literal matcher declaration: $baselinePath"
        }
        $baselineCount++
    }
}

if ($baselineCount -lt 1 -or $matcherDeclarationCount -ne $baselineCount) {
    throw (
        'Golden comparison contract needs one literal matcher per baseline; ' +
        "found $matcherDeclarationCount matchers for $baselineCount baselines."
    )
}

Write-Output (
    "Golden comparison contract: {0} baselines and {1} matcher declarations across {2} test files." -f
        $baselineCount,
        $matcherDeclarationCount,
        $contracts.Count
)
