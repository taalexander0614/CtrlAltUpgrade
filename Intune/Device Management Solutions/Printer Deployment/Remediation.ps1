<#
.SYNOPSIS
    This script automates the management of printers on multiple computers by adding or removing printers based on a predefined JSON configuration file.

.DESCRIPTION
    The script starts by logging its initiation. It then defines necessary variables including the organization folder, printer folder, and the path to the printer remediation JSON file. 
    Next, it retrieves the JSON content from the printer remediation file and processes each printer entry. For each printer, it performs either an addition or removal action based on the specified action in the JSON content. 
    If the action is to add a printer, it installs the printer on the system. If the action is to remove a printer, it first attempts removal by the printer path. If that fails, it tries removing the printer by its IP address. If no IP address is provided, it logs a warning. 
    The script logs any warnings for invalid actions or the absence of an IP address. After processing all printers, it removes the printer remediation file and exits the script.

.PARAMETER orgName
    Specifies the name of the organization.

.PARAMETER scriptName
    Specifies the name of the script.

.PARAMETER logLevel
    Specifies the logging level for the script. Valid values are DEBUG, INFO, WARN, and ERROR. The default value is INFO.

.NOTES
    - This script assumes the existence of a printer remediation JSON file containing the necessary printer information for management.
    - It is essential to ensure that the script is executed with appropriate permissions to add or remove printers.
    - Ensure the JSON file is correctly formatted with valid printer entries and actions.
    - The script employs logging to track its execution, providing insight into the actions taken and any encountered warnings or errors.
    - The logging function will create a log file in the organization's ProgramData or user's AppData\Roaming directory, depending on the context in which the script is executed.
    - Before executing the script in a production environment, thoroughly test it in a controlled setting to verify its functionality and ensure it meets organizational requirements.
#>

$Global:orgName = 'CtrlAltUpgrade'
$Global:scriptName = "Printer Management - Remediation"
$Global:logLevel = "INFO"

Function Write-Log {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Level = "INFO",  # Set default value to "INFO"
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [int]$maxLogSizeMB = 10
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

####################
# Start Script
####################

Write-Log -Message "Starting $scriptName"

####################
# Variables
####################

$orgFolder = "$env:ProgramData\$orgName"
$printerFolder = Join-Path -Path $orgFolder -ChildPath "$orgName\Printer Management"
$printerRemediationFile = Join-Path -Path $printerFolder -ChildPath "printerRemediation.json"

####################
# Main Logic
####################

# Get remediation JSON content
$jsonContent = Get-Content -Path $printerRemediationFile -Raw | ConvertFrom-Json

# Iterate through each computer in the JSON content
foreach ($printer in $jsonContent) {
    Write-Log -Message "Processing printer $($printer.PrinterName) - $($printer.Action)"

    if ($printer.Action -eq "Add") {
        # Install Printer on the system
        Write-Log -Message "Installing $($printer.PrinterName)"
        Write-Output "Installing $($printer.PrinterName)"
        Add-Printer -ConnectionName $printer.PrinterPath
    }
    elseif ($printer.Action -eq "Remove") {
        # Remove printer from the system
        Write-Log -Message "Removing $($printer.PrinterName)"
        Write-Output "Removing $($printer.PrinterName)"
        
        # If removing by PrinterPath fails, try removing by IPAddress
        if (Get-Printer -Name $printer.PrinterPath -ErrorAction SilentlyContinue) {
            Remove-Printer -Name $printer.PrinterPath -ErrorAction SilentlyContinue
        }
        else {
            if ($printer.IpAddress) {
                # Get the printer object by IP Address and remove it
                $printerObject = Get-Printer | Where-Object {$_.PortName -eq $printer.IpAddress} | Select-Object -First 1
                if ($printerObject) {
                    Remove-Printer -InputObject $printerObject -ErrorAction SilentlyContinue
                }
            }
            else {
                Write-Log -Level "WARN" -Message "Unable to remove printer $($printer.PrinterName). No IP Address provided."
            }
        }

        
    }    
    else {
        Write-Log -Level "WARN" -Message "Invalid action specified for printer $($printer.PrinterName). Valid values are 'Add' and 'Remove'."
    }
}

# Remove the printer remediation file and exit script
Remove-Item -Path $printerRemediationFile -Force
Write-Log -Message "All printers installed/removed. Exiting..."
exit
