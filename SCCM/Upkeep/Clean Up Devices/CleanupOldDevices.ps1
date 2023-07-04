<#
.SYNOPSIS
This script is used to cleanup stale devices in SCCM and AD.

.DESCRIPTION
The script is designed to help manage device records in Active Directory (AD) and System Center Configuration Manager (SCCM). 
It's particularly useful in scenarios where a change in device naming scheme has resulted in duplicate records. 
The script identifies duplicates based on the last five characters of device names (assumed to be the asset number), and it prioritizes newer devices over older ones based on the naming scheme.
In addition to AD and SCCM, the script also handles device records in Intune, ensuring that devices are properly managed across all three platforms.
Setting the $audit variable to $true will prevent any changes from being made so you can review the log file before running in production.

.INPUTS
No inputs. You cannot pipe objects to this script.

.OUTPUTS
No outputs. This script does not generate any output. It writes directly to the log file.

.NOTES
Ensure that the naming schemes, site code, and provider machine name are correctly set for your environment. 
In case of any errors, they will be logged and script execution will continue with the next device.
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>


# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Cleanup Old Devices"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

# Script parameters
$auditOnly = $true # Set to $true to enable audit mode (no changes will be made)
$SiteCode = "101" # Site code 
$ProviderMachineName = "sitesccm.org.local" # SMS Provider machine name
$oldDeviceNaming = @("*ID*", "*IL*", "*AD*", "*AL*") # Old naming scheme for old devices; use * as a wildcard. We used to use ID and IL for desktops and AD and AL for laptops
$newDeviceNaming = @("*DT*", "*LT*") # New naming scheme for new devices; use * as a wildcard. We now use DT for desktops and LT for laptops
$nameLength = "10" # Minimum number of characters in the device name to be considered valid; meant to help filter out devices with random names or servers
$localDomain = "ORG" # Local domain name

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

Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

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

# Filter SCCM query to skip "Unknown Computer" and set the last five characters of the name as a substring called Asset
Write-Log -Level "INFO" -Message "Pulling List of Devices and Setting Asset Number Property"
try {
    $allDevices = Get-CMDevice | Where-Object { $_.DeviceOS -notlike "*Server*" -and $_.Name.Length -ge $nameLength -and $_.Name -notlike "*Unknown Computer*"} | ForEach-Object {    
        $device = $_ | Select-Object -Property Name, DeviceOS, Domain
        $asset = $_.Name.Substring($_.Name.Length - 5)
        $device | Add-Member -MemberType NoteProperty -Name "Asset" -Value $asset -PassThru
        Write-Log -Level "DEBUG" -Message "Added Asset Property: Name: $($device.Name) Asset: $($device.Asset)"
    }
}
catch {
    Write-Log -Level "ERROR" -Message "Failed to pull list of devices: $($_.Exception.Message)"
}

$duplicateDevices = $allDevices | Group-Object Asset | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Group }

# Perform device operations
try {
    $oldDevices = $duplicateDevices | Where-Object {
        foreach ($old in $oldDeviceNaming) {
            if ($_.Name -like $old) {
                Write-Log -Level "DEBUG" -Message "Old Device: $($_.Name)"
                return $true
            }
        }
        # Return false if none of the search strings matched
        return $false
    }
    $newDevices = $duplicateDevices | Where-Object {
        foreach ($new in $newDeviceNaming) {
            if ($_.Name -like $new) {
                Write-Log -Level "DEBUG" -Message "New Device: $($_.Name)"
                return $true
            }
        }
        # Return false if none of the search strings matched
        return $false
    }
    $domainDevices = $duplicateDevices | Where-Object { $_.Domain -contains $localDomain } 
    $intuneDevices = $duplicateDevices | Where-Object { $_.Domain -contains "WORKGROUP" }

    # Logging
    Write-Log -Level "INFO" -Message "Found $($duplicateDevices.Count) devices with duplicate asset numbers"
    Write-Log -Level "DEBUG" -Message "Old Devices: $($oldDevices.Name -join ', ')"
    Write-Log -Level "DEBUG" -Message "New Devices: $($newDevices.Name -join ', ')"
    Write-Log -Level "DEBUG" -Message "RCS Devices: $($domainDevices.Name -join ', ')"
    Write-Log -Level "DEBUG" -Message "Intune Devices: $($intuneDevices.Name -join ', ')"
}
catch {
    Write-Log -Level "ERROR" -Message "Failed during device operations: $($_.Exception.Message)"
}

# Initialize an empty array to hold names of deleted devices
$deletedDevices = @()

