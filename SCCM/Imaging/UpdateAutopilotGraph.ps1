<#
.SYNOPSIS
This script retrieves and updates Windows Autopilot Device Identities using the Microsoft Graph API.

.DESCRIPTION
The script uses the Microsoft Graph API to interact with device identities. It gets the device identity using 
the serial number, checks if the device is enrolled in Autopilot, and if so, deletes the Intune record and 
updates the device properties.

.PARAMETERS
-Tenant: The tenant ID for the Microsoft Graph API.
-Secret: The secret used to authenticate with the Microsoft Graph API.
-AppID: The application ID for the Microsoft Graph API.

If the script is not running within a Task Sequence Environment, the following parameters are mandatory:
-displayName: The display name of the device to update.
-groupTag: The group tag of the device to update.

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
This script will update the displayName and groupTag of devices already enrolled in Autopilot

.NOTES
To run this script within a Task Sequence Environment, ensure that OSDComputerName and GroupTag are set in the environment.
I know there are scripts you can install but in WinPE you do not have the ability to install scripts or modules natively.
To keep things simple, I chose to go this route instead of adding another part to enable the use of the PSGallery.
The app will need these permissions: 
--DeviceManagementConfiguration.ReadWrite.All: Required to read and write device management configurations.
--DeviceManagementManagedDevices.ReadWrite.All: Required to read and write managed devices.
--DeviceManagementManagedDevices.PrivilegedOperations.All: Required to perform privileged operations on managed devices.
--DeviceManagementServiceConfig.ReadWrite.All: Required to read and write service configurations.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$tenant = "",
    [Parameter(Mandatory=$true)]
    [string]$appID ="",
    [Parameter(Mandatory=$true)]
    [string]$secret = "",
    [Parameter(Mandatory=$false)]
    [string]$displayName,
    [Parameter(Mandatory=$false)]
    [string]$groupTag
)

# Check if script is running within a task sequence
if (Test-Path env:OSDComputerName) {
    # Get displayName and groupTag from Task Sequence
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment  
    $displayName = $TSEnv.Value("OSDComputerName")
    $groupTag = $TSEnv.Value("GroupTag")
}

# Get an auth token
$tokenUrl = "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token"
$body = @{
    client_id     = $appId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $Secret
    grant_type    = "client_credentials"
}
$response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body
$token = $response.access_token

# Get Serial Number
$win32BIOS = (get-wmiobject -Class win32_bios)
$serial = $win32BIOS.SerialNumber

# Call the Graph API to get the device
$apiUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
$headers = @{
    Authorization = "Bearer $token"
}
$device = $null
do {
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    $device = $response.value | Where-Object { $_.serialNumber -eq $serial }
    $apiUrl = $response.'@odata.nextLink'
} while ($apiUrl -and -not $device)

# Check if the device is in Autopilot
if ($device) {
    Write-Output "Device is in Autopilot"
    Write-Output "Deleting Intune Record"
    $manageddeviceId = $device.manageddeviceid
    # Send Wipe Command
    # Documentation says delete doesn't work without Wipe or Retire first but it seems to for me
    #$Resource = "deviceManagement/managedDevices/$managedDeviceId/wipe"
    #$uri = "https://graph.microsoft.com/beta/$($resource)"
    #write-verbose $uri
    #Write-Verbose "Sending wipe command to $managedDeviceId"
    #Invoke-RestMethod -Uri $uri -Headers $headers -Method Post

    # Delete Device
    $Resource = "deviceManagement/managedDevices('$managedDeviceId')"
    $uri = "https://graph.microsoft.com/beta/$($resource)"
    Write-Verbose "Sending delete command to $managedDeviceId"
    Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete

    # Update the device
    $deviceId = $device.id
    $apiUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId/updateDeviceProperties"
    $body = @{
        displayName = $displayName
        groupTag    = $groupTag
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -Headers $headers -ContentType "application/json"
    Write-Output "Device updated"
} 
else {
    Write-Output "Device is not in Autopilot"
}

