<#
.SYNOPSIS
    Invoke a Microsoft Graph API call.
.DESCRIPTION
    This function invokes a Microsoft Graph API call using the provided access token, endpoint, and optional parameters.
.PARAMETER accessToken
    Required: The access token to authenticate the request.
.PARAMETER version
    Optional: The version of the Microsoft Graph API to use. Default is "v1.0".
.PARAMETER endpoint
    Required: The endpoint of the Microsoft Graph API to call.
.PARAMETER method
    Optional: The HTTP method to use for the request. Default is "GET".
.PARAMETER body
    Optional: The body of the request.
.PARAMETER consistencyLevel
    Optional: The consistency level for the request.
.PARAMETER headers
    Optional: Additional headers to include in the request.
.PARAMETER select
    Optional: The $select query parameter for the request.
.PARAMETER filter
    Optional: The $filter query parameter for the request.
.PARAMETER search
    Optional: The $search query parameter for the request.
.NOTES
    This function is useful for making calls to the Microsoft Graph API in PowerShell scripts.
    It uses a do-while loop to handle pagination when the response contains a nextLink.
    Author: Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
.EXAMPLE
    # This example gets all users from the Microsoft Graph API.
    # Get-AccessToken is an internal function we use to get access tokens.
    $authToken = Get-AccessToken -tenantID $tenantID -appID $appID -appSecret $appSecret
    $accessToken = $authToken.access_token
    $users = Invoke-MsGraphCall -accessToken $accessToken -endpoint "users"
#>

function Invoke-MsGraphCall {
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$accessToken,
        [Parameter(Mandatory=$false)]
        [string]$version = "v1.0",
        [Parameter(Mandatory=$True)]
        [string]$endpoint,
        [Parameter(Mandatory=$False)]
        [string]$method = "GET",
        [Parameter(Mandatory=$False)]
        [string]$body,
        [Parameter(Mandatory=$False)]
        [string]$consistencyLevel,
        [Parameter(Mandatory=$False)]
        [hashtable]$headers = @{},
        [Parameter(Mandatory=$False)]
        [string]$select,
        [Parameter(Mandatory=$False)]
        [string]$filter,
        [Parameter(Mandatory=$False)]
        [string]$search
    )

    # Make uri
    $uri = "https://graph.microsoft.com/$version/$endpoint"
    # Add default headers
    $headers["Content-Type"] = "application/json"
    $headers["Authorization"] = "Bearer $($accessToken)"
    if ($consistencyLevel) {
        $headers["ConsistencyLevel"] = $consistencyLevel
    }

    # Add optional parameters to URI
    if ($select) {
        $uri += "?`$select=$select"
    }

    if ($filter) {
        $uri += "&`$filter=$filter"
    }

    if ($search) {
        $uri += "?`$search=$search"
    }

    $results = @()

    do {
        # Create Splat hashtable
        $graphSplatParams = @{
            Headers     = $headers
            Method      = $method
            URI         = $uri
            ErrorAction = "SilentlyContinue"
        }

        # If method requires body, add body to splat
        if ($Method -in ('PUT', 'PATCH', 'POST')) {
            $graphSplatParams["Body"] = $body
        }

        try {
            $MSGraphResult = Invoke-WebRequest @graphSplatParams | ConvertFrom-Json
            $results += $MSGraphResult
            $uri = $MSGraphResult.'@odata.nextLink'
        } catch {
            Write-Host "Error in API call: $_"
            Write-Host "Response StatusCode: $($_.Exception.Response.StatusCode)"
            Write-Host "Response Content: $($_.Exception.Response.Content)"
            break  # Exit the loop on error
        }
    } while ($uri)

    return $results
}