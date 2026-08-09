[CmdletBinding()]
param(
    [switch]$ConfirmStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedHost = 'pxtjkwfedrtnxuihtdox.supabase.co'
$bucket = 'chronospark-sync'
$expectedUserAUuid = 'a6dc2118-2140-4416-8642-9c3eba691288'
$expectedUserBUuid = 'aa116396-4dc1-461e-8502-61b6896570b4'

function Assert-ValidationPath {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$OwnerUuid)

    if ($Path -match '(?i)(^|/)backup(/|$)' -or
        $Path -notmatch "^$([regex]::Escape($OwnerUuid))/validation/[^/]+/[^/]+\.json$") {
        throw "Refusing unsafe Storage path: $Path"
    }
}

function Invoke-StorageRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('POST', 'GET', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey,
        [AllowNull()][string]$AccessToken,
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()][byte[]]$Content
    )

    Add-Type -AssemblyName System.Net.Http
    $encodedPath = ($Path -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::$Method,
        "$SupabaseUrl/storage/v1/object/$bucket/$encodedPath"
    )
    $request.Headers.Add('apikey', $AnonKey)
    if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
        $request.Headers.Add('Authorization', "Bearer $AccessToken")
    }
    if ($Method -eq 'POST') {
        $request.Headers.Add('x-upsert', 'false')
        $request.Content = [System.Net.Http.ByteArrayContent]::new($Content)
        $request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json')
    }
    $client = [System.Net.Http.HttpClient]::new()
    try {
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    finally {
        $request.Dispose()
        $client.Dispose()
    }
}

