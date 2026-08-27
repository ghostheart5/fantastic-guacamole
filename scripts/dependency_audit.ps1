param(
  [string]$OutputDirectory = 'artifacts/dependency-audit'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$output = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force -Path $output | Out-Null

if (-not (Test-Path 'pubspec.lock')) { throw 'pubspec.lock is required and must be committed.' }

$lockHash = (Get-FileHash 'pubspec.lock' -Algorithm SHA256).Hash.ToLowerInvariant()
@{
  generatedAtUtc = [DateTime]::UtcNow.ToString('o')
  lockfile = 'pubspec.lock'
  lockfileSha256 = $lockHash
  licenseReview = 'Review resolved package licenses before release; this report intentionally does not infer license approval.'
} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $output 'manifest.json')

# Emit a dependency-only CycloneDX inventory from the committed lockfile. It
# deliberately contains package names/versions and no credentials; licenses
# and advisories are attached by the release owner during review.
$components = New-Object System.Collections.Generic.List[object]
$currentPackage = $null
foreach ($line in (Get-Content 'pubspec.lock')) {
  $packageMatch = [regex]::Match($line, '^  ([A-Za-z0-9_+.-]+):\s*$')
  if ($packageMatch.Success) {
    $currentPackage = $packageMatch.Groups[1].Value
    continue
  }
  if ($null -ne $currentPackage) {
    $versionMatch = [regex]::Match($line, '^\s{4}version:\s*["'']([^"'']+)["'']\s*$')
    if ($versionMatch.Success) {
      $version = $versionMatch.Groups[1].Value
      $components.Add([ordered]@{
          type = 'library'
          name = $currentPackage
          version = $version
          purl = "pkg:dart/$currentPackage@$version"
        })
      $currentPackage = $null
    }
  }
}
@{
  bomFormat = 'CycloneDX'
  specVersion = '1.5'
  version = 1
  metadata = @{ timestamp = [DateTime]::UtcNow.ToString('o') }
  components = $components
} | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $output 'sbom.cdx.json')

if (Get-Command flutter -ErrorAction SilentlyContinue) {
  flutter pub deps --json | Set-Content -Encoding utf8 (Join-Path $output 'pub-deps.json')
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub deps failed.' }
  flutter pub outdated --json | Set-Content -Encoding utf8 (Join-Path $output 'pub-outdated.json')
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub outdated failed.' }
} else {
  Write-Warning 'Flutter is unavailable; dependency report contains lockfile evidence only.'
}

Write-Host "Dependency audit written to $output" -ForegroundColor Green
