$ErrorActionPreference = 'Stop'
$root = Get-Location
$lcovPath = Join-Path $root 'coverage/lcov.info'
if (!(Test-Path $lcovPath)) { throw "coverage/lcov.info not found" }

function RelPath([string]$absPath) {
  return [System.IO.Path]::GetRelativePath($root.Path, $absPath).Replace('\\','/')
}

function GetImportance([string]$relPath) {
  $p = $relPath.ToLowerInvariant()
  if ($p -match '^lib/features/auth/' -or
      $p -match '^lib/state/' -or
      $p -match '^lib/.*/providers?/' -or
      $p -match '^lib/.*/services?/' -or
      $p -match '^lib/.*/repositories?/' -or
      $p -match '^lib/.*/storage/' -or
      $p -match '^lib/features/(timeline|creator|nexus|trajectory_engine|home|settings|profile)/') {
    return 'Critical'
  }
  if ($p -match '^lib/features/' -or $p -match '^lib/data/' -or $p -match '^lib/app/') { return 'High' }
  if ($p -match '^lib/(core|domain|engine|ui|theme|tutorial)/') { return 'Medium' }
  return 'Low'
}

function WhyMatters([string]$relPath, [string]$importance) {
  $p = $relPath.ToLowerInvariant()
  if ($p -match '/auth/') { return 'Authentication stability and account trust depend on this path.' }
  if ($p -match '/state/' -or $p -match '/providers?/') { return 'Shared application state behavior here impacts multiple screens and flows.' }
  if ($p -match '/repositories?/') { return 'Repository behavior controls data correctness and integration boundaries.' }
  if ($p -match '/services?/') { return 'Service branch behavior drives reliability, retries, and failure handling.' }
  if ($p -match '/storage/') { return 'Storage code protects persistence and migration safety.' }
  if ($p -match '/timeline/') { return 'Timeline is a core execution/review surface in the product loop.' }
  if ($p -match '/creator/') { return 'Creator is the primary entry flow for creating user value.' }
  if ($p -match '/nexus/') { return 'Nexus orchestrates first-view comprehension and top-level navigation.' }
  if ($p -match '/trajectory/') { return 'Trajectory/future surfaces affect planning confidence and strategic decisions.' }
  if ($p -match '/smart_coach|/home/') { return 'Smart coach and home guidance influence daily engagement and retention.' }
  if ($p -match '/settings/') { return 'Settings impacts trust, user control, and recovery actions.' }
  if ($p -match '/profile/') { return 'Profile/account surfaces affect identity confidence and account operations.' }
  switch ($importance) {
    'Critical' { return 'Core path with high user/business impact if regressions occur.' }
    'High' { return 'Important feature path with meaningful user impact.' }
    'Medium' { return 'Supporting path that affects quality and consistency.' }
    default { return 'Peripheral path with lower direct impact.' }
  }
}

function QuickestTests([string]$relPath) {
  $p = $relPath.ToLowerInvariant()
  if ($p -match '/providers?/') { return 'ProviderContainer tests for defaults, notifier transitions, and override branches.' }
  if ($p -match '/repositories?/') { return 'Repository contract tests with fake data sources: success, empty, and error mapping.' }
  if ($p -match '/services?/') { return 'Service unit tests for happy path, timeout, and failure fallback branches.' }
  if ($p -match '/storage/') { return 'Serialization/migration tests: valid payload, invalid payload, and backward compatibility.' }
  if ($p -match '/timeline/') { return 'Widget tests for event rendering, filters, and action callbacks with mocked providers.' }
  if ($p -match '/creator/') { return 'Form validation/submit tests and mode-specific creation branches.' }
  if ($p -match '/nexus/') { return 'Widget smoke tests for key sections plus state/status rendering branches.' }
  if ($p -match '/trajectory/') { return 'Computation tests plus primary panel rendering states.' }
  if ($p -match '/smart_coach|/home/') { return 'Hero/decision widget tests across online-offline and recommendation states.' }
  if ($p -match '/settings/') { return 'Section rendering + toggle/command interaction tests with mocked actions.' }
  if ($p -match '/profile/') { return 'Header/account widget rendering and callback branch tests.' }
  if ($p -match '/auth/') { return 'Auth widget tests for signed-out, signed-in, loading, and error states.' }
  return 'Target branch-focused tests on public methods and conditional paths.'
}

