Write-Host "Checking architecture boundaries..."

$root = Join-Path $PSScriptRoot 'lib'
$violations = New-Object System.Collections.Generic.List[string]

function Test-ForbiddenImport {
    param(
        [string]$ImportLine,
        [string[]]$ForbiddenSegments
    )

    foreach ($segment in $ForbiddenSegments) {
        $relativePattern = [regex]::Escape("/$segment/")
        $packagePattern = [regex]::Escape("package:fantastic_guacamole/$segment/")

        if ($ImportLine -match $relativePattern -or $ImportLine -match $packagePattern) {
            return $true
        }
    }

    return $false
}

function Find-LayerViolations {
    param(
        [string]$Directory,
        [string]$Label,
        [string[]]$ForbiddenSegments
    )

    if (-not (Test-Path $Directory)) {
        return
    }

    Get-ChildItem -Path $Directory -Recurse -Filter *.dart | ForEach-Object {
        $file = $_.FullName
        $lines = @(Get-Content -Path $file)

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $rawLine = $lines[$index]

            if ($null -eq $rawLine) {
                continue
            }

            $line = [string]$rawLine
            $line = $line.Trim()

            if ($line -notmatch '^(import|export)\s+''') {
                continue
            }

            if (Test-ForbiddenImport -ImportLine $line -ForbiddenSegments $ForbiddenSegments) {
                $violations.Add(("[{0}] {1}:{2} -> {3}" -f $Label, $file, ($index + 1), $line))
            }
        }
    }
}

Find-LayerViolations -Directory (Join-Path $root 'features') -Label 'UI x' -ForbiddenSegments @('engine', 'data')
Find-LayerViolations -Directory (Join-Path $root 'state') -Label 'STATE x' -ForbiddenSegments @('features', 'ui')
Find-LayerViolations -Directory (Join-Path $root 'engine') -Label 'ENGINE x' -ForbiddenSegments @('state', 'features', 'ui')
Find-LayerViolations -Directory (Join-Path $root 'data') -Label 'DATA x' -ForbiddenSegments @('state', 'engine', 'features', 'ui')

if ($violations.Count -eq 0) {
    Write-Host 'No architecture violations found.'
    exit 0
}

Write-Host 'Violations found:'
$violations | Sort-Object | ForEach-Object { Write-Host $_ }
exit 1