function Test-ExpectedStatus {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Response,
        [Parameter(Mandatory)][bool]$ShouldSucceed
    )

    $succeeded = $Response.StatusCode -ge 200 -and $Response.StatusCode -lt 300
    if ($succeeded -eq $ShouldSucceed) {
        $script:ValidationPasses++
        Write-Host "PASS  $Name" -ForegroundColor Green
    }
    else {
        $script:ValidationFailures++
        Write-Host "FAIL  $Name - HTTP $($Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host 'This script only targets staging and only generated validation objects.' -ForegroundColor Yellow
if (-not $ConfirmStaging) {
    throw 'Refusing to run. Pass -ConfirmStaging only after STORAGE_VALIDATION_APPROVAL.md is completed.'
}

. "$PSScriptRoot/core_sync_rls_tests/CoreSyncRls.TestSupport.ps1"
Import-StagingEnvironment -EnvironmentFile "$PSScriptRoot/.env"
$supabaseUrl = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_URL'
if ($supabaseUrl -notmatch 'pxtjkwfedrtnxuihtdox' -or $supabaseUrl -match '(?i)/rest/v1/?$') {
    throw 'Refusing to run: STAGING_SUPABASE_URL must be the confirmed staging base URL, not a REST endpoint.'
}
$target = [uri]$supabaseUrl
if ($target.Scheme -ne 'https' -or $target.Host -ne $expectedHost -or $target.AbsolutePath -notin @('', '/')) {
    throw 'Refusing to run: target is not the confirmed staging base URL.'
}

$anonKey = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_ANON_KEY'
$userAUuid = Get-RequiredStagingValue -Name 'STAGING_USER_A_UUID'
$userBUuid = Get-RequiredStagingValue -Name 'STAGING_USER_B_UUID'
Test-StagingUserUuidConfiguration -UserAUuid $userAUuid -UserBUuid $userBUuid
if ((@($userAUuid, $userBUuid) | Sort-Object) -join ',' -ne ((@($expectedUserAUuid, $expectedUserBUuid) | Sort-Object) -join ',')) {
    throw 'Refusing to run: configured staging user UUIDs do not match the approved Storage validation user pair.'
}
$userA = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
    -Email (Get-RequiredStagingValue -Name 'STAGING_USER_A_EMAIL') `
    -Password (Get-RequiredStagingValue -Name 'STAGING_USER_A_PASSWORD') -Label 'staging_user_a'
$userB = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
    -Email (Get-RequiredStagingValue -Name 'STAGING_USER_B_EMAIL') `
    -Password (Get-RequiredStagingValue -Name 'STAGING_USER_B_PASSWORD') -Label 'staging_user_b'
Assert-StagingSessionIdentity -Session $userA -ExpectedUserId $userAUuid
Assert-StagingSessionIdentity -Session $userB -ExpectedUserId $userBUuid

$script:ValidationPasses = 0
$script:ValidationFailures = 0
$script:ValidationSkips = 0
$runId = "storage-policy-$([guid]::NewGuid().ToString('N'))"
$pathA = "$userAUuid/validation/$runId/owned.json"
$pathB = "$userBUuid/validation/$runId/owned.json"
Assert-ValidationPath -Path $pathA -OwnerUuid $userAUuid
Assert-ValidationPath -Path $pathB -OwnerUuid $userBUuid
$bytesA = [System.Text.Encoding]::UTF8.GetBytes("{`"owner`":`"A`",`"runId`":`"$runId`"}")
$bytesB = [System.Text.Encoding]::UTF8.GetBytes("{`"owner`":`"B`",`"runId`":`"$runId`"}")

Write-Host "Target STAGING_SUPABASE_URL: $supabaseUrl" -ForegroundColor Cyan
try {
    Test-ExpectedStatus -Name 'User A uploads User A validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathA -Content $bytesA)
    Test-ExpectedStatus -Name 'User B uploads User B validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathB -Content $bytesB)
    Test-ExpectedStatus -Name 'User A cannot upload User B path' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathB -Content $bytesA)
    Test-ExpectedStatus -Name 'User B cannot upload User A path' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathA -Content $bytesB)
    Test-ExpectedStatus -Name 'Anonymous upload denied' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $null -Path $pathA -Content $bytesA)
    Test-ExpectedStatus -Name 'User A reads User A validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method GET -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathA -Content $null)
    Test-ExpectedStatus -Name 'User B reads User B validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method GET -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathB -Content $null)
    Test-ExpectedStatus -Name 'User A cannot read User B validation object' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method GET -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathB -Content $null)
    Test-ExpectedStatus -Name 'User B cannot read User A validation object' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method GET -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathA -Content $null)
    Test-ExpectedStatus -Name 'Anonymous read denied' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method GET -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $null -Path $pathA -Content $null)
    Test-ExpectedStatus -Name 'User A deletes User A validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method DELETE -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathA -Content $null)
    Test-ExpectedStatus -Name 'User B deletes User B validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method DELETE -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathB -Content $null)
    Test-ExpectedStatus -Name 'User A recreates own validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathA -Content $bytesA)
    Test-ExpectedStatus -Name 'User B recreates own validation object' -ShouldSucceed $true -Response (Invoke-StorageRequest -Method POST -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathB -Content $bytesB)
    Test-ExpectedStatus -Name 'User A cannot delete User B validation object' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method DELETE -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userA.AccessToken -Path $pathB -Content $null)
    Test-ExpectedStatus -Name 'User B cannot delete User A validation object' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method DELETE -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $userB.AccessToken -Path $pathA -Content $null)
    Test-ExpectedStatus -Name 'Anonymous delete denied' -ShouldSucceed $false -Response (Invoke-StorageRequest -Method DELETE -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $null -Path $pathA -Content $null)
}
finally {
    foreach ($cleanup in @(
        [pscustomobject]@{ Session = $userA; Path = $pathA },
        [pscustomobject]@{ Session = $userB; Path = $pathB }
    )) {
        try {
            $response = Invoke-StorageRequest -Method DELETE -SupabaseUrl $supabaseUrl -AnonKey $anonKey -AccessToken $cleanup.Session.AccessToken -Path $cleanup.Path -Content $null
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
                $script:ValidationPasses++
                Write-Host "PASS  Cleanup $($cleanup.Session.Label) validation object" -ForegroundColor Green
            }
            else {
                $script:ValidationFailures++
                Write-Host "FAIL  Cleanup $($cleanup.Session.Label) validation object - HTTP $($response.StatusCode)" -ForegroundColor Red
            }
        }
        catch {
            $script:ValidationFailures++
            Write-Host "FAIL  Cleanup $($cleanup.Session.Label) validation object - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "Summary: PASS $script:ValidationPasses | FAIL $script:ValidationFailures | SKIP $script:ValidationSkips" -ForegroundColor Cyan
if ($script:ValidationFailures -gt 0) { exit 1 }