# Inventory files
$libFiles = Get-ChildItem (Join-Path $root 'lib') -Recurse -File -Filter *.dart | ForEach-Object { $_.FullName }
$testFiles = Get-ChildItem (Join-Path $root 'test') -Recurse -File -Filter *.dart | ForEach-Object { $_.FullName }

# Parse lcov
$cov = @{}
$current = $null
Get-Content $lcovPath | ForEach-Object {
  $line = $_
  if ($line.StartsWith('SF:')) {
    $sfRaw = $line.Substring(3)
    $sfAbs = if ([System.IO.Path]::IsPathRooted($sfRaw)) { [System.IO.Path]::GetFullPath($sfRaw) } else { [System.IO.Path]::GetFullPath((Join-Path $root $sfRaw)) }
    $key = $sfAbs.ToLowerInvariant()
    if (!($cov.ContainsKey($key))) { $cov[$key] = [PSCustomObject]@{ LF = 0; LH = 0 } }
    $current = $key
  } elseif ($line.StartsWith('LF:') -and $current) {
    $obj = $cov[$current]; $obj.LF = [int]$line.Substring(3); $cov[$current] = $obj
  } elseif ($line.StartsWith('LH:') -and $current) {
    $obj = $cov[$current]; $obj.LH = [int]$line.Substring(3); $cov[$current] = $obj
  } elseif ($line -eq 'end_of_record') {
    $current = $null
  }
}

$rows = foreach ($f in $libFiles) {
  $rel = RelPath $f
  $lineCount = (Get-Content $f | Measure-Object -Line).Lines
  $key = $f.ToLowerInvariant()
  $lf = 0; $lh = 0
  if ($cov.ContainsKey($key)) { $lf = [int]$cov[$key].LF; $lh = [int]$cov[$key].LH }
  $pct = if ($lf -gt 0) { [Math]::Round(($lh * 100.0 / $lf), 2) } else { 0.0 }
  $uncovered = [Math]::Max(0, $lf - $lh)
  [PSCustomObject]@{
    RelPath = $rel
    AbsPath = $f
    LineCount = $lineCount
    LF = $lf
    LH = $lh
    Pct = $pct
    Uncovered = $uncovered
    Importance = GetImportance $rel
  }
}

$totalLF = ($rows | Measure-Object -Property LF -Sum).Sum
$totalLH = ($rows | Measure-Object -Property LH -Sum).Sum
if (-not $totalLF) { $totalLF = 0 }
if (-not $totalLH) { $totalLH = 0 }
$currentPct = if ($totalLF -gt 0) { [Math]::Round(($totalLH*100.0/$totalLF), 2) } else { 0.0 }

$b0 = $rows | Where-Object { $_.Pct -eq 0 } | Sort-Object RelPath
$b1 = $rows | Where-Object { $_.Pct -gt 0 -and $_.Pct -le 10 } | Sort-Object RelPath
$b2 = $rows | Where-Object { $_.Pct -gt 10 -and $_.Pct -le 25 } | Sort-Object RelPath
$b3 = $rows | Where-Object { $_.Pct -gt 25 -and $_.Pct -le 50 } | Sort-Object RelPath
$b4 = $rows | Where-Object { $_.Pct -gt 50 -and $_.Pct -le 80 } | Sort-Object RelPath
$b5 = $rows | Where-Object { $_.Pct -gt 80 -and $_.Pct -le 100 } | Sort-Object RelPath

$top25 = $rows | Sort-Object @{Expression='Uncovered';Descending=$true}, @{Expression='LineCount';Descending=$true} | Select-Object -First 25

# Test corpus and explicit imports
$testCorpus = ''
$imported = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($tf in $testFiles) {
  $txt = Get-Content $tf -Raw
  $low = $txt.ToLowerInvariant()
  $testCorpus += "`n$low"
  $matches = [regex]::Matches($txt, "import\\s+['\"]([^'\"]+)['\"]")
  foreach ($m in $matches) {
    $uri = $m.Groups[1].Value
    if ($uri.StartsWith('package:fantastic_guacamole/')) {
      $rel = 'lib/' + $uri.Substring('package:fantastic_guacamole/'.Length)
      [void]$imported.Add($rel.ToLowerInvariant())
    } elseif ($uri.StartsWith('./') -or $uri.StartsWith('../')) {
      $resolved = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetDirectoryName($tf)) $uri))
      if ($resolved.ToLowerInvariant().StartsWith($root.Path.ToLowerInvariant())) {
        [void]$imported.Add((RelPath $resolved).ToLowerInvariant())
      }
    }
  }
}

