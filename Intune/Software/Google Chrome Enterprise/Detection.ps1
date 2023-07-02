<#
.SYNOPSIS
This script is used for detecting if Google Chrome is installed in an organization's environment.

.DESCRIPTION
The script first checks if the log directory exists, and if not, it creates the directory. It then logs messages to a log file.

The script checks if Google Chrome is installed by querying the uninstall registry keys. If Google Chrome is found, it logs the finding and writes "Installed" to the output. If Google Chrome is not found, it logs the absence and writes "Not Installed" to the output.

.OUTPUTS
The script returns "Installed" if Google Chrome is found or "Not Installed" if Google Chrome is not found. It also writes log messages to a file during the detection process.

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Chrome Detection Script"

# Function to log messages
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

Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

try {
    $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "Google Chrome*" }
    if ($app) {
        Write-Log -Level "INFO" -Message "Found Google Chrome."
        Write-Output "Installed"
        Exit 0        
    } 
    else {
        Write-Log -Level "WARN" -Message "Google Chrome is not installed."
        Write-Output "Not Installed"
        Exit 1
    }
}
catch {
    Write-Log -Level "ERROR" -Message "An error occurred: $_"
    exit 1
}
