Set-StrictMode -Version Latest

$script:ValidationFailures = 0
$script:ValidationSkips = 0
$script:ValidationPasses = 0

function Import-StagingEnvironment {
    param([Parameter(Mandatory)][string]$EnvironmentFile)

    if (-not (Test-Path -LiteralPath $EnvironmentFile -PathType Leaf)) {
        return
    }

    $allowedNames = @(
        'STAGING_SUPABASE_URL',
        'STAGING_SUPABASE_ANON_KEY',
        'STAGING_USER_A_EMAIL',
        'STAGING_USER_A_PASSWORD',
        'STAGING_USER_B_EMAIL',
        'STAGING_USER_B_PASSWORD',
        'STAGING_USER_A_UUID',
        'STAGING_USER_B_UUID'
    )
    foreach ($line in Get-Content -LiteralPath $EnvironmentFile) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        $pair = $trimmed -split '=', 2
        if ($pair.Count -ne 2 -or $pair[0] -notin $allowedNames) {
            throw "Invalid variable in staging environment file: $EnvironmentFile"
        }
        [Environment]::SetEnvironmentVariable($pair[0], $pair[1], 'Process')
    }
}

function Write-ValidationPass {
    param([Parameter(Mandatory)][string]$Name)
    $script:ValidationPasses++
    Write-Host "PASS  $Name" -ForegroundColor Green
}

function Write-ValidationFail {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Detail)
    $script:ValidationFailures++
    Write-Host "FAIL  $Name - $Detail" -ForegroundColor Red
}

function Write-ValidationSkip {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Detail)
    $script:ValidationSkips++
    Write-Host "SKIP  $Name - $Detail" -ForegroundColor Yellow
}

function Get-RequiredStagingValue {
    param([Parameter(Mandatory)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable: $Name"
    }
    return $value
}

function Test-StagingUserUuidConfiguration {
    param(
        [Parameter(Mandatory)][string]$UserAUuid,
        [Parameter(Mandatory)][string]$UserBUuid
    )

    $uuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    if ($UserAUuid -notmatch $uuidPattern) {
        throw 'STAGING_USER_A_UUID is not a valid UUID.'
    }
    if ($UserBUuid -notmatch $uuidPattern) {
        throw 'STAGING_USER_B_UUID is not a valid UUID.'
    }
    if ($UserAUuid -eq $UserBUuid) {
        throw 'STAGING_USER_A_UUID and STAGING_USER_B_UUID must be different.'
    }
}

function Assert-StagingSessionIdentity {
    param(
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)][string]$ExpectedUserId
    )

    if ($Session.UserId -ne $ExpectedUserId) {
        throw "Authenticated $($Session.Label) does not match its configured staging UUID."
    }
}

function New-StagingSession {
    param(
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey,
        [Parameter(Mandatory)][string]$Email,
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Label
    )

    $response = Invoke-SupabaseRequest -Method 'POST' -Url "$SupabaseUrl/auth/v1/token?grant_type=password" `
        -AnonKey $AnonKey -AccessToken $null -Body @{ email = $Email; password = $Password }
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        throw "Unable to authenticate $Label. HTTP $($response.StatusCode): $($response.Content)"
    }

    $session = $response.Content | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($session.access_token) -or [string]::IsNullOrWhiteSpace($session.user.id)) {
        throw "Authentication response for $Label did not contain an access token and user ID."
    }

    return [pscustomobject]@{
        Label = $Label
        AccessToken = [string]$session.access_token
        UserId = [string]$session.user.id
    }
}

function Invoke-SupabaseRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('POST')][string]$Method,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$AnonKey,
        [AllowNull()][string]$AccessToken,
        [hashtable]$Body = @{}
    )

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$Method, $Url)
    $request.Headers.Add('apikey', $AnonKey)
    if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
        $request.Headers.Add('Authorization', "Bearer $AccessToken")
    }
    $json = $Body | ConvertTo-Json -Depth 8 -Compress
    $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')

    $client = [System.Net.Http.HttpClient]::new()
    try {
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Content = $content
        }
    }
    finally {
        $request.Dispose()
        $client.Dispose()
    }
}

function Invoke-StagingRpc {
    param(
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey,
        [Parameter(Mandatory)][string]$RpcName,
        [AllowNull()][string]$AccessToken,
        [hashtable]$Arguments = @{}
    )

    return Invoke-SupabaseRequest -Method 'POST' -Url "$SupabaseUrl/rest/v1/rpc/$RpcName" `
        -AnonKey $AnonKey -AccessToken $AccessToken -Body $Arguments
}

function Assert-RpcFailure {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Response)

    if ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 300) {
        Write-ValidationFail -Name $Name -Detail "Expected denial but received HTTP $($Response.StatusCode): $($Response.Content)"
        return
    }
    Write-ValidationPass -Name $Name
}

function Assert-RpcSuccess {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Response)

    if ($Response.StatusCode -lt 200 -or $Response.StatusCode -ge 300) {
        Write-ValidationFail -Name $Name -Detail "Expected success but received HTTP $($Response.StatusCode): $($Response.Content)"
        return $false
    }
    Write-ValidationPass -Name $Name
    return $true
}

function ConvertFrom-RpcJson {
    param([Parameter(Mandatory)]$Response)

    try {
        return $Response.Content | ConvertFrom-Json
    }
    catch {
        Write-ValidationFail -Name 'RPC JSON response parsing' -Detail $_.Exception.Message
        return $null
    }
}