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
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$org = "RCS"

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
Logwrite "Start Detection Script"
try {
    $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "Google Chrome*" }
    if ($app) {
        LogWrite "Found Google Chrome."
        Write-Output "Installed"
        Exit 0        
    } 
    else {
        LogWrite "Google Chrome is not installed."
        Write-Output "Not Installed"
        Exit 1
    }
}
catch {
    LogWrite "An error occurred: $_"
    exit 1
}
