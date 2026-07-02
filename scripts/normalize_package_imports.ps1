$packageName = 'fantastic_guacamole'
$libRoot = Join-Path $PSScriptRoot '..\lib'
$libRoot = (Resolve-Path $libRoot).Path

$dartFiles = Get-ChildItem -Path $libRoot -Recurse -Filter *.dart

foreach ($file in $dartFiles) {
    $fullPath = $file.FullName
    $directory = Split-Path -Parent $fullPath
    $lines = Get-Content -Path $fullPath
    $updatedLines = foreach ($line in $lines) {
        if ($line -notmatch "^(\s*(?:import|export)\s+')(?<rest>.+)$") {
            $line
            continue
        }

        $prefix = $matches[1]
        $rest = $matches['rest']
        $suffix = ';'

        if ($rest -match "^(?<path>[^']+)'(?<suffix>.*)$") {
            $pathValue = $matches['path']
            $suffix = $matches['suffix']
        }
        else {
            $pathValue = $rest.Trim()
        }

        if ($suffix.Trim().Length -eq 0) {
            $suffix = ';'
        }

        if ($pathValue.StartsWith('dart:')) {
            "$prefix$pathValue'$suffix"
            continue
        }

        if ($pathValue.StartsWith("package:$packageName/")) {
            if ($pathValue -match "^(package:$packageName/.+?\.dart)") {
                $normalizedPath = $matches[1]
            }
            else {
                $normalizedPath = $pathValue
            }
            "$prefix$normalizedPath'$suffix"
            continue
        }

        if ($pathValue.StartsWith('package:')) {
            "$prefix$pathValue'$suffix"
            continue
        }

        $relativePath = $pathValue -replace '/', [IO.Path]::DirectorySeparatorChar
        $resolvedPath = [IO.Path]::GetFullPath((Join-Path $directory $relativePath))

        if (-not $resolvedPath.StartsWith($libRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            "$prefix$pathValue'$suffix"
            continue
        }

        $packagePath =
        $resolvedPath.Substring($libRoot.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
        $normalizedPath = "package:$packageName/$packagePath"
        "$prefix$normalizedPath'$suffix"
    }

    $updated = ($updatedLines -join [Environment]::NewLine)
    if ($updated -ne ((Get-Content -Path $fullPath) -join [Environment]::NewLine)) {
        Set-Content -Path $fullPath -Value $updated -Encoding utf8
    }
}

Write-Host 'Package import normalization complete.'
