<#
.SYNOPSIS
    This script cleans up inactive devices from a given site.

.DESCRIPTION
    This script first creates a new scheduled task log file in a specified folder.
    It then connects to a site using the given Site Code and SMS Provider machine name.
    After connecting, it pulls the list of inactive clients and attempts to remove any clients that are not found in AD.
    Any errors, as well as a summary of the cleanup, are logged to the scheduled task log file.

    To run this script, press 'F5' in PowerShell.

.PARAMETERS
    $SiteCode: Code of the site to connect to.
    $ProviderMachineName: SMS Provider machine name for the site.

.NOTES
This script requires that the SCCM/MECM console is installed on the machine running the script.
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors
$Global:org = "ORG"
$Global:scriptName = "SCCM-NotAD-Cleanup"
$SiteCode = "101" # Site code 
$ProviderMachineName = "server.org.local" # SMS Provider machine name

# Do not change anything below this line

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
        $orgFolder = "$env:ProgramData\$org"
    }
    else {
        $orgFolder = "$Home\AppData\Roaming\$org"
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

# Import the ConfigurationManager.psd1 module 
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams   
    Write-Log -Level "INFO" -Message "$time Importing Configuration Manager Module" 
}

# Connect to the site's drive if it is not already present
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams    
    Write-Log -Level "INFO" -Message "$time Connecting to Site's Drive"
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams



Write-Log -Level "INFO" -Message "$time Pulling List of Inactive Clients"
$InactiveClients = Get-CMDevice | Where-Object {$_.ClientActiveStatus -eq 0 -or $_.ClientActiveStatus -eq $null -and $_.Name -notlike "*Unknown Computer*"}
$InactiveClientsCount = $InactiveClients.Count

Write-Log -Level "INFO" -Message "$time Number of Inactive Clients: $InactiveClientsCount"

 
ForEach($InactiveClient in $InactiveClients) {     
    Try {
        
        If((Get-ADComputer -Identity $($InactiveClient.Name))) {
            #Write-Host "Still exists $($InactiveClient.Name)"
            continue
        }
        If(!(Get-ADComputer -Identity $($InactiveClient.Name))) {
            Write-Host "$($InactiveClient.Name)"              
            Write-Log -Level "INFO" -Message "$time Inactive Client: $($InactiveClient.Name)"
        }
    }
    Catch {
        Try {
        Remove-CMDevice -Name $($InactiveClient.Name) -Force
        Write-Host "Removed: $($InactiveClient.Name)"         
        Write-Log -Level "INFO" -Message "$time Removed: $($InactiveClient.Name)"
        }
        Catch {
        Write-Host "Failed to Remove: $($InactiveClient.Name)"         
        Write-Log -Level "ERROR" -Message "$time Failed to Remove: $($InactiveClient.Name)" 
        } 
    }
}
Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"


