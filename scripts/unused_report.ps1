$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$libRoot = Join-Path $root 'lib'
$outFile = Join-Path $root 'tmp_unused_report.txt'

$allFiles = Get-ChildItem -Path $libRoot -Recurse -File -Filter *.dart | ForEach-Object { $_.FullName }

function Normalize-Path([string]$p) {
  return [System.IO.Path]::GetFullPath($p)
}

function Resolve-Import([string]$fromFile, [string]$uri) {
  if ($uri.StartsWith('dart:')) { return $null }
  if ($uri.StartsWith('package:')) {
    if ($uri.StartsWith('package:chronospark/')) {
      $sub = $uri.Substring('package:chronospark/'.Length).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
      return Normalize-Path (Join-Path $libRoot $sub)
    }
    return $null
  }

  $fromDir = Split-Path -Parent $fromFile
  $rel = $uri.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
  return Normalize-Path (Join-Path $fromDir $rel)
}

$edges = @{}
foreach ($f in $allFiles) {
  $text = Get-Content -Path $f -Raw
  $matches = [regex]::Matches($text, "(?m)^\s*(import|export|part)\s+'([^']+)'\s*;")
  $targets = New-Object System.Collections.Generic.List[string]
  foreach ($m in $matches) {
    $uri = $m.Groups[2].Value
    $resolved = Resolve-Import -fromFile $f -uri $uri
    if ($resolved -and (Test-Path $resolved)) {
      $targets.Add($resolved)
    }
  }
  $edges[$f] = $targets
}

$main = Normalize-Path (Join-Path $libRoot 'main.dart')
$visited = New-Object System.Collections.Generic.HashSet[string]
$queue = New-Object System.Collections.Generic.Queue[string]
if (Test-Path $main) {
  [void]$visited.Add($main)
  $queue.Enqueue($main)
}

while ($queue.Count -gt 0) {
  $cur = $queue.Dequeue()
  if (-not $edges.ContainsKey($cur)) { continue }
  foreach ($n in $edges[$cur]) {
    if ($visited.Add($n)) {
      $queue.Enqueue($n)
    }
  }
}

$unreachable = $allFiles | Where-Object { -not $visited.Contains($_) } | Sort-Object

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("TOTAL_DART_FILES=$($allFiles.Count)")
$lines.Add("REACHABLE_FROM_MAIN=$($visited.Count)")
$lines.Add("UNREACHABLE=$($unreachable.Count)")
$lines.Add('---UNREACHABLE_LIST_START---')
foreach ($u in $unreachable) {
  $rel = $u.Substring($root.Length + 1).Replace('\\','/')
  $lines.Add($rel)
}
$lines.Add('---UNREACHABLE_LIST_END---')

Set-Content -Path $outFile -Value $lines -Encoding UTF8
Write-Output "WROTE_REPORT=$outFile"