$neverImported = $rows | Where-Object { -not $imported.Contains($_.RelPath.ToLowerInvariant()) } | Sort-Object RelPath

function ExtractSymbols([string]$absPath, [string]$regexPattern) {
  $txt = Get-Content $absPath -Raw
  $ms = [regex]::Matches($txt, $regexPattern)
  return ($ms | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -Unique)
}

$providerFiles = $rows | Where-Object { $_.RelPath -match '^lib/.*/providers?/.*\.dart$' -or $_.RelPath -match '^lib/state/providers/.*\.dart$' }
$repoFiles = $rows | Where-Object { $_.RelPath -match '^lib/.*/repositories?/.*\.dart$' }
$serviceFiles = $rows | Where-Object { $_.RelPath -match '^lib/.*/services?/.*\.dart$' }

$providersNever = @()
foreach ($pf in $providerFiles) {
  $symbols = @()
  $symbols += ExtractSymbols $pf.AbsPath 'final\s+([A-Za-z0-9_]+Provider)\s*='
  $symbols += ExtractSymbols $pf.AbsPath 'class\s+([A-Za-z0-9_]+Notifier)\b'
  $symbols = $symbols | Select-Object -Unique
  if ($symbols.Count -eq 0) { continue }
  $hit = $false
  foreach ($s in $symbols) { if ($testCorpus.Contains($s.ToLowerInvariant())) { $hit = $true; break } }
  if (-not $hit) {
    $providersNever += [PSCustomObject]@{ RelPath=$pf.RelPath; Symbols=($symbols -join ', ') }
  }
}

$reposNever = @()
foreach ($rf in $repoFiles) {
  $symbols = ExtractSymbols $rf.AbsPath 'class\s+([A-Za-z0-9_]*Repository)\b'
  if ($symbols.Count -eq 0) { $symbols = @([System.IO.Path]::GetFileNameWithoutExtension($rf.RelPath)) }
  $hit = $false
  foreach ($s in $symbols) { if ($testCorpus.Contains($s.ToLowerInvariant())) { $hit = $true; break } }
  if (-not $hit) {
    $reposNever += [PSCustomObject]@{ RelPath=$rf.RelPath; Symbols=($symbols -join ', ') }
  }
}

$servicesNever = @()
foreach ($sf in $serviceFiles) {
  $symbols = ExtractSymbols $sf.AbsPath 'class\s+([A-Za-z0-9_]*Service)\b'
  if ($symbols.Count -eq 0) { $symbols = @([System.IO.Path]::GetFileNameWithoutExtension($sf.RelPath)) }
  $hit = $false
  foreach ($s in $symbols) { if ($testCorpus.Contains($s.ToLowerInvariant())) { $hit = $true; break } }
  if (-not $hit) {
    $servicesNever += [PSCustomObject]@{ RelPath=$sf.RelPath; Symbols=($symbols -join ', ') }
  }
}

# Rank candidates for phase route
$priorityRegex = 'auth|state|providers|services|repositories|storage|timeline|creator|nexus|trajectory|smart_coach|settings|profile'
$ranked = $rows | Where-Object { $_.LF -gt 0 -and $_.Uncovered -gt 0 } | ForEach-Object {
  $impScore = switch ($_.Importance) { 'Critical' { 4 } 'High' { 3 } 'Medium' { 2 } default { 1 } }
  $prioBoost = if ($_.RelPath.ToLowerInvariant() -match $priorityRegex) { 2 } else { 0 }
  $uiPenalty = if ($_.RelPath -match '/ui/|/widgets?/') { 0.8 } else { 1.0 }
  $score = ($impScore + $prioBoost) * ($_.Uncovered + 1) * ((100 - $_.Pct)/100.0) * $uiPenalty
  $_ | Add-Member -NotePropertyName Score -NotePropertyValue $score -PassThru
} | Sort-Object @{Expression='Score';Descending=$true}

