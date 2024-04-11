<#
.SYNOPSIS
    Get user details of all users in a specified Verkada group.
.DESCRIPTION
    This function gets user details of all users in a specified Verkada group. The function first gets the user IDs of all users in the group and then gets the user details for each user.
.PARAMETER key
    Required: The API key to authenticate the request.
.PARAMETER id
    Required: The group ID of the Verkada group.
.NOTES
    This function is useful for getting user details of all users in a Verkada group in PowerShell scripts.
    It uses the Invoke-VerkadaApi function to make API requests to the Verkada API.
    Author: Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
.EXAMPLE
    # This example gets user details of all users in a Verkada group.
    $users = Invoke-GetVerkadaGroupUsers -key $apiKey -id $groupID
#>

function Invoke-GetVerkadaGroupUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$key,
        [Parameter(Mandatory = $true)]
        [string]$id
    )

    try {
        $response = Invoke-VerkadaApi -endpoint "access/v1/access_groups/group" -apiKey $key -query "group_id=$id"
    }
    catch {
        Write-Host "Failed to get group users: $_"
        Write-Host "URI: $uri"
        Write-Host "Response: $response"
    }

    # Use Invoke-GetVerkadaUser to get user details for each user in the group
    $users = @()
    foreach ($user in $response.user_ids) {
        $verkadaUser = Invoke-VerkadaApi -endpoint "core/v1/user" -query "user_id=$user" -apiKey $key
        $verkadaAccessUser = Invoke-VerkadaApi -endpoint "access/v1/access_users/user" -apiKey $key -query "user_id=$user"
        Add-Member -InputObject $verkadaUser -MemberType NoteProperty -Name "access_user_details" -Value $verkadaAccessUser
        if ($verkadaUser) {
            $users += $verkadaUser
        }
    }

    return $users
}