<#
.SYNOPSIS
This script unpins specified apps from the taskbar and logs the process.

.DESCRIPTION
The script creates a log directory if it doesn't exist, then logs the process of unpinning each specified app from the taskbar. The apps to unpin are defined in the $pinnedApps array.

-This script needs to be deployed in the user context

.OUTPUTS
The script outputs logs to a file in the directory specified by $orgFolder.

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
Tested on Windows 10 and 11 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Unpin Taskbar Apps"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

# Add the apps you want to unpin from the taskbar
$pinnedApps = $null
$pinnedApps += "Microsoft Store"

# The rest of the script does not need to be modified
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
Write-Log -Level "INFO" -Message "Apps to be unpinned are $pinnedApps"

# Create a new shell application object
Write-Log -Level "INFO" -Message "Creating shell application object"
$shell = New-Object -ComObject "Shell.Application"

# Get the current user's namespace
Write-Log -Level "INFO" -Message "Getting Current User's Namespace"
$namespace = $shell.Namespace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}")

# An array to get the pinned apps
$detectedApps = @()
Write-Log -Level "INFO" -Message "Getting pinned apps"
ForEach ($pinnedApp in $pinnedApps) {
    # Get the app
    $app = $namespace.Items() | Where-Object { $_.Name -eq $pinnedApp }

    # If the app exists, unpin it
    if ($app) {
        Write-Log -Level "INFO" -Message "Found $pinnedApp"
        $verb = $app.Verbs() | Where-Object { $_.Name.Replace('&', '') -match 'Unpin from taskbar' }
        if ($verb) {
            Write-Log -Level "INFO" -Message "$pinnedApp has option to unpin"
            $detectedApps += $pinnedApp
        } 
        else {
            Write-Log -Level "INFO" -Message "$pinnedApp does not have the option to unpin"
        }
    } 
    else {
        Write-Log -Level "INFO" -Message "Could not detect whether $pinnedApp has option to unpin"
    }
}
if ($detectedApps.count -eq 0) {
    Write-Log -Level "INFO" -Message "No apps to unpin"
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
    Exit 0    
}
else {
    Write-Log -Level "INFO" -Message "Apps to unpin are $detectedApps"
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
    Exit 1
}
