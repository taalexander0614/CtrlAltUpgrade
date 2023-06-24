param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Install","Uninstall")]
    [string]$Action
)

# Define the log file path
$logDir = "$env:ProgramData\RCS\Logs"
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
    $url = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"
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
    LogWrite "Downloading installer from $url"
    Try {
        Invoke-WebRequest -Uri $url -OutFile $output
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