foreach ($oldDevice in $oldDevices) {
    $matchingNewDevice = $newDevices | Where-Object { $_.Asset -eq $oldDevice.Asset }
    if ($matchingNewDevice) {
        
        if ($oldDevice.Name -notin $deletedDevices) {
            try {
                Write-Log -Level "DEBUG" -Message "New device is $($matchingNewDevice.Name)"
                Write-Log -Level "DEBUG" -Message "Removing $($oldDevice.Name) from SCCM"
                if ($auditOnly) {
                    Write-Log -Level "INFO" -Message "Audit - Found $($matchingNewDevice.Name) with the same asset number, removing $($oldDevice.Name) from SCCM."
                }
                if (-not $auditOnly) {
                    Write-Log -Level "INFO" -Message "Found $($matchingNewDevice.Name) with the same asset number, removing $($oldDevice.Name) from SCCM and AD."
                    Remove-CMDevice -DeviceName $oldDevice.Name -Force
                }
                $deletedDevices += $oldDevice.Name
            }
            catch {
                Write-Log -Level "ERROR" -Message "Failed to remove $($oldDevice.Name) from SCCM: $($_.Exception.Message)"
            }

            try {
                Write-Log -Level "DEBUG" -Message "Removing $($oldDevice.Name) from AD"
                $adObject = Get-ADComputer -Identity $oldDevice.Name
                # Check if the object has any child objects
                if ((Get-ADObject -Filter {Parent -eq $adObject.DistinguishedName}).count -gt 0) {
                    # If it does, use Remove-ADObject with -Recursive
                    if ($auditOnly) {
                        Write-Log -Level "INFO" -Message "Audit - $($oldDevice.Name) has child objects, using Remove-ADObject with -Recursive"
                    }
                    if (-not $auditOnly) {
                        Write-Log -Level "DEBUG" -Message "$($oldDevice.Name) has child objects, using Remove-ADObject with -Recursive"
                        Remove-ADObject -Identity $adObject.DistinguishedName -Recursive -Confirm:$false
                    }
                } 
                else {
                    # If it doesn't, use Remove-ADComputer
                    if ($auditOnly) {    
                        Write-Log -Level "INFO" -Message "Audit - $($oldDevice.Name) has no child objects, using Remove-ADComputer"
                    }
                    if (-not $auditOnly) {    
                        Write-Log -Level "DEBUG" -Message "$($oldDevice.Name) has no child objects, using Remove-ADComputer"
                        Remove-ADComputer -Identity $oldDevice.Name -Confirm:$false
                    }
                }
            }
            catch {
                Write-Log -Level "ERROR" -Message "Failed to remove $($oldDevice.Name) from AD: $($_.Exception.Message)"
            }
        } 
        else {
            Write-Log -Level "INFO" -Message "$($oldDevice.Name) has already been removed"
        }
    }
}

foreach ($domainDevice in $domainDevices) {
    $matchingIntuneDevice = $intuneDevices | Where-Object { $_.Asset -eq $domainDevice.Asset }
    if ($matchingIntuneDevice) {
        
        if ($domainDevice.Name -notin $deletedDevices) {
            try {
                Write-Log -Level "DEBUG" -Message "Found $($matchingIntuneDevice.Name) in Intune"
                Write-Log -Level "DEBUG" -Message "Removing $($domainDevice.Name) from SCCM"
                if ($auditOnly) {
                    Write-Log -Level "INFO" -Message "Audit - Found $($matchingIntuneDevice.Name) in Intune, removing $($domainDevice.Name) from SCCM."
                }
                if (-not $auditOnly) {
                    Write-Log -Level "INFO" -Message "Found $($matchingIntuneDevice.Name) in Intune, removing $($domainDevice.Name) from SCCM and AD."
                    Remove-CMDevice -DeviceName $domainDevice.Name -Force
                }
                $deletedDevices += $domainDevice.Name
            }
            catch {
                Write-Log -Level "ERROR" -Message "Failed to remove $($domainDevice.Name) from SCCM: $($_.Exception.Message)"
            }

            try {
                Write-Log -Level "DEBUG" -Message "Removing $($domainDevice.Name) from AD"
                # Get the AD object
                $adObject = Get-ADComputer -Identity $domainDevice.Name
                # Check if the object has any child objects
                if ((Get-ADObject -Filter {Parent -eq $adObject.DistinguishedName}).count -gt 0) {
                    # If it does, use Remove-ADObject with -Recursive
                    if ($auditOnly) {
                        Write-Log -Level "INFO" -Message "Audit - $($domainDevice.Name) has child objects, using Remove-ADObject with -Recursive"
                    }
                    if (-not $auditOnly) {
                        Write-Log -Level "DEBUG" -Message "$($domainDevice.Name) has child objects, using Remove-ADObject with -Recursive"
                        Remove-ADObject -Identity $adObject.DistinguishedName -Recursive -Confirm:$false
                    }
                } 
                else {
                    # If it doesn't, use Remove-ADComputer
                    if ($auditOnly) {
                        Write-Log -Level "INFO" -Message "Audit - $($domainDevice.Name) has no child objects, using Remove-ADComputer"
                    }
                    if (-not $auditOnly) {
                        Write-Log -Level "DEBUG" -Message "$($domainDevice.Name) has no child objects, using Remove-ADComputer"
                        Remove-ADComputer -Identity $domainDevice.Name -Confirm:$false
                    }
                }
            }
            catch {
                Write-Log -Level "ERROR" -Message "Failed to remove $($domainDevice.Name) from AD: $($_.Exception.Message)"
            }
        } 
        else {
            Write-Log -Level "INFO" -Message "$($domainDevice.Name) has already been removed"
        }
    }
}

Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"