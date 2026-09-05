function Get-RepositoryScanFiles {
  param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

  # NUL delimiters preserve Unicode, brackets, whitespace and Git-quoted names.
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = (Get-Command git -ErrorAction Stop).Source
  $startInfo.Arguments = 'ls-files -z --cached --others --exclude-standard'
  $startInfo.WorkingDirectory = $RepositoryRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { throw 'git repository file discovery failed.' }
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $output = $outputTask.GetAwaiter().GetResult()
    $null = $errorTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw 'git repository file discovery failed.' }
    $output.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries)
  } finally {
    $process.Dispose()
  }
}
