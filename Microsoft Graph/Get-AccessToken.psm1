<#
.SYNOPSIS
    Get an access token for Microsoft Graph API.
.DESCRIPTION
    This function gets an access token for Microsoft Graph API using the client credentials flow.
.PARAMETER tenantID
    Required: The tenant ID of the Azure AD tenant.
.PARAMETER appID
    Required: The application ID of the Azure AD application.
.PARAMETER appSecret
    Required: The application secret of the Azure AD application.
.NOTES
    This function is useful for obtaining access tokens for Microsoft Graph API in PowerShell scripts.
#>

function Get-AccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$tenantID,
        [Parameter(Mandatory = $true)]
        [string]$appID,
        [Parameter(Mandatory = $true)]
        [string]$appSecret
    )
    Write-Host "Obtaining Auth Token"
    $accessTokenUrl = "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token"
    $tokenRequestBody = @{
        "grant_type"    = "client_credentials"
        "scope"         = "https://graph.microsoft.com/.default"
        "client_id"     = $appID
        "client_secret" = $appSecret
    }   
    Try {
        $tokenResponse = Invoke-RestMethod -Uri $accessTokenUrl -Method POST -Body $tokenRequestBody
    }
    Catch {
        Write-Host "Failed to obtain Auth Token: $_"
    }
    Write-Host "Obtained Auth Token"
    return $tokenResponse
}