<#
.SYNOPSIS
    Invoke-DeltaCheck is a function that checks for changes in a Microsoft Graph endpoint using delta queries.
.DESCRIPTION
    This function checks for changes in a Microsoft Graph endpoint using delta queries. It can be used to monitor changes in resources such as users, groups, or messages.
.PARAMETER accessToken
    Required: The access token to authenticate the request.
.PARAMETER deltaLink
    Optional: The delta link to continue checking for changes from a previous query.
.PARAMETER endpoint
    Optional: The endpoint of the Microsoft Graph API to check for changes.
.PARAMETER version
    Optional: The version of the Microsoft Graph API to use. Default is "v1.0".
.PARAMETER select
    Optional: The $select query parameter for the request.
.NOTES
    This function is useful for monitoring changes in Microsoft Graph resources and can be used in PowerShell scripts to automate tasks based on changes in the environment.
    It uses a do-while loop to handle pagination when the response contains a nextLink and will return the delta link when present to allow for future checks.
    Author: Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
#>

function Invoke-DeltaCheck {
    param (
        [string]$accessToken,
        [Parameter(Mandatory = $false)]
        [string]$deltaLink,
        [Parameter(Mandatory = $false)]
        [string]$endpoint,
        [Parameter(Mandatory = $false)]
        [string]$version = "v1.0",
        [Parameter(Mandatory = $false)]
        [string]$select
    )

    if (!$deltaLink) {
        $graphUri = "https://graph.microsoft.com"
        $uri = "$graphUri/$version/$endpoint/delta?"
        if ($select) {
            $uri += "`$select=$select"
        }
        Write-Host "No Delta Link provided."
    }
    else {
        Write-Host "Delta Link provided"
        $uri = $deltaLink
    }
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $accessToken"
        "ConsistencyLevel" = "eventual"
    }
    $graphResponse = @()
    $pageCount = 0

    while ($uri) {
        try {
            #Write-Host "URI: $uri"
            $pageCount++
            Write-Progress -Activity "Checking for changes in $endpoint" -Status "Page $pageCount" -PercentComplete 0
            $MSGraphResult = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            $graphResponse += $MSGraphResult.value

            # Check if there are more changes to sync
            if ($MSGraphResult.'@odata.nextLink') {
                $uri = $MSGraphResult.'@odata.nextLink'
                #Write-Host "More changes detected. Next Link: $uri"
            } 
            elseif ($MSGraphResult.'@odata.deltaLink') {
                $deltaLink = $MSGraphResult.'@odata.deltaLink'
                #Write-Host "No more changes detected. Delta Link: $deltaLink"
                $uri = $null
            }
            else {
                Write-Host "Not sure what happened. MSGraphResult: $MSGraphResult"
                Write-Host "$($MSGraphResult | ConvertTo-Json -Depth 10)"
                $deltaLink = $null
                $uri = $null
            }
        } catch {
            Write-Host "Error in API call: $_"
            Write-Host "URI: $uri"
            Write-Host "Headers:"
            $headers.GetEnumerator() | ForEach-Object {
                if ($_.Key -ne "Authorization"){
                    Write-Host "$($_.Key): $($_.Value)"
                }
            }
            Write-Host "Response StatusCode: $($_.Exception.Response.StatusCode)"
            Write-Progress -Activity "Checking for changes in $endpoint" -Completed
            break
        }
    }
    Write-Progress -Activity "Checking for changes in $endpoint" -Completed

    return $graphResponse, $deltaLink
}