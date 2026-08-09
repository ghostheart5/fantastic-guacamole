function Invoke-ProfileRepairTests {
    param(
        [Parameter(Mandatory)]$UserA,
        [Parameter(Mandatory)]$UserB,
        [Parameter(Mandatory)][string]$SupabaseUrl,
        [Parameter(Mandatory)][string]$AnonKey
    )

    $firstA = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'ensure_profile_for_current_user' -AccessToken $UserA.AccessToken
    if (Assert-RpcSuccess -Name 'User A profile repair succeeds' -Response $firstA) {
        $profileA = ConvertFrom-RpcJson -Response $firstA
        if ($null -eq $profileA -or $profileA.id -ne $UserA.UserId) {
            Write-ValidationFail -Name 'User A profile repair returns User A profile' -Detail 'Returned profile ID did not match User A.'
        }
        else {
            Write-ValidationPass -Name 'User A profile repair returns User A profile'
        }
    }

    $secondA = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'ensure_profile_for_current_user' -AccessToken $UserA.AccessToken
    if (Assert-RpcSuccess -Name 'User A profile repair is idempotent' -Response $secondA) {
        $profileAAgain = ConvertFrom-RpcJson -Response $secondA
        if ($null -eq $profileAAgain -or $profileAAgain.id -ne $UserA.UserId) {
            Write-ValidationFail -Name 'User A idempotent repair preserves ownership' -Detail 'Returned profile ID did not match User A.'
        }
        else {
            Write-ValidationPass -Name 'User A idempotent repair preserves ownership'
        }
    }

    $profileBResponse = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'ensure_profile_for_current_user' -AccessToken $UserB.AccessToken
    if (Assert-RpcSuccess -Name 'User B profile repair succeeds' -Response $profileBResponse) {
        $profileB = ConvertFrom-RpcJson -Response $profileBResponse
        if ($null -eq $profileB -or $profileB.id -ne $UserB.UserId -or $profileB.id -eq $UserA.UserId) {
            Write-ValidationFail -Name 'User B cannot affect User A profile' -Detail 'Returned profile did not belong exclusively to User B.'
        }
        else {
            Write-ValidationPass -Name 'User B cannot affect User A profile'
        }
    }

    $anonymous = Invoke-StagingRpc -SupabaseUrl $SupabaseUrl -AnonKey $AnonKey `
        -RpcName 'ensure_profile_for_current_user' -AccessToken $null
    Assert-RpcFailure -Name 'Profile repair rejects anonymous caller' -Response $anonymous
}