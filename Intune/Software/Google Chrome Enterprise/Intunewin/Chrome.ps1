<#
.SYNOPSIS
This script is used for installing or uninstalling Google Chrome in an organization's environment.

.DESCRIPTION
The script first checks if the log directory exists, and if not, it creates the directory. It then logs messages to a log file.

The script operates in two modes: "Install" and "Uninstall".

In "Uninstall" mode, the script checks if Google Chrome is installed. If it is, the script attempts to uninstall Google Chrome, logging the process along the way. 

In "Install" mode, the script downloads the Google Chrome MSI installer from a specified URL, logs the download process, and then installs Google Chrome. If a previous installer is detected, it is removed before the new installer is downloaded. After installation, the script checks for a Google Chrome desktop shortcut and deletes it if it's found. It then cleans up the installer files.

.PARAMETERS
$action: The operation to perform. Can be "Install" or "Uninstall".

.INPUTS
The script does not accept any inputs.

.OUTPUTS
The script does not return any outputs. It writes log messages to a file during the installation or uninstallation process.

.EXAMPLE
PS> .\Chrome.ps1 -action "Install"
PS> .\Chrome.ps1 -action "Uninstall"

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Install","Uninstall")]
    [string]$Action
)

# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Chrome Enterprise Online Installer"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR
$ChromeUrl = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"


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

if ($action -eq "Uninstall"){
    Write-Log -Level "INFO" -Message "Start Uninstall Script"
    try {
        $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "Google Chrome*" }
        if ($app) {
            Write-Log -Level "INFO" -Message "Found Google Chrome. Attempting to uninstall..."
            Start-Process -FilePath "cmd.exe" -ArgumentList "/C", $app.UninstallString -Wait -NoNewWindow
            Write-Log -Level "INFO" -Message "Google Chrome has been uninstalled."
        } 
        else {
            Write-Log -Level "INFO" -Message "Google Chrome is not installed."
        }
    }
    catch {
        Write-Log -Level "ERROR" -Message "An error occurred: $_"
        exit 1
    }
}
if ($action -eq "Install") {
    Write-Log -Level "INFO" -Message "Start Install Script"
    # Define the URL and output file path
    $output = Join-Path -Path $env:TEMP -ChildPath "chrome.msi"
    if (Test-Path -Path $output) {
        Write-Log -Level "INFO" -Message "Previous installer detected, attempting to remove"
        Try {
        Remove-Item -Path $output -Force
        Write-Log -Level "INFO" -Message "Successfully removed"
        }
        Catch {
            Write-Log -Level "ERROR" -Message "Failed to remove: $_"
        }
    }
    # Download the file
    Write-Log -Level "INFO" -Message "Downloading installer from $ChromeUrl"
    Try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($ChromeUrl, $output)
        Write-Log -Level "INFO" -Message "Successfully downloaded installer"
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Error downloading installer: $_"
        Exit 1
    }

    # Install the MSI
    Try {
        Write-Log -Level "INFO" -Message "Executing installer: $output"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $output, "/qn" -Wait
        Write-Log -Level "INFO" -Message "Successfully installed, checking for desktop shortcut"
        # Checking for desktop shortcut
        $publicDesktopPath = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
        $shortcutPath = Join-Path -Path $publicDesktopPath -ChildPath "Google Chrome.lnk"
        if (Test-Path -Path $shortcutPath) {
            Write-Log -Level "INFO" -Message "Shortcut Found. Deleting..."
            Try {
                Remove-Item -Path $shortcutPath -Force
                Write-Log -Level "INFO" -Message "Shortcut deleted successfully."
            }
            Catch {
                Write-Log -Level "ERROR" -Message "Failed to remove shortcut :$_"
            }
        }
        else {
            Write-Log -Level "INFO" -Message "No shortcut found on the public desktop."
        }
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Error executing installer: $_"
    }
    # Delete the MSI
    Try {
        Write-Log -Level "INFO" -Message "Cleaning up installer files"
        Remove-Item -Path $output
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Error cleaning up files: $_"
    }
}

