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

$org = "ORG"
$ChromeUrl = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"

# Define the log file path
$orgFolder = "$env:ProgramData\$org"
$logDir = "$orgFolder\Logs"
$appLogDir = "$logDir\Apps"
$logFilePath = "$appLogDir\Chrome.log"

# Function to log messages
function LogWrite
{
    param([string]$logstring)

    Add-content $logFilePath -value "$(Get-Date) - $logstring"
}

# Check if log directory exists, if not, create it
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir
}
if (-not (Test-Path -Path $appLogDir)) {
    New-Item -ItemType Directory -Force -Path $appLogDir
}
if (-not (Test-Path -Path $logFilePath)){
    New-Item -Path $appLogDir -Name Chrome.log -ItemType File
}

if ($action -eq "Uninstall"){
    LogWrite "Start Uninstall Script"
    try {
        $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "Google Chrome*" }
        if ($app) {
            LogWrite "Found Google Chrome. Attempting to uninstall..."
            Start-Process -FilePath "cmd.exe" -ArgumentList "/C", $app.UninstallString -Wait -NoNewWindow
            LogWrite "Google Chrome has been uninstalled."
        } 
        else {
            LogWrite "Google Chrome is not installed."
        }
    }
    catch {
        LogWrite "An error occurred: $_"
        exit 1
    }
}
if ($action -eq "Install") {
    LogWrite "Start Install Script"
    # Define the URL and output file path
    $output = Join-Path -Path $env:TEMP -ChildPath "chrome.msi"
    if (Test-Path -Path $output) {
        LogWrite "Previous installer detected, attempting to remove"
        Try {
        Remove-Item -Path $output -Force
        LogWrite "Successfully removed"
        }
        Catch {
            LogWrite "Failed to remove: $_"
        }
    }
    # Download the file
    LogWrite "Downloading installer from $ChromeUrl"
    Try {
        Invoke-WebRequest -Uri $ChromeUrl -OutFile $output
        LogWrite "Successfully downloaded installer"
    }
    Catch {
        LogWrite "Error downloading installer: $_"
        Exit 1
    }

    # Install the MSI
    Try {
        LogWrite "Executing installer: $output"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $output, "/qn" -Wait
        LogWrite "Successfully installed, checking for desktop shortcut"
        # Checking for desktop shortcut
        $publicDesktopPath = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
        $shortcutPath = Join-Path -Path $publicDesktopPath -ChildPath "Google Chrome.lnk"
        if (Test-Path -Path $shortcutPath) {
            LogWrite "Shortcut Found. Deleting..."
            Try {
                Remove-Item -Path $shortcutPath -Force
                LogWrite "Shortcut deleted successfully."
            }
            Catch {
                LogWrite "Failed to remove shortcut :$_"
            }
        }
        else {
            LogWrite "No shortcut found on the public desktop."
        }
    }
    Catch {
        LogWrite "Error executing installer: $_"
    }
    # Delete the MSI
    Try {
        LogWrite "Cleaning up installer files"
        Remove-Item -Path $output
    }
    Catch {
        LogWrite "Error cleaning up files: $_"
    }
}

