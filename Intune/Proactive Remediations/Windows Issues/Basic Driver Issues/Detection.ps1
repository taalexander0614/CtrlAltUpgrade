<#
.SYNOPSIS
This script is designed to identify issues related to drivers. 

.DESCRIPTION
This script checks for missing and disabled drivers using WMI queries and logs the results to a log file.

.INPUTS
None

.OUTPUTS
The script creates a log file in the specified organization folder and logs the driver information.

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.
Ensure that you have administrative privileges to run this script.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$Global:org = "ORG"
$Global:scriptName = "Driver Error Detection"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

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
# Start Log
Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# Check for missing and disabled drivers using WMI queries
Write-Log -Level "INFO" -Message "Checking for missing and disabled drivers"
$Drivers_Test = Get-WmiObject Win32_PNPEntity | Where-Object { $_.ConfigManagerErrorCode -gt 0 }
$Search_Disabled_Missing_Drivers = ($Drivers_Test | Where-Object {($_.ConfigManagerErrorCode -eq 22) -or ($_.ConfigManagerErrorCode -eq 28)})

If(($Search_Disabled_Missing_Drivers).Count -gt 0) {
    $Search_Missing_Drivers = ($Search_Disabled_Missing_Drivers | Where-Object {$_.ConfigManagerErrorCode -eq 28}).Count
    $Search_Disabled_Drivers = ($Search_Disabled_Missing_Drivers | Where-Object {$_.ConfigManagerErrorCode -eq 22}).Count

    Write-Log -Level "ERROR" -Message "There is an issue with drivers."
	Write-Log -Level "ERROR" -Message "Missing drivers: $Search_Missing_Drivers"
	Write-Log -Level "ERROR" -Message "Disabled drivers: $Search_Disabled_Drivers"
    # Log information about each disabled or missing driver
    ForEach($Driver in $Search_Disabled_Missing_Drivers) {
        $Driver_Name = $Driver.Caption
        $Driver_DeviceID = $Driver.DeviceID
        Write-Log -Level "ERROR" -Message "Driver name is: $Driver_Name"
        Write-Log -Level "ERROR" -Message "Driver device ID is: $Driver_DeviceID"
    }
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
	Exit 1
}
Else {
    Write-Log -Level "INFO" -Message "There is no issue with drivers."
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
    Exit 0
}
