$ErrorActionPreference = 'Stop'
$lines = Get-Content 'tmp_unused_report.txt'
$start = ($lines | Select-String '---UNREACHABLE_LIST_START---').LineNumber
$end = ($lines | Select-String '---UNREACHABLE_LIST_END---').LineNumber
$items = $lines[($start)..($end-2)] | Where-Object { $_ -like 'lib*' }
$normalized = $items | ForEach-Object { $_ -replace '\\','/' }
$groups = $normalized | Group-Object { ($_ -split '/')[1] } | Sort-Object Count -Descending
foreach ($g in $groups) {
  Write-Output ("{0}:{1}" -f $g.Name, $g.Count)
}
