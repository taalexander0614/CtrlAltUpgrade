<#
.SYNOPSIS
A detection script that is part of a proactive remediation used to delete specified registry keys/paths.

.DESCRIPTION


.PARAMETER


.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$Global:org = "ORG"
$Global:scriptName = "Delete Registry Keys"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

# Registry keys you want to delete. Remember that if you copy the key from RegEdit, you need to make sure it starts with HKLM:.
$keyPaths = @(
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\microsoft_edge~Policy~microsoft_edge~Extensions",
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist"
)

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
 
Write-Log -Level "INFO" -Message "====================== Start $scriptName Remediation Log ======================"

Write-Log -Level "DEBUG" -Message "Keys in `$keyPath:"
$keyPaths | ForEach-Object {
    if ($_.Trim() -ne "") {
        Write-Log -Level "DEBUG" -Message $_
    }
}

foreach ($keyPath in $keyPaths) {
    Write-Log -Level "DEBUG" -Message "Checking for $keyPath"
    if (Test-Path -Path $keyPath) {
        Write-Log -Level "DEBUG" -Message "Found $keyPath"
        try {
            Remove-Item -Path $KeyPath -Force
            Write-Log -Level "INFO" -Message "Removed $keyPath"
        }
        catch {
            Write-Log -Level "ERROR" -Message "Failed to remove $keyPath"
        }
    }
    else {
        Write-Log -Level "DEBUG" -Message "Did not find $keyPath"
    }
}

Write-Log -Level "INFO" -Message "====================== End $scriptName Remediation Log ======================"

##End Script