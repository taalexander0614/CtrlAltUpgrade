<#
.SYNOPSIS
    Add or remove users from groups in Verkada Command
.DESCRIPTION
    This function adds or removes users from groups in Verkada Command. It can be used to manage access to Verkada cameras and other devices.
.PARAMETER key
    Required: The API key to authenticate the request.
.PARAMETER groupId
    Required: The group ID of the Verkada group.
.PARAMETER userId
    Required: The user ID of the Verkada user.
.PARAMETER remove
    Optional: A switch parameter to remove the user from the group. Default is $false.
.NOTES
    This function is useful for adding or removing users from groups in Verkada Command in PowerShell scripts.
    It uses the Invoke-VerkadaApi function to make API requests to the Verkada API.
    Author: Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
.EXAMPLE
    # This example adds a user to a Verkada group.
    Invoke-VerkadaGroupUser -key $apiKey -groupId $groupID -userId $userID

    # This example removes a user from a Verkada group.
    Invoke-VerkadaGroupUser -key $apiKey -groupId $groupID -userId $userID -remove
#>

function Invoke-VerkadaGroupUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$key,
        [Parameter(Mandatory = $true)]
        [string]$groupId,
        [Parameter(Mandatory = $true)]
        [string]$userId,
        [Parameter(Mandatory = $false)]
        [bool]$remove = $false
    )

    $response = $null

    if ($remove) {
        try {
            $response = Invoke-VerkadaApi -endpoint "access/v1/access_groups/group/user" -apiKey $key -query "group_id=$groupId&external_id=$userId" -method "DELETE"
        }
        catch {
            Write-Host "Failed to remove user from group: $_"
        }
    }
    else {
        $body = @{
            "external_id" = $userId
        } | ConvertTo-Json
    
        try {
            $response = Invoke-VerkadaApi -endpoint "access/v1/access_groups/group/user" -apiKey $key -query "group_id=$groupId" -method "PUT" -body $body
        }
        catch {
            Write-Host "Failed to add user to group: $_"
        }
    }

    return $response
}