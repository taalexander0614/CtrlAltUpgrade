<#
.SYNOPSIS
    This script is used to detect printers that should be installed or removed from a computer based on the computer's group membership and the printer deployment configuration.

.DESCRIPTION
    This script is used to detect printers that should be installed or removed from a computer based on the computer's group membership and the printer deployment configuration. 
    The script retrieves the computer's group membership from Microsoft Graph and compares it to the printer deployment configuration. 
    If a printer is assigned to a group that the computer is a member of, the script checks if the printer is already installed. 
    If the printer is not installed, the script adds the printer to a list of printers to install. 
    If the printer is installed, the script moves on to the next printer. 
    If the printer is not assigned to the computer, the script checks if the printer is installed. 
    If the printer is installed, the script adds the printer to a list of printers to remove. 
    If the printer is not installed, the script moves on to the next printer. 
    The script writes the list of printers to install or remove to a JSON file and exits with a status code of 1 if there are printers to manage, or 0 if there are no printers to manage.

.PARAMETER orgName
    Specifies the name of the organization.

.PARAMETER scriptName
    Specifies the name of the script.

.PARAMETER logLevel
    Specifies the logging level for the script. Valid values are DEBUG, INFO, WARN, and ERROR. The default value is INFO.

.PARAMETER jsonUrl
    Specifies the URL of the printer deployment configuration JSON file.

.PARAMETER tenantId
    Specifies the tenant ID for the Microsoft Graph API.

.PARAMETER appID
    Specifies the application ID for the Microsoft Graph API.

.PARAMETER appSecret
    Specifies the application secret for the Microsoft Graph API.

.NOTES
    - This script assumes the existence of a printer deployment configuration JSON file containing the necessary printer information for management.
    - It is essential to ensure that the script is executed with appropriate permissions to add or remove printers.
    - Ensure the JSON file is correctly formatted with valid printer entries and actions.
    - The script employs logging to track its execution, providing insight into the actions taken and any encountered warnings or errors.
    - The logging function will create a log file in the organization's ProgramData or user's AppData\Roaming directory, depending on the context in which the script is executed.
    - Before executing the script in a production environment, thoroughly test it in a controlled setting to verify its functionality and ensure it meets organizational requirements.
#>

$Global:orgName = 'CtrlAltUpgrade'
$Global:scriptName = "Printer Management - Detection"
$Global:logLevel = "INFO"
$jsonUrl = "<YourJsonUrl>"
$tenantId = '<YourTenantID>'
$appID = '<YourAppID>'
$appSecret = '<YourAppSecret>'


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

function Get-AccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$tenantID,
        [Parameter(Mandatory = $true)]
        [string]$appID,
        [Parameter(Mandatory = $true)]
        [string]$appSecret
    )
    Write-Log -Message "Obtaining Auth Token"
    $accessTokenUrl = "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token"
    $tokenRequestBody = @{
        "grant_type"    = "client_credentials"
        "scope"         = "https://graph.microsoft.com/.default"
        "client_id"     = $appID
        "client_secret" = $appSecret
    }   
    Try {
        Write-Log -Level "DEBUG" -Message "Calling $accessTokenUrl with body: $tokenRequestBody"
        $tokenResponse = Invoke-RestMethod -Uri $accessTokenUrl -Method POST -Body $tokenRequestBody
        Write-Log -Level "DEBUG" -Message "Response: $tokenResponse"
    }
    Catch {
        Write-Log -Message "Failed to obtain Auth Token: $_"
    }
    return $tokenResponse.access_token
}

function Invoke-GetComputerObject {
    param (
        [string]$accessToken
    )
    
    # Retrieve computer ID from Microsoft Graph
    $url = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$ENV:ComputerName'"
    $headers = @{
        Authorization    = "Bearer $accessToken"
        ConsistencyLevel = "eventual"
    }
    
    try {
        Write-Log -Level "DEBUG" -Message "Retrieving device ID from Microsoft Graph using URL: $url"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        Write-Log -Level "DEBUG" -Message "Response: $($response.value)"
        return $response
    } catch {
        Write-Output "Error retrieving device ID: $_"
    }
}    

function Invoke-GetComputerGroups {
    param (
        [string]$accessToken,
        [string]$azureId
    )

    # Retrieve group members from Microsoft Graph
    $getGroupMembersUrl = "https://graph.microsoft.com/v1.0/devices/$azureId/memberOf"
    $headers = @{
        Authorization    = "Bearer $accessToken"
        ConsistencyLevel = "eventual"
    }
    Write-Log -Level "DEBUG" -Message "Retrieving group members from Microsoft Graph using URL: $getGroupMembersUrl"
    $deviceGroups = Invoke-RestMethod -Uri $getGroupMembersUrl -Headers $headers -Method GET -ContentType "application/json"
    Write-Log -Level "DEBUG" -Message "Response: $($deviceGroups.value)"

    return $deviceGroups
}

####################
# Start Script
####################

Write-Log -Message "Starting $scriptName"

####################
# Variables
####################

$orgFolder = "$env:ProgramData\$orgName"
$deviceInfoFolder = Join-Path -Path $orgFolder -ChildPath "$orgName\Device Information"
$groupsFile = Join-Path -Path $deviceInfoFolder -ChildPath "groups.json"
$printerFolder = Join-Path -Path $orgFolder -ChildPath "$orgName\Printer Management"
$printerRemediationFile = Join-Path -Path $printerFolder -ChildPath "printerRemediation.json"
$printerDeploymentFile = Join-Path -Path $printerFolder -ChildPath "printerDeployment.json"

####################
# Upkeep
####################

Write-Log -Level "DEBUG" -Message "Checking for existing printer remediation file"
if (Test-Path $printerRemediationFile) {
    Write-Log -Message "Removing existing printer remediation file"
    Remove-Item -Path $printerRemediationFile -Force
}
Write-Log -Level "DEBUG" -Message "Checking for organization folder"
if (!(Test-Path $printerFolder)) {
    Write-Log -Message "Creating organization folder: $printerFolder"
    New-Item -Path $printerFolder -ItemType Directory -Force
}

####################
# Check for Updates
####################

# Get MSGraph Access Token
Write-Log -Level "DEBUG" -Message "Calling function to get MSGraph Access Token"
$accessToken = Get-AccessToken -tenantID $tenantID -appID $appID -appSecret $appSecret
Write-Log -Level "DEBUG" -Message "Access Token: $accessToken"

# Check last modified date for $groupsFile and download if older than 1 day
$updateGroups = $true
$updateDeployments = $true

Write-Log -Level "DEBUG" -Message "Checking for existing groups file"
if (Test-Path $groupsFile) {
    Write-Log -Level "DEBUG" -Message "Groups file exists. Checking last modified date."
    $lastModified = (Get-Item $groupsFile).LastWriteTime
    Write-Log -Level "DEBUG" -Message "Last modified date: $lastModified"
    $currentDate = Get-Date
    Write-Log -Level "DEBUG" -Message "Current date: $currentDate"
    $daysOld = ($currentDate - $lastModified).Days
    Write-Log -Level "DEBUG" -Message "Groups file is $daysOld days old."
    if ($daysOld -gt 1) {
        Write-Log -Message "Groups file is $daysOld days old. Downloading new file."
        Remove-Item -Path $groupsFile -Force
    }
    else {
        Write-Log -Level "DEBUG" -Message "Groups file is up to date."
        $updateGroups = $false
    }
}
Write-Log -Message "Checking for existing printer deployment file"
if (Test-Path $printerDeploymentFile) {
    Write-Log -Level "DEBUG" -Message "Printer deployment file exists. Checking last modified date using $jsonUrl"
    $lastmodifiedremote = (Invoke-RestMethod -Uri $jsonUrl -Method Head).LastModified
    Write-Log -Level "DEBUG" -Message "Remote last modified date: $lastmodifiedremote"
    $lastmodifiedlocal = (Get-Item $printerDeploymentFile).LastWriteTime
    Write-Log -Level "DEBUG" -Message "Local last modified date: $lastmodifiedlocal"
    if ($lastmodifiedremote -gt $lastmodifiedlocal) {
        Write-Log -Message "Remote file is newer than local file. Downloading new file."
        $updateDeployments = $true
    }
    else {
        Write-Log -Message "Printer deployment file is up to date."
        $updateDeployments = $false
    }
}

####################
# Update Files if Necessary 
####################

Write-Log -Level "DEBUG" -Message "Updating files if necessary."
if ($updateGroups) {
    Write-Log -Message "Downloading groups file"
    # Get computer object from MSGraph and groups
    Write-Log -Level "DEBUG" -Message "Calling function to get computer object"
    $computerObject = Invoke-GetComputerObject -accessToken $accessToken
    Write-Log -Level "DEBUG" -Message "Computer object: $($computerObject.value)"
    Write-Log -Level "DEBUG" -Message "Calling function to get computer groups"
    $computerGroups = Invoke-GetComputerGroups -accessToken $accessToken -azureId $computerObject.value.id
    Write-Log -Level "DEBUG" -Message "Computer groups: $($computerGroups.value)"
    Write-Log -Message "Writing groups to file"
    $groups = @()
    foreach ($group in $computerGroups.value) {
        Write-Log -Level "DEBUG" -Message "Adding group $($group.displayName) to groups file"
        $groupObject = [PSCustomObject]@{
            "id" = $group.id
            "name" = $group.displayName
        }
        $groups += $groupObject
    }
    Write-Log -Level "DEBUG" -Message "Outputting groups to file: $groupsFile"
    $groups | ConvertTo-Json | Out-File -FilePath $groupsFile -Force
}
if ($updateDeployments) {
    Write-Log -Message "Remote file is newer than local file. Downloading new file."
    Invoke-WebRequest -Uri $jsonUrl -OutFile $printerDeploymentFile
}

####################
# Get Necessary Data
####################

# Get all installed printers and set flags for remediation
Write-Log -Message "Collecting Printer Data"
$installedPrinters = Get-Printer | Select-Object -ExpandProperty Name
Write-Log -Level "DEBUG" -Message "Installed Printers: $($installedPrinters -join ', ')"
Write-Log -Message "Collecting Groups Data"
$deviceGroups = Get-Content -Path $groupsFile -Raw | ConvertFrom-Json
Write-Log -Level "DEBUG" -Message "Device Groups: $($deviceGroups.name -join ', ')"
Write-Log -Message "Collecting Deployment Data"
$jsonDeployments = Get-Content -Path $printerDeploymentFile -Raw | ConvertFrom-Json
Write-Log -Level "DEBUG" -Message "Printers: $($jsonDeployments.Printers.PrinterName -join ', ')"

####################
# Evaluate Printers
####################

$printers = @()
# Iterate through each computer in the JSON content
Write-Log -Message "Iterating through each printer in deployments json"
foreach ($printer in $jsonDeployments.Printers) {
    Write-Log -Level "DEBUG" -Message "Checking printer $($printer.PrinterName)"
    Write-Log -Level "DEBUG" -Message "Printer groups: $($printer.groups)"
    $assigned = $false
    if ($null -ne $printer.groups -and $printer.groups -ne "") {
        foreach ($group in $printer.groups) {
            Write-Log -Level "DEBUG" -Message "Checking if computer is a member of $($group.name)"
            if ($deviceGroups.id -contains $group.id) {
                Write-Log -Message "Computer is a member of $($group.name)"
                Write-Host "Computer is a member of $($group.name)"
                if ($installedPrinters -contains $printer.PrinterPath) {
                    Write-Log -Message "Printer '$($printer.PrinterPath)' already installed."
                    $assigned = $true
                }
                else {
                    Write-Log -Level "WARN" -Message "Printer '$($printer.PrinterPath)' not found."
                    # Create a custom object to store printer details and action
                    if ($printer.IpAddress) {
                        $ipAddress = $printer.IpAddress
                    }
                    else {
                        $ipAddress = $null
                    }
                    $printerToAdd = [PSCustomObject]@{
                        "PrinterName" = $printer.PrinterName
                        "IpAddress" = $ipAddress  # Add IP address if available
                        "PrinterPath" = $printer.PrinterPath
                        "Action" = "Add"
                    }
                    
                    # Add the printer to the list of printers to remove
                    $printers += $printerToAdd
                    $assigned = $true
                }
                break  # No need to continue checking groups if the computer is already a member
            }
        }
    }
    else {
        Write-Log -Level "DEBUG" -Message "No groups found for $($printer.PrinterName)"
    }
    # Remove printer if it is not assigned to the computer
    if ($installedPrinters -contains $printer.PrinterPath -and !$assigned) {
        Write-Log -Level "WARN" -Message "Should not have printer '$($printer.PrinterPath)'"
        Write-Host "Should not have printer '$($printer.PrinterPath)'"
        # Create a custom object to store printer details and action
        if ($printer.IpAddress) {
            $ipAddress = $printer.IpAddress
        }
        else {
            $ipAddress = $null
        }
        $printerToRemove = [PSCustomObject]@{
            "PrinterName" = $printer.PrinterName
            "IpAddress" = $ipAddress  # Add IP address if available
            "PrinterPath" = $printer.PrinterPath
            "Action" = "Remove"
        }
        
        # Add the printer to the list of printers to remove
        $printers += $printerToRemove
    }
}

if ($printers) {
    Write-Log -Message "Printers to manage: $($printers.PrinterName -join ', ')"
    Write-Output "Printers to manage: $($printers.PrinterName -join ', ')"
    $printers | ConvertTo-Json | Out-File -FilePath $printerRemediationFile -Force
    exit 1
}
else {
    exit 0
}