function BuildPhase([double]$targetPct, [double]$startPct, [int]$startIndex) {
  $needPct = [Math]::Max(0, $targetPct - $startPct)
  $needLines = [Math]::Ceiling(($needPct/100.0) * $totalLF)
  $picked = @()
  $acc = 0
  $i = $startIndex
  while ($i -lt $ranked.Count -and $acc -lt $needLines) {
    $r = $ranked[$i]
    $coverFactor = if ($r.RelPath -match '/providers?/|/repositories?/|/services?/|/storage/') { 0.45 } elseif ($r.RelPath -match '/ui/|/widgets?/') { 0.22 } else { 0.30 }
    $gainLines = [Math]::Max(1, [Math]::Floor($r.Uncovered * $coverFactor))
    $picked += [PSCustomObject]@{ RelPath=$r.RelPath; Importance=$r.Importance; Pct=$r.Pct; Uncovered=$r.Uncovered; EstGainLines=$gainLines }
    $acc += $gainLines
    $i++
  }
  $gainPct = if ($totalLF -gt 0) { [Math]::Round(($acc*100.0/$totalLF),2) } else { 0 }
  return [PSCustomObject]@{ Picked=$picked; GainLines=$acc; GainPct=$gainPct; NextIndex=$i }
}

$phaseA = BuildPhase 20 $currentPct 0
$phaseB = BuildPhase 40 ($currentPct + $phaseA.GainPct) $phaseA.NextIndex
$phaseC = BuildPhase 60 ($currentPct + $phaseA.GainPct + $phaseB.GainPct) $phaseB.NextIndex

$outDir = Join-Path $root 'tool/test_audit'
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = Join-Path $outDir 'coverage_attack_plan.md'

$sb = New-Object System.Text.StringBuilder
$append = { param([string]$s) [void]$sb.AppendLine($s) }

& $append '# Coverage Attack Plan'
& $append ''
& $append "Source: coverage/lcov.info"
& $append "Scanned lib files: $($rows.Count)"
& $append "Scanned test files: $($testFiles.Count)"
& $append "Current aggregate line coverage (from lcov): $currentPct%"
& $append ''

& $append '## Coverage Buckets'
& $append "- 0% coverage: $($b0.Count) files"
& $append "- 1-10% coverage: $($b1.Count) files"
& $append "- 11-25% coverage: $($b2.Count) files"
& $append "- 26-50% coverage: $($b3.Count) files"
& $append "- 51-80% coverage: $($b4.Count) files"
& $append "- 81-100% coverage: $($b5.Count) files"
& $append ''

foreach ($bucket in @(
  @{Name='0% coverage'; Data=$b0},
  @{Name='1-10% coverage'; Data=$b1},
  @{Name='11-25% coverage'; Data=$b2},
  @{Name='26-50% coverage'; Data=$b3},
  @{Name='51-80% coverage'; Data=$b4},
  @{Name='81-100% coverage'; Data=$b5}
)) {
  & $append "### $($bucket.Name)"
  foreach ($f in $bucket.Data) {
    & $append "- $($f.RelPath) ($($f.Pct)% | LF=$($f.LF), LH=$($f.LH), uncovered=$($f.Uncovered))"
  }
  & $append ''
}

& $append '## Top 25 Largest Uncovered Dart Files'
& $append '| # | path | line count | business importance | LF | LH | uncovered | coverage |'
& $append '|---|---|---:|---|---:|---:|---:|---:|'
$idx = 1
foreach ($f in $top25) {
  & $append "| $idx | $($f.RelPath) | $($f.LineCount) | $($f.Importance) | $($f.LF) | $($f.LH) | $($f.Uncovered) | $($f.Pct)% |"
  $idx++
}
& $append ''

& $append '## Priority Area Focus (lowest coverage first)'
& $append '| path | coverage | uncovered | importance |'
& $append '|---|---:|---:|---|'
foreach ($f in ($rows | Where-Object { $_.RelPath.ToLowerInvariant() -match $priorityRegex } | Sort-Object @{Expression='Pct';Ascending=$true}, @{Expression='Uncovered';Descending=$true})) {
  & $append "| $($f.RelPath) | $($f.Pct)% | $($f.Uncovered) | $($f.Importance) |"
}
& $append ''

