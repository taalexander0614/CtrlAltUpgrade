<#
.SYNOPSIS
This script is designed to fix issues related to drivers. 

.DESCRIPTION
This script is designed to search for and install pending driver updates using the Windows Update service. 
It utilizes the Microsoft.Update API to perform the necessary operations.
It displays available driver updates, downloads and installs them, and checks if a reboot is required.

.INPUTS
None

.OUTPUTS
This script creates a log file in the specified organization folder and logs the driver information.

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.
Ensure that you have administrative privileges to run this script.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$Global:org = "RCS"
$Global:scriptName = "Driver Error Remediation"

Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level,       
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $orgFolder = "$env:PROGRAMDATA\$org"
    $logFolder = "$orgFolder\Logs"
    $logFile = "$logFolder\$scriptName.log"
    # Create organization folder and log if they don't exist
    If(!(Test-Path $orgFolder)){New-Item $orgFolder -ItemType Directory -Force | Out-Null}
    If(!(Test-Path $logFolder)){New-Item $logFolder -ItemType Directory -Force | Out-Null}
    If(!(Test-Path $logFile)){New-Item $logFile -ItemType File -Force | Out-Null}
    # Set log date stamp
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
}

Write-Log -Level "INFO" -Message "====================== Start Log ======================"

# Check Windows Update for drivers
$UpdateSvc = New-Object -ComObject Microsoft.Update.ServiceManager
$UpdateSvc.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()
$Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
$Searcher.SearchScope = 1 # MachineOnly
$Searcher.ServerSelection = 3 # Third Party
$Criteria = "IsInstalled=0 and Type='Driver'"
Write-Log -Level "INFO" -Message 'Searching for Driver Updates...' 
$SearchResult = $Searcher.Search($Criteria)
$Updates = $SearchResult.Updates

# Check if there are any pending driver updates
if ([string]::IsNullOrEmpty($Updates)) {
    Write-Log -Level "INFO" -Message "No pending driver updates."
}
else {
    # Add the updates to the download collection
    $Updates | Select-Object Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | Format-List
    $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { $UpdatesToDownload.Add($_) | Out-Null }

    # Download the drivers
    Write-Log -Level "INFO" -Message 'Downloading Drivers...'
    $Downloader = $Session.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Downloader.Download()

    # Install the driver
    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { if ($_.IsDownloaded) { $UpdatesToInstall.Add($_) | Out-Null } }
    Write-Log -Level "INFO" -Message 'Installing Drivers...'
    $Installer = $Session.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()

    if ($InstallationResult.RebootRequired) {
        Write-Log -Level "INFO" -Message 'Reboot required.'
    }
    else {
        Write-Log -Level "INFO" -Message 'Done.' 
    }

    # Remove the Windows Update service
    $updateSvc.Services | Where-Object { $_.IsDefaultAUService -eq $false -and $_.ServiceID -eq "7971f918-a847-4430-9279-4a52d1efe18d" } | ForEach-Object { $UpdateSvc.RemoveService($_.ServiceID) }
}
