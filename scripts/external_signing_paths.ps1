function Get-ExternalSigningPaths {
    param(
        [string]$PropertiesPath,
        [string]$KeystorePath
    )

    if ([string]::IsNullOrWhiteSpace($PropertiesPath)) {
        $PropertiesPath = $env:CHRONOSPARK_SIGNING_PROPERTIES_PATH
    }
    if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
        $KeystorePath = $env:CHRONOSPARK_SIGNING_KEYSTORE_PATH
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $signingDirectory = Join-Path $env:LOCALAPPDATA 'ChronoSpark/signing'
        if ([string]::IsNullOrWhiteSpace($PropertiesPath)) {
            $PropertiesPath = Join-Path $signingDirectory 'key.properties'
        }
        if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
            $KeystorePath = Join-Path $signingDirectory 'upload-keystore.jks'
        }
    }

    return [pscustomobject]@{
        PropertiesPath = $PropertiesPath
        KeystorePath = $KeystorePath
    }
}
