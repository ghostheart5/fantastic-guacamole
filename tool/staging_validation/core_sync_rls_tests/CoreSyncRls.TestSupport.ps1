Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Net.Http
. "$PSScriptRoot/../StagingValidation.Common.ps1"

function New-CoreSyncRlsContext {
    param(
        [Parameter(Mandatory)][bool]$ConfirmStaging,
        [Parameter(Mandatory)][bool]$ApproveMutationTests
    )

    if (-not $ConfirmStaging -or -not $ApproveMutationTests) {
        throw 'Refusing to execute. Pass both -ConfirmStaging and -ApproveMutationTests only after all approval checklist items are checked.'
    }

    Import-StagingEnvironment -EnvironmentFile "$PSScriptRoot/../.env"

    $supabaseUrl = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_URL'
    $target = [uri]$supabaseUrl
    if ($target.Scheme -ne 'https' -or $target.Host -ne 'pxtjkwfedrtnxuihtdox.supabase.co' -or $target.AbsolutePath -notin @('', '/')) {
        throw 'Refusing to execute: the target must be the confirmed staging base URL.'
    }

    $anonKey = Get-RequiredStagingValue -Name 'STAGING_SUPABASE_ANON_KEY'
    $userAUuid = Get-RequiredStagingValue -Name 'STAGING_USER_A_UUID'
    $userBUuid = Get-RequiredStagingValue -Name 'STAGING_USER_B_UUID'
    Test-StagingUserUuidConfiguration -UserAUuid $userAUuid -UserBUuid $userBUuid

    $userA = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
        -Email (Get-RequiredStagingValue -Name 'STAGING_USER_A_EMAIL') `
        -Password (Get-RequiredStagingValue -Name 'STAGING_USER_A_PASSWORD') -Label 'staging_user_a'
    $userB = New-StagingSession -SupabaseUrl $supabaseUrl -AnonKey $anonKey `
        -Email (Get-RequiredStagingValue -Name 'STAGING_USER_B_EMAIL') `
        -Password (Get-RequiredStagingValue -Name 'STAGING_USER_B_PASSWORD') -Label 'staging_user_b'
    Assert-StagingSessionIdentity -Session $userA -ExpectedUserId $userAUuid
    Assert-StagingSessionIdentity -Session $userB -ExpectedUserId $userBUuid

    return [pscustomobject]@{
        SupabaseUrl = $supabaseUrl
        AnonKey = $anonKey
        UserA = $userA
        UserB = $userB
    }
}

function Invoke-StagingRestRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PATCH', 'DELETE')][string]$Method,
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)]$Session,
        [hashtable]$Filters = @{},
        [AllowNull()][hashtable]$Body,
        [string]$Prefer = 'return=representation'
    )

    $filterParts = @(foreach ($filter in $Filters.GetEnumerator()) {
        "$($filter.Key)=eq.$([uri]::EscapeDataString([string]$filter.Value))"
    })
    $query = if ($filterParts.Count -gt 0) { '?' + ($filterParts -join '&') } else { '' }
    $httpMethod = [System.Net.Http.HttpMethod]::new($Method)
    $request = [System.Net.Http.HttpRequestMessage]::new($httpMethod, "$($Context.SupabaseUrl)/rest/v1/$Table$query")
    $request.Headers.Add('apikey', $Context.AnonKey)
    $request.Headers.Add('Authorization', "Bearer $($Session.AccessToken)")
    $request.Headers.Add('Prefer', $Prefer)
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 8 -Compress
        $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
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

function Test-RestSuccess {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Response)

    if ($Response.StatusCode -lt 200 -or $Response.StatusCode -ge 300) {
        Write-ValidationFail -Name $Name -Detail "Expected success but received HTTP $($Response.StatusCode)."
        return $false
    }
    Write-ValidationPass -Name $Name
    return $true
}

function Test-RestDeniedOrEmpty {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Response)

    if ($Response.StatusCode -lt 200 -or $Response.StatusCode -ge 300) {
        Write-ValidationPass -Name $Name
        return
    }
    if ([string]::IsNullOrWhiteSpace($Response.Content) -or $Response.Content.Trim() -eq '[]') {
        Write-ValidationPass -Name $Name
        return
    }
    Write-ValidationFail -Name $Name -Detail "Expected denial or zero rows but received HTTP $($Response.StatusCode)."
}

function Remove-CoreSyncTestRow {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)]$Owner,
        [Parameter(Mandatory)][hashtable]$Filters,
        [Parameter(Mandatory)][string]$Name
    )

    $response = Invoke-StagingRestRequest -Method 'DELETE' -Context $Context -Table $Table -Session $Owner -Filters $Filters -Body $null
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        Write-ValidationFail -Name $Name -Detail "Cleanup failed with HTTP $($response.StatusCode)."
    }
}

function Invoke-CoreSyncRlsTableTests {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)][scriptblock]$PayloadFactory,
        [Parameter(Mandatory)][scriptblock]$LocatorFactory,
        [Parameter(Mandatory)][hashtable]$UpdatePayload,
        [switch]$RequiresEmptyOwnershipSlot
    )

    $marker = [guid]::NewGuid().ToString('N')
    $ownPayload = & $PayloadFactory $Context.UserA.UserId "$marker-own"
    $ownLocator = & $LocatorFactory $Context.UserA.UserId "$marker-own"

    if ($RequiresEmptyOwnershipSlot) {
        foreach ($session in @($Context.UserA, $Context.UserB)) {
            $existing = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table $Table -Session $session `
                -Filters (& $LocatorFactory $session.UserId "$marker-own") -Body $null
            if ($existing.StatusCode -ge 200 -and $existing.StatusCode -lt 300 -and $existing.Content.Trim() -ne '[]') {
                Write-ValidationSkip -Name "${Table} requires an empty ownership slot" -Detail 'A pre-existing row would be unsafe to overwrite or delete.'
                return
            }
        }
    }

    $insertOwn = Invoke-StagingRestRequest -Method 'POST' -Context $Context -Table $Table -Session $Context.UserA -Body $ownPayload
    if (Test-RestSuccess -Name "${Table}: User A inserts own row" -Response $insertOwn) {
        $readOwn = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table $Table -Session $Context.UserA -Filters $ownLocator -Body $null
        Test-RestSuccess -Name "${Table}: User A reads own row" -Response $readOwn | Out-Null

        $readByB = Invoke-StagingRestRequest -Method 'GET' -Context $Context -Table $Table -Session $Context.UserB -Filters $ownLocator -Body $null
        Test-RestDeniedOrEmpty -Name "${Table}: User B cannot read User A row" -Response $readByB

        $updateByB = Invoke-StagingRestRequest -Method 'PATCH' -Context $Context -Table $Table -Session $Context.UserB -Filters $ownLocator -Body $UpdatePayload
        Test-RestDeniedOrEmpty -Name "${Table}: User B cannot update User A row" -Response $updateByB

        $deleteByB = Invoke-StagingRestRequest -Method 'DELETE' -Context $Context -Table $Table -Session $Context.UserB -Filters $ownLocator -Body $null
        Test-RestDeniedOrEmpty -Name "${Table}: User B cannot delete User A row" -Response $deleteByB
    }
    Remove-CoreSyncTestRow -Context $Context -Table $Table -Owner $Context.UserA -Filters $ownLocator -Name "${Table}: cleanup User A row"

    $spoofBPayload = & $PayloadFactory $Context.UserB.UserId "$marker-a-spoofs-b"
    $spoofBLocator = & $LocatorFactory $Context.UserB.UserId "$marker-a-spoofs-b"
    $spoofByA = Invoke-StagingRestRequest -Method 'POST' -Context $Context -Table $Table -Session $Context.UserA -Body $spoofBPayload
    Test-RestDeniedOrEmpty -Name "${Table}: User A cannot spoof User B UUID" -Response $spoofByA
    Remove-CoreSyncTestRow -Context $Context -Table $Table -Owner $Context.UserB -Filters $spoofBLocator -Name "${Table}: cleanup A-to-B spoof row"

    $spoofAPayload = & $PayloadFactory $Context.UserA.UserId "$marker-b-spoofs-a"
    $spoofALocator = & $LocatorFactory $Context.UserA.UserId "$marker-b-spoofs-a"
    $spoofByB = Invoke-StagingRestRequest -Method 'POST' -Context $Context -Table $Table -Session $Context.UserB -Body $spoofAPayload
    Test-RestDeniedOrEmpty -Name "${Table}: User B cannot spoof User A UUID" -Response $spoofByB
    Remove-CoreSyncTestRow -Context $Context -Table $Table -Owner $Context.UserA -Filters $spoofALocator -Name "${Table}: cleanup B-to-A spoof row"
}
