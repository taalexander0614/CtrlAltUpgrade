<#
.SYNOPSIS
    Invoke-VerkadaApi is a helper function to make API requests to the Verkada API.
.DESCRIPTION
    This function is a helper function to make API requests to the Verkada API. It handles the authentication, rate limiting, and error handling for API requests.
.PARAMETER endpoint
    Required: The endpoint of the Verkada API to call.
.PARAMETER region
    Optional: The region of the Verkada API to use. Default is "api".
.PARAMETER method
    Optional: The HTTP method to use for the request. Default is "GET".
.PARAMETER apiKey
    Required: The API key to authenticate the request.
.PARAMETER query
    Optional: The query string to include in the request.
.PARAMETER body
    Optional: The body of the request.
.NOTES
    This function is useful for making calls to the Verkada API in PowerShell scripts.
    It handles rate limiting by waiting for the specified Retry-After time and then retrying the request.
    Author: Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
#>

function Invoke-VerkadaApi {
    param (
        [Parameter(Mandatory=$true)]    
        [string]$endpoint,
        [Parameter(Mandatory=$false)]
        [string]$region = "api",
        [Parameter(Mandatory=$false)]
        [string]$method = "GET",
        [Parameter(Mandatory=$false)]
        [string]$apiKey,
        [Parameter(Mandatory=$false)]
        [string]$query,
        [Parameter(Mandatory=$false)]
        [string]$body
    )

    $baseURI = "https://$region.verkada.com"
    $uri = "$baseURI/$endpoint"
    if ($query) {
        $uri += "?$query"
    }

    $headers=@{}
    $headers.Add("accept", "application/json")
    $headers.Add("x-api-key", $apiKey)
    $headers.Add("content-type", "application/json")

    try {
        if ($body) {
            $response = Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -Body $body 
        }
        else {
            $response = Invoke-WebRequest -Uri $uri -Method $method -Headers $headers
        }
    }
    catch {
        return "failed"
    }

    if ($response.StatusCode -eq 429) {
        # Handle rate limiting
        $retryAfter = $response.Headers["Retry-After"]
        Write-Host "Rate Limit Exceeded. Waiting for $retryAfter seconds..."
        Start-Sleep -Seconds $retryAfter
        # Retry the request
        if ($body) {
            $response = Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -Body $body
        }
        else {
            $response = Invoke-WebRequest -Uri $uri -Method $method -Headers $headers
        }
    }

    if ($response.StatusCode -eq 200) {
        return $response.Content | ConvertFrom-Json
    }
    else {
        return "failed"
    }
}