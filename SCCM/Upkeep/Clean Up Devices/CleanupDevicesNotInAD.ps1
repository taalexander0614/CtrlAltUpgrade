<#
.SYNOPSIS
    This script cleans up devices still in SCCM but not in Active Directory (and Intune if using Co-Management).

.DESCRIPTION
    This script connects to your SCCM site using the given Site Code and SMS Provider machine name.
    After connecting, it pulls the list of inactive clients and attempts to remove any clients that are not found in Active Directory (or Intune if using Co-Management).
    Any errors, as well as a summary of the cleanup, are logged.
    The script can be run as a scheduled task or manually.
    Setting the $audit variable to $true will prevent any changes from being made so you can review the log file before running in production.

.NOTES
    This script was created for use with my organization's resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
    I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
    Tested on Windows 10 with PowerShell 5.1.

    If your environment is using Co-Management (SCCM and Intune), uncomment the $coManaged variable so it is set to $true. This allows the script to check devices using Microsoft Graph and Active Directory. If a device is not found in either, it will be removed from SCCM.
    If your environment is not using Co-Management, just comment out the $coManaged variable line, and the script will only check devices in Active Directory.

    The script uses the Get-ADComputer cmdlet to retrieve the list of devices from Active Directory. For Co-Management scenarios, it uses the Microsoft Graph API to obtain the list of devices from Intune.
    If using the $coManaged variable, the app you use will need these permissions: 
    --DeviceManagementConfiguration.ReadWrite.All: Required to read and write device management configurations.
    --DeviceManagementManagedDevices.ReadWrite.All: Required to read and write managed devices.
    --DeviceManagementManagedDevices.PrivilegedOperations.All: Required to perform privileged operations on managed devices.
    --DeviceManagementServiceConfig.ReadWrite.All: Required to read and write service configurations.

.AUTHOR
    Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
#>


# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Cleanup Devices Not in AD"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

# Script parameters
$auditOnly = $true # Set to $true to enable audit mode (no changes will be made)
$coManaged = $true # Set to $true if using Co-Management and need to prevent deleting Intune devices from SCCM
$SiteCode = "101" # Site code 
$ProviderMachineName = "sitesccm.org.local" # SMS Provider machine name
# If you are not using Co-Management, set $coManaged to $false and don't worry about the rest of the Intune variables
$tenantId = '*********************'
$appId = '*********************'
$appSecret = '*********************'

# Do not change anything below this line

# Function to log messages
Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    # Compare the priority of logging level
    $LogPriority = @{
        "DEBUG" = 0
        "INFO"  = 1
        "WARN"  = 2
        "ERROR" = 3
    }

    if($LogPriority[$Level] -ge $LogPriority[$Global:logLevel]) {
        # Determine whether the script is running in user or system context
        $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($userName -eq "NT AUTHORITY\SYSTEM") {
            $Global:orgFolder = "$env:ProgramData\$org"
        }
        else {
            $Global:orgFolder = "$Home\AppData\Roaming\$org"
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
}

# Function to get access token
function Get-AccessToken {
    param (
        [Parameter(Mandatory=$true)]
        [string]$tenantId,
        [Parameter(Mandatory=$true)]
        [string]$appId,
        [Parameter(Mandatory=$true)]
        [string]$appSecret
    )
    Write-Log -Level "DEBUG" -Message "Getting access token"
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    $tokenBody = @{
        client_id     = $appId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $appSecret
        grant_type    = "client_credentials"
    }

    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    Write-Log -Level "DEBUG" -Message "Retrieved access token"
    return $tokenResponse.access_token
}

Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# Import the ConfigurationManager.psd1 module 
try {
    if($null -eq (Get-Module ConfigurationManager)) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
    }
    Write-Log -Level "INFO" -Message "Imported Configuration Manager Module"
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to import Configuration Manager Module: $($_.Exception.Message)"
}

# Connect to the site's drive if it is not already present
try {
    if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
    }
    Write-Log -Level "INFO" -Message "Connected to Site's Drive"
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to connect to Site's Drive: $($_.Exception.Message)"
}

# Set the current location to be the site code.
try {
    Set-Location "$($SiteCode):\"
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to set location: $($_.Exception.Message)"
}

# Filter SCCM query to skip "Unknown Computer" and servers
Write-Log -Level "INFO" -Message "Pulling List of Devices from SCCM"
try {
    $allDevices = Get-CMDevice | Where-Object { $_.DeviceOS -notlike "*Server*" -and $_.Name -notlike "*Unknown Computer*" -and $_.Domain -like $localDomain} 
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to pull list of devices: $($_.Exception.Message)"
}


# Import the ActiveDirectory module
try {
    if($null -eq (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }
    Write-Log -Level "INFO" -Message "Imported Active Directory Module"
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to import Active Directory Module: $($_.Exception.Message)"
}
Write-Log -Level "INFO" -Message "Pulling List of Devices from Active Directory"
try {
    $deviceNames = @()
    $deviceNames = Get-ADComputer -Filter * -Properties Name | ForEach-Object { $_.Name } 
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to pull list of devices: $($_.Exception.Message)"
}
if ($coManaged) {
    $accessToken = Get-AccessToken -tenantId $tenantId -appId $appId -appSecret $appSecret
    # Call Graph API
    Write-Log -Level "INFO" -Message "Pulling List of Devices from Intune"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter=deviceEnrollmentType eq 'windowsCoManagement'"

    $pageCount = 1
    do {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers    
        # Extract device names and add to the list
        $deviceNames += $response.value | ForEach-Object { $_.deviceName } 
        # If there is a next page, update the URI
        $uri = $response.'@odata.nextLink'
        if ($uri) {
            $pageCount++
        }
    } while ($uri)
    Write-Log -Level "INFO" -Message "Acquired $pageCount pages of devices"
}

# If the device name is not in the $deviceNames list, delete it
Write-Log -Level "INFO" -Message "Removing Non-Matching Devices from SCCM"
foreach ($device in $allDevices) {
    if ($device.Name -notin $deviceNames) {
        # Check if the device is in SCCM
        $sccmDevice = Get-CMDevice -Name $device.Name
        if ($null -ne $sccmDevice) {
            if (-not $auditOnly) {
                # Only run Remove-CMDevice in live mode
                Write-Log -Level "INFO" -Message "Removing Device: $($device.Name)"
                Remove-CMDevice -Name $device.Name -Force
            }
            if ($auditOnly) {
                # Only run Remove-CMDevice in live mode
                Write-Log -Level "INFO" -Message "Auditing - Removing Device: $($device.Name)"
            }
        } 
        else {
            Write-Log -Level "INFO" -Message "Device: $($device.Name) not found in SCCM"
        }
    }
}



Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"