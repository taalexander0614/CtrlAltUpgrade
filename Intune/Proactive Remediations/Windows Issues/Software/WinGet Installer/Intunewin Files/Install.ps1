<#
.SYNOPSIS
This script provides the functionality to install or uninstall an application using the Windows Package Manager (winget). 

.DESCRIPTION
The script accepts three mandatory parameters: the application name ($AppName), the action (install or uninstall), and an optional parameter for passing additional parameters to winget.

The script first checks if the log directory exists, if not, it creates it. It then initiates logging to a file named after the application.

Then it checks if winget is installed in the system. If not, it throws an error and exits.

Depending on the action parameter, the script either installs or uninstalls the application. If installing, it can also handle the removal of a desktop shortcut if a shortcut name is provided.

.PARAMETERS
-AppName: The name of the application to install/uninstall.
-Action: The action to perform, either "Install" or "Uninstall".
-shortcutName: The name of the shortcut to remove from the desktop after installation (optional).
-param: Additional parameters to pass to winget (optional).

.INPUTS
None. You cannot pipe inputs to this script.

.OUTPUTS
None. This script does not produce any output.

.EXAMPLE
PS> .\script.ps1 -AppName "ETHZurich.SafeExamBrowser" -Action "Install"

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>


Param
  (
    [parameter(Mandatory=$false)]
    [String[]]
    $param,
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [ValidateSet("Install","Uninstall")]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$shortcutName
  )

$org = "Org"  

# Define the log file path
$orgFolder = "$env:ProgramData\$org"
$logDir = "$orgFolder\Logs"
$appLogDir = "$logDir\Apps"
$logFilePath = "$appLogDir\$AppName.log"

# Check if log directory exists, if not, create it
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir
}
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $appLogDir
}

Start-Transcript -Path $logFilePath -Force -Append

# resolve winget_exe
$winget_exe = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
if ($winget_exe.count -gt 1) {
        $winget_exe = $winget_exe[-1].Path
}

if (!$winget_exe) {
    Write-Error "Winget not installed"
    Exit 1
}

if ($Action -eq "Install") {
    if ($AppName -eq "ETHZurich.SafeExamBrowser") {
        & $winget_exe install --exact --id $AppName --silent --accept-package-agreements --accept-source-agreements $param
    }
    else {
        & $winget_exe install --exact --id $AppName --silent --accept-package-agreements --accept-source-agreements --scope=machine $param
    }
    if ($shortcutName) {
        # Checking for desktop shortcut
        $publicDesktopPath = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
        $shortcutPath = Join-Path -Path $publicDesktopPath -ChildPath "$shortcutName.lnk"
        if (Test-Path -Path $shortcutPath) {
            Try {
                Remove-Item -Path $shortcutPath -Force
            }
            Catch {
                Continue
            }
        }
    }
}
if ($Action -eq "Uninstall") {
    & $winget_exe uninstall --id $AppName --silent --scope=machine $param
}
Stop-Transcript