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
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
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
$org = "ORG"
$Script = "SCCM-NotAD-Cleanup"
$SiteCode = "101" # Site code 
$ProviderMachineName = "anxsccm.rcs.local" # SMS Provider machine name

# Do not change anything below this line

# Define the log file path
$orgFolder = "$env:ProgramData\$org"
$logFolder = "$orgFolder\Logs"
$logFileName = "$Script" + "_" + (Get-Date -Format "MM-dd-yy") + ".log"
$logFile = Join-Path -Path $TaskFolder -ChildPath $logFileName

if (!(Test-Path $LogFolder)) {
    New-Item $LogFolder -Type Directory -Force | Out-Null
}

if (!(Test-Path $TaskFolder)) {
    New-Item $TaskFolder -Type Directory -Force | Out-Null
}

# Initialization of the log file with current date and time
$dateTime = Get-Date
$time = Get-Date -Format "[HH:mm:ss]:"
Out-File $logFile -Append -InputObject "====================== Scheduled Task Creation ======================"
$time = Get-Date -Format "[HH:mm:ss]:"
Out-File $logFile -Append -InputObject $dateTime

# Import the ConfigurationManager.psd1 module 
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
    $time = Get-Date -Format "[HH:mm:ss]:"
    Out-File $logFile -Append -InputObject "$time Importing Configuration Manager Module" 
}

# Connect to the site's drive if it is not already present
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    $time = Get-Date -Format "[HH:mm:ss]:"
    Out-File $logFile -Append -InputObject "$time Connecting to Site's Drive"
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams


$time = Get-Date -Format "[HH:mm:ss]:"
Out-File $logFile -Append -InputObject "$time Pulling List of Inactive Clients"
$InactiveClients = Get-CMDevice | Where-Object {$_.ClientActiveStatus -eq 0 -or $_.ClientActiveStatus -eq $null -and $_.Name -notlike "*Unknown Computer*"}
$InactiveClientsCount = $InactiveClients.Count
$time = Get-Date -Format "[HH:mm:ss]:"
Out-File $logFile -Append -InputObject "$time Number of Inactive Clients: $InactiveClientsCount"

 
ForEach($InactiveClient in $InactiveClients) {     
    Try {
        
        If((Get-ADComputer -Identity $($InactiveClient.Name))) {
            #Write-Host "Still exists $($InactiveClient.Name)"
            continue
        }
        If(!(Get-ADComputer -Identity $($InactiveClient.Name))) {
            Write-Host "$($InactiveClient.Name)"  
            $time = Get-Date -Format "[HH:mm:ss]:"
            Out-File $logFile -Append -InputObject "$time Inactive Client: $($InactiveClient.Name)"
        }
    }
    Catch {
        Try {
        Remove-CMDevice -Name $($InactiveClient.Name) -Force
        Write-Host "Removed: $($InactiveClient.Name)" 
        $time = Get-Date -Format "[HH:mm:ss]:"
        Out-File $logFile -Append -InputObject "$time Removed: $($InactiveClient.Name)"
        }
        Catch {
        Write-Host "Failed to Remove: $($InactiveClient.Name)"  
        $time = Get-Date -Format "[HH:mm:ss]:"
        Out-File $logFile -Append -InputObject "$time Failed to Remove: $($InactiveClient.Name)" 
        } 
    }
}


