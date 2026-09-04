param(
  [string]$OutputDirectory = 'artifacts/dependency-audit',
  [switch]$SkipResolverReports
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$output = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force -Path $output | Out-Null

if (-not (Test-Path 'pubspec.lock')) { throw 'pubspec.lock is required and must be committed.' }

function Get-DirectDependencies {
  $dependencies = New-Object System.Collections.Generic.List[string]
  $inDependencies = $false
  foreach ($line in (Get-Content 'pubspec.yaml')) {
    if ($line -match '^dependencies:\s*$') {
      $inDependencies = $true
      continue
    }
    if ($line -match '^dev_dependencies:\s*$') {
      break
    }
    if ($inDependencies -and $line -match '^  ([A-Za-z0-9_]+):') {
      $dependencies.Add($matches[1]) | Out-Null
    }
  }
  return @($dependencies)
}

function Get-RegisteredCapabilityPackages {
  param([string]$Path)

  $packages = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($line in (Get-Content $Path)) {
    if (-not $line.StartsWith('|')) { continue }
    foreach ($match in [regex]::Matches($line, '`([a-z][a-z0-9_]*)`')) {
      [void]$packages.Add($match.Groups[1].Value)
    }
  }
  return @($packages)
}

$directDependencies = @(Get-DirectDependencies)
$sourceRoots = @('lib', 'test', 'integration_test', 'tool')
$sourceFiles = New-Object System.Collections.Generic.List[string]
foreach ($sourceRoot in $sourceRoots) {
  if (Test-Path $sourceRoot) {
    foreach ($file in (Get-ChildItem $sourceRoot -Filter '*.dart' -Recurse -File)) {
      $sourceFiles.Add($file.FullName) | Out-Null
    }
  }
}
$allDartSource = [string]::Join(
  "`n",
  @($sourceFiles | ForEach-Object { [System.IO.File]::ReadAllText($_) })
)
$sdkDependencies = @('flutter', 'flutter_localizations')
$unusedDirectDependencies = @(
  $directDependencies | Where-Object {
    $_ -notin $sdkDependencies -and
    -not $allDartSource.Contains("package:$_/")
  }
)
if ($unusedDirectDependencies.Count -gt 0) {
  throw "Unused direct dependencies must be removed or explicitly used: $($unusedDirectDependencies -join ', ')"
}

$capabilityRegister = 'docs/DEPENDENCY_CAPABILITY_REGISTER.md'
if (-not (Test-Path $capabilityRegister)) {
  throw "$capabilityRegister is required."
}
$registeredCapabilityPackages = @(
  Get-RegisteredCapabilityPackages -Path $capabilityRegister
)
$staleCapabilityPackages = @(
  $registeredCapabilityPackages | Where-Object {
    $_ -notin $directDependencies
  }
)
if ($staleCapabilityPackages.Count -gt 0) {
  throw "Capability register packages are absent from pubspec.yaml: $($staleCapabilityPackages -join ', ')"
}

$lockHash = (Get-FileHash 'pubspec.lock' -Algorithm SHA256).Hash.ToLowerInvariant()
@{
  generatedAtUtc = [DateTime]::UtcNow.ToString('o')
  lockfile = 'pubspec.lock'
  lockfileSha256 = $lockHash
  licenseReview = 'Review resolved package licenses before release; this report intentionally does not infer license approval.'
} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $output 'manifest.json')

@{
  directDependencies = $directDependencies
  registeredCapabilityPackages = $registeredCapabilityPackages
  scannedDartFiles = $sourceFiles.Count
  unusedDirectDependencies = @()
  staleCapabilityPackages = @()
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $output 'manifest-consistency.json')

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

if (-not $SkipResolverReports -and (Get-Command flutter -ErrorAction SilentlyContinue)) {
  flutter pub deps --json | Set-Content -Encoding utf8 (Join-Path $output 'pub-deps.json')
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub deps failed.' }
  flutter pub outdated --json | Set-Content -Encoding utf8 (Join-Path $output 'pub-outdated.json')
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub outdated failed.' }
} elseif ($SkipResolverReports) {
  Write-Warning 'Resolver reports were explicitly skipped; manifest consistency and lockfile inventory were still checked.'
} else {
  Write-Warning 'Flutter is unavailable; dependency report contains lockfile evidence only.'
}

Write-Host "Dependency audit written to $output" -ForegroundColor Green
