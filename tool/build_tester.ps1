[CmdletBinding()]
param(
    [switch]$SplitPerAbi
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$definesFile = Join-Path $PSScriptRoot 'qa_defines.json'

if (-not (Test-Path -LiteralPath $definesFile)) {
    throw "Missing QA configuration: $definesFile"
}

Push-Location $projectRoot
try {
    $arguments = @(
        'build'
        'apk'
        '--release'
        '--dart-define-from-file=tool/qa_defines.json'
    )

    if ($SplitPerAbi) {
        $arguments += '--split-per-abi'
    }

    & flutter @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter tester build failed with exit code $LASTEXITCODE."
    }

    Write-Host ''
    Write-Host 'ChronoSpark QA build completed.' -ForegroundColor Green
    if ($SplitPerAbi) {
        Write-Host 'Artifacts: build/app/outputs/flutter-apk/*-release.apk'
    } else {
        $sourceArtifact = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
        $qaArtifact = Join-Path $projectRoot 'build/app/outputs/flutter-apk/chronospark-qa-release.apk'
        Copy-Item -LiteralPath $sourceArtifact -Destination $qaArtifact -Force
        $hash = (Get-FileHash -LiteralPath $qaArtifact -Algorithm SHA256).Hash
        Write-Host 'Artifact: build/app/outputs/flutter-apk/chronospark-qa-release.apk'
        Write-Host "SHA-256: $hash"
    }
    Write-Host 'Mode: QA release, Tester Access enabled, cloud sync disabled.'
} finally {
    Pop-Location
}
