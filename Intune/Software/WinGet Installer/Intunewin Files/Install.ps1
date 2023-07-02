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

.Notes
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.

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

$Global:org = "ORG"
$Global:scriptName = "WinGet Installer"  

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
# Start Log
Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# resolve winget_exe
$winget_exe = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
if ($winget_exe.count -gt 1) {
    Write-Log -Level "INFO" -Message "WinGet has multiple versions installed, using latest version"    
    $winget_exe = $winget_exe[-1].Path
}

if (!$winget_exe) {
    Write-Log -Level "ERROR" -Message "Winget not installed"
    Exit 1
}

if ($Action -eq "Install") {
    if ($AppName -eq "ETHZurich.SafeExamBrowser") {
        Write-Log -Level "INFO" -Message "Installing $AppName with additional parameters: $param"
        & $winget_exe install --exact --id $AppName --silent --accept-package-agreements --accept-source-agreements $param
    }
    else {
        Write-Log -Level "INFO" -Message "Installing $AppName with additional parameters: $param"
        & $winget_exe install --exact --id $AppName --silent --accept-package-agreements --accept-source-agreements --scope=machine $param
    }
    if ($shortcutName) {
        # Checking for desktop shortcut
        Write-Log -Level "INFO" -Message "Checking for desktop shortcut $shortcutName"
        $publicDesktopPath = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
        $shortcutPath = Join-Path -Path $publicDesktopPath -ChildPath "$shortcutName.lnk"
        if (Test-Path -Path $shortcutPath) {
            Write-Log -Level "INFO" -Message "Removing desktop shortcut $shortcutPath"
            Try {
                Remove-Item -Path $shortcutPath -Force
                Write-Log -Level "INFO" -Message "Successfully removed desktop shortcut $shortcutPath"
            }
            Catch {
                Write-Log -Level "ERROR" -Message "Failed to remove desktop shortcut $shortcutPath : $_"
                Continue
            }
        }
    }
}
if ($Action -eq "Uninstall") {
    Write-Log -Level "INFO" -Message "Uninstalling $AppName with additional parameters: $param"
    & $winget_exe uninstall --id $AppName --silent --scope=machine $param
}
Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"