<#
.SYNOPSIS
This script is part of an Intune proactive remediation and detects unwanted shortcuts from the public desktop and logs the process.

.DESCRIPTION
The script creates a log directory if it doesn't exist, then logs the process of checking for each shortcut. The shortcuts to check are defined in the $iconsToRemove array.

-This script needs to be deployed in the system context (Or at least run with admin rights) to remove the public desktop icons.

.OUTPUTS
The script outputs logs to a file in the directory specified by $orgFolder.

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
Tested on Windows 10 and 11 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Remove Public Desktop Icons"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

# Define the list of icons to remove
$iconsToRemove = @(
    "Clever.lnk",
    "AR Bookfinder.url",
    "Calculator.url",
    "Educator's Handbook.lnk"
)

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

Write-Log -Level "INFO" -Message "====================== Start $scriptName Detection Log ======================"

# Define the path to the public desktop
$publicDesktopPath = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
Write-Log -Level "DEBUG" -Message "Public Desktop Path: $publicDesktopPath"
# Convert the array to a single string with a comma separator
$iconsToRemoveString = $iconsToRemove -join ', '
# Write the string to the log
Write-Log -Level "INFO" -Message "Icons to check: $iconsToRemoveString"


# Iterate over each icon in the list
foreach ($icon in $iconsToRemove) {
    # Define the full path to the icon
    $iconPath = Join-Path -Path $publicDesktopPath -ChildPath $icon
    Write-Log -Level "DEBUG" -Message "Icon Path: $iconPath"
    # Check if the icon exists
    if (Test-Path -Path $iconPath) {
        Write-Log -Level "INFO" -Message "Found icon: $icon"
        Exit 1
    }
}
Write-Log -Level "INFO" -Message "Icons not found"
Write-Log -Level "INFO" -Message "====================== End $scriptName Detection Log ======================"
Exit 0