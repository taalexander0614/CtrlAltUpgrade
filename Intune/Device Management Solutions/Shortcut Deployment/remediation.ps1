<#
.SYNOPSIS
    This script remediates the shortcuts based on the JSON file.

.DESCRIPTION
    This script remediates the shortcuts based on the JSON file. 
    It reads the JSON file and loops through each shortcut to copy or delete the file based on the action specified in the JSON file.

.PARAMETER logLevel
    The logging level for the script. Valid values are DEBUG, INFO, WARN, ERROR. Default value is INFO.

.PARAMETER orgName
    The organization name to be used for the log folder. Default value is CtrlAltUpgrade.

.PARAMETER scriptName
    The name of the script. Default value is Shortcut Deployment- Remediation.

.PARAMETER logLevel
    The logging level for the script. Valid values are DEBUG, INFO, WARN, ERROR. Default value is INFO.

.NOTES
    - The script employs logging to track its execution, providing insight into the actions taken and any encountered warnings or errors.
    - The logging function will create a log file in the organization's ProgramData or user's AppData\Roaming directory, depending on the context in which the script is executed.
    - Before executing the script in a production environment, thoroughly test it in a controlled setting to verify its functionality and ensure it meets organizational requirements.
#>

$Global:orgName = 'CtrlAltUpgrade'
$Global:scriptName = "Shortcut Deployment- Remediation"
$Global:logLevel = "INFO"

Function Write-Log {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Level = "INFO",  # Set default value to "INFO"
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    # Validate outside of the param block so it can still be logged if the level paramater is wrong
    if ($PSBoundParameters.ContainsKey('Level')) {
        # Validate against the specified values
        if ($Level -notin ("DEBUG", "INFO", "WARN", "ERROR")) {
            $errorMessage = "$Level is an invalid value for Level parameter. Valid values are DEBUG, INFO, WARN, ERROR."
            Write-Error  $errorMessage
            $Message = "$errorMessage - $Message"
            $Level = "WARN"
        }
    }

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
            $Global:orgFolder = "$env:ProgramData\$orgName"
        }
        else {
            $Global:orgFolder = "$Home\AppData\Roaming\$orgName"
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
            else {
                # Check log file size and truncate if necessary
                $logFileInfo = Get-Item $logFile
                if ($logFileInfo.Length / 1MB -gt $maxLogSizeMB) {
                    $streamWriter = New-Object System.IO.StreamWriter($logFile, $false)
                    $streamWriter.Write("")
                    $streamWriter.Close()
                    Write-Log -Level "INFO" -Message "Log file truncated due to exceeding maximum size."
                }
            }
        }
        catch {
            Write-Error "Failed to create log directory or file: $_"
        }

        # Set log date stamp
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp [$Level] $Message"
        $streamWriter = New-Object System.IO.StreamWriter($logFile, $true)
        $streamWriter.WriteLine($LogEntry)
        $streamWriter.Close()
    }
}

######################
# Main script
######################

Write-Log -Message "Starting $scriptName"

######################
# Initialize variables
######################

$orgFolder = Join-Path $env:ProgramData $orgName
$shortcutFolder = Join-Path $orgFolder "Shortcuts"
$remediationFilePath = Join-Path $shortcutFolder "remediation.json"
$jsonData = Get-Content $remediationFilePath -Raw | ConvertFrom-Json

######################
# Remediation
######################

Write-Log -Message "Remediating shortcuts"

# Loop through each shortcut in the JSON file and copy the file to the destination
foreach ($shortcut in $jsonData.create) {
    Write-Log -Message "Copy Icon: $($shortcut.path)"
    Write-Log -Message "Destination: $($shortcut.destination)"

    # Check if destination path exists and create it if it doesn't
    if (!(Test-Path $shortcut.destination)) {
        New-Item -ItemType Directory -Path $shortcut.destination -Force
    }

    # Copy the item
    Copy-Item -Path $shortcut.path -Destination $shortcut.destination -Force
    }

foreach ($shortcut in $jsonData.delete) {
    Write-Log -Message "Delete $shortcut"
    Remove-Item -Path $shortcut -Force
}

Write-Log -Message "Finished $scriptName"