& $append '## Coverage Attack Cards (for every uncovered file)'
foreach ($f in ($rows | Where-Object { $_.Uncovered -gt 0 } | Sort-Object @{Expression='Importance';Descending=$false}, @{Expression='Uncovered';Descending=$true}, RelPath)) {
  $coverFactor = if ($f.RelPath -match '/providers?/|/repositories?/|/services?/|/storage/') { 0.45 } elseif ($f.RelPath -match '/ui/|/widgets?/') { 0.22 } else { 0.30 }
  $gainLines = [Math]::Max(1, [Math]::Floor($f.Uncovered * $coverFactor))
  $gainPct = if ($totalLF -gt 0) { [Math]::Round(($gainLines*100.0/$totalLF),4) } else { 0 }
  & $append "### $($f.RelPath)"
  & $append "- why it matters: $(WhyMatters $f.RelPath $f.Importance)"
  & $append "- quickest tests to cover it: $(QuickestTests $f.RelPath)"
  & $append "- estimated coverage gain: +$gainPct%"
  & $append ''
}

& $append '## Files Never Imported by Any Test'
& $append "Count: $($neverImported.Count)"
foreach ($f in $neverImported) { & $append "- $($f.RelPath)" }
& $append ''

& $append '## Providers Never Exercised by Any Test'
& $append "Count: $($providersNever.Count)"
foreach ($p in ($providersNever | Sort-Object RelPath)) { & $append "- $($p.RelPath) :: $($p.Symbols)" }
& $append ''

& $append '## Repositories Never Exercised by Any Test'
& $append "Count: $($reposNever.Count)"
foreach ($r in ($reposNever | Sort-Object RelPath)) { & $append "- $($r.RelPath) :: $($r.Symbols)" }
& $append ''

& $append '## Services Never Exercised by Any Test'
& $append "Count: $($servicesNever.Count)"
foreach ($s in ($servicesNever | Sort-Object RelPath)) { & $append "- $($s.RelPath) :: $($s.Symbols)" }
& $append ''

& $append '## Ranked Route: 7% -> 20% -> 40% -> 60%'
& $append "Baseline coverage: $currentPct%"
& $append ''
& $append '### Phase A: Fastest route to ~20%'
& $append "Estimated gain: +$($phaseA.GainPct)%"
foreach ($p in $phaseA.Picked) {
  & $append "- $($p.RelPath) [$($p.Importance)] coverage=$($p.Pct)% uncovered=$($p.Uncovered) estGainLines=$($p.EstGainLines)"
}
& $append ''
& $append '### Phase B: Fastest route to ~40%'
& $append "Estimated gain: +$($phaseB.GainPct)% (cumulative +$([Math]::Round($phaseA.GainPct + $phaseB.GainPct,2))%)"
foreach ($p in $phaseB.Picked) {
  & $append "- $($p.RelPath) [$($p.Importance)] coverage=$($p.Pct)% uncovered=$($p.Uncovered) estGainLines=$($p.EstGainLines)"
}
& $append ''
& $append '### Phase C: Fastest route to ~60%'
& $append "Estimated gain: +$($phaseC.GainPct)% (cumulative +$([Math]::Round($phaseA.GainPct + $phaseB.GainPct + $phaseC.GainPct,2))%)"
foreach ($p in $phaseC.Picked) {
  & $append "- $($p.RelPath) [$($p.Importance)] coverage=$($p.Pct)% uncovered=$($p.Uncovered) estGainLines=$($p.EstGainLines)"
}
& $append ''

& $append 'Note: This report intentionally creates no tests.'

[System.IO.File]::WriteAllText($outFile, $sb.ToString())
Write-Output "WROTE: $outFile"
Write-Output "COVERAGE: $currentPct%"
Write-Output "BUCKET_COUNTS: 0=$($b0.Count),1-10=$($b1.Count),11-25=$($b2.Count),26-50=$($b3.Count),51-80=$($b4.Count),81-100=$($b5.Count)"
Write-Output "NEVER_IMPORTED: $($neverImported.Count)"
Write-Output "PROVIDERS_NEVER: $($providersNever.Count)"
Write-Output "REPOS_NEVER: $($reposNever.Count)"
Write-Output "SERVICES_NEVER: $($servicesNever.Count)"
