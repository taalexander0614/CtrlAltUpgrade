<#
.SYNOPSIS
This script deletes stale devices using the Microsoft Graph API.

.DESCRIPTION
The script uses the Microsoft Graph API to connect to a Microsoft 365 tenant, retrieve a list of managed devices, and remove them if stale.
The script is set up to authenticate using app credentials and make API calls to endpoints in the Microsoft Graph API.

It uses the following global variables:
- $Global:org - The name of the organization.
- $Global:scriptName - The name of the script.
- $tenantID - The tenant ID.
- $appID - The application ID.
- $secret - The secret key.
- $betaGraphVersion - The Graph API version.
- $baseGraphURL - The Graph API URL.
- $managedDevices - The endpoint for managed devices.
- $betaManagedDevicesUrl - The full URL for the managed devices endpoint.

The script contains two functions:
- Write-Log - Logs messages to a log file.
- Get-AccessToken - Obtains an access token for the Microsoft Graph API.

The script then starts a log, obtains an access token, retrieves a list of devices, creates a group of devices with duplicate serial numbers and deletes all but the newest.
It uses the device's last sync time, so that if there are three devices with same same serial number, the two that synced on the older dates are deleted.

.OUTPUTS
The script creates a log file in the specified organization folder and logs the device ID for each duplicated device and again if it deletes the device.

.EXAMPLE
.\Intune Device Cleanup.ps1

.NOTES
I created this to use app permissions so I could set it as a scheduled task.
Make sure to update the tenant ID, app ID, and secret key with your actual values.
The app you use will need these permissions: 
--DeviceManagementConfiguration.ReadWrite.All: Required to read and write device management configurations.
--DeviceManagementManagedDevices.ReadWrite.All: Required to read and write managed devices.
--DeviceManagementManagedDevices.PrivilegedOperations.All: Required to perform privileged operations on managed devices.
--DeviceManagementServiceConfig.ReadWrite.All: Required to read and write service configurations.
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Intune Device Cleanup"

# Variables needed for Graph API interaction
$tenantID = ""
$appID = ""
$secret = ""
$graphURL = "https://graph.microsoft.com"
$graphVersion = "beta"
$baseGraphURL = "$graphURL/$graphVersion"
$managedDevices = "deviceManagement/managedDevices"
$betaManagedDevicesUrl = "$baseGraphURL/$managedDevices"

Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    # Determine whether the script is running in user or system context
    $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($userName -eq "NT AUTHORITY\SYSTEM") {
        $orgFolder = "$env:ProgramData\$org"
    }
    else {
        $orgFolder = "$Home\AppData\Roaming\$org"
    }

    $logFolder = "$orgFolder\Logs"
    $logFile = "$logFolder\$scriptName.log"
    # Create organization folder and log if they don't exist
    try {
        if (!(Test-Path $orgFolder)) {
            New-Item $orgFolder -ItemType Directory -Force | Out-Null
        }
        if (!(Test-Path $logFolder)) {
            New-Item $logFolder -ItemType Directory -Force | Out-Null
        }
        if (!(Test-Path $logFile)) {
            New-Item $logFile -ItemType File -Force | Out-Null
        }
    }
    catch {
        Write-Output "Failed to create log directory or file: $_"
    }
    # Set log date stamp
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    $streamWriter = New-Object System.IO.StreamWriter($logFile, $true)
    $streamWriter.WriteLine($LogEntry)
    $streamWriter.Close()
}

# Function to get the access token using app credentials
function Get-AccessToken {
    Write-Log -Level "INFO" -Message "Obtaining Auth Token"
    $accessTokenUrl = "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token"
    $tokenRequestBody = @{
        "grant_type"    = "client_credentials"
        "scope"         = "https://graph.microsoft.com/.default"
        "client_id"     = $appID
        "client_secret" = $secret
    }   
    Try {
        $tokenResponse = Invoke-RestMethod -Uri $accessTokenUrl -Method POST -Body $tokenRequestBody
    }
    Catch {
        Write-Log -Level "INFO" -Message "Failed to obtain Auth Token: $_"
    }
    Write-Log -Level "INFO" -Message "Obtained Auth Token"
    return $tokenResponse.access_token
}

# Start Log
Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# Get the auth token
$accessToken = Get-AccessToken -TenantId $tenantID -AppId $appID -ClientSecret $secret

# Construct the authorization header
$authHeaders = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

Write-Log -Level "INFO" -Message "Retreiving list of devices"
# Array to store all Windows devices
$devices = @()
Try {
    $pageCount = 0
    $managedDevicesResponse = (Invoke-RestMethod -Uri $betaManagedDevicesUrl -Headers $authHeaders -Method Get) 
    $devices = $managedDevicesResponse.value
    $pageCount++
    Write-Log -Level "INFO" -Message "Retrieved page $pageCount of devices"
    $devicesNextLink = $managedDevicesResponse."@odata.nextLink"
    
    while ($null -ne $devicesNextLink) {  
        $managedDevicesResponse = (Invoke-RestMethod -Uri $devicesNextLink -Headers $authHeaders -Method Get)
           $devicesNextLink = $managedDevicesResponse."@odata.nextLink"
        $devices += $managedDevicesResponse.value
        $pageCount++
        Write-Log -Level "INFO" -Message "Retrieved page $pageCount of devices"
    }
    Write-Log -Level "INFO" -Message "Retrieved all pages"
}
Catch {
    Write-Log -Level "ERROR" -Message "Failed to retrieve devices: $_"
}
Write-Log -Level "INFO" -Message "Found $($devices.Count) devices."
# Iterate over each managed device and remove stale devices
Write-Log -Level "INFO" -Message "Looping through devices to remove stale devices"
$deviceGroups = $devices | Where-Object { -not [String]::IsNullOrWhiteSpace($_.serialNumber) } | Group-Object -Property serialNumber
$duplicatedDevices = $deviceGroups | Where-Object {$_.Count -gt 1 }
Write-Log -Level "INFO" -Message "Found $($duplicatedDevices.Count) serialNumbers with duplicated entries"

$baseDeviceURL = "$betaManagedDevicesUrl/{deviceId}"
foreach($duplicatedDevice in $duplicatedDevices) {
    # Find device which is the newest.
    $newestDevice = $duplicatedDevice.Group | Sort-Object -Property lastSyncDateTime -Descending | Select-Object -First 1
    Write-Log -Level "INFO" -Message "Serial: $($duplicatedDevice.Name)"
    Write-Log -Level "INFO" -Message "Newest: $($newestDevice.deviceName) $($newestDevice.lastSyncDateTime)"
    $oldDevices = $duplicatedDevice.Group | Where-Object { $_.lastSyncDateTime -ne $newestDevice.lastSyncDateTime }
    foreach($oldDevice in $oldDevices) {   
        $deviceID = $oldDevice.id
        $deviceURL = $baseDeviceURL -replace "{deviceId}", $deviceID 
        Invoke-RestMethod -Uri $deviceURL -Method DELETE -Headers $authHeaders 
        Write-Log -Level "INFO" -Message "Deleted $($oldDevice.deviceName) $($oldDevice.lastSyncDateTime)"       
    }
}