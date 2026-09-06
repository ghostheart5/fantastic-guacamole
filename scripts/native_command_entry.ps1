# Fixed entry point for run_maestro_android_evidence.ps1. Command data arrives
# only through stdin; it is never interpolated into PowerShell source.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$phase = 'payload-validation'

try {
    # Windows PowerShell can prefix redirected stdin with its host encoding's
    # BOM before the parent writes UTF-8 bytes. Detect it without treating it as
    # JSON content; Console.In does not consistently do this across host modes.
    $inputReader = [System.IO.StreamReader]::new(
        [Console]::OpenStandardInput(),
        [System.Text.UTF8Encoding]::new($false),
        $true
    )
    try {
        $payloadJson = $inputReader.ReadToEnd()
    }
    finally {
        $inputReader.Dispose()
    }
    $phase = 'payload-json-parsing'
    $payload = $payloadJson | ConvertFrom-Json
    $phase = 'payload-type-validation'
    if ($null -eq $payload -or
        $payload.executable -isnot [string] -or
        [string]::IsNullOrWhiteSpace($payload.executable) -or
        $payload.arguments -isnot [System.Array] -or
        -not (Test-Path -LiteralPath $payload.executable -PathType Leaf)) {
        throw 'Invalid native command payload.'
    }
    foreach ($argument in $payload.arguments) {
        if ($argument -isnot [string]) {
            throw 'Native command arguments must be strings.'
        }
    }

    $target = $payload.executable
    $targetArguments = @($payload.arguments)
    $LASTEXITCODE = $null
    $phase = 'target-invocation'
    & $target @targetArguments
    $commandSucceeded = $?
    if ($null -ne $LASTEXITCODE) {
        exit $LASTEXITCODE
    }
    if (-not $commandSucceeded) {
        exit 1
    }
    exit 0
}
catch {
    # Never repeat the structured payload or command arguments in diagnostics.
    $exceptionType = $_.Exception.GetType().Name
    $category = [string]$_.CategoryInfo.Category
    [Console]::Error.WriteLine("Native command entry failed ($phase; $exceptionType; $category).")
    exit 1
}
