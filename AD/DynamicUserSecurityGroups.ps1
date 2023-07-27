<#
.SYNOPSIS
This script updates an Active Directory security group based on inclusion and exclusion rules.

.DESCRIPTION
This script is designed to update an existing Active Directory security group, ensuring that it contains only non-disabled users matching the inclusion rules while excluding users based on exclusion rules. The script first retrieves all users from the AD database that match the specified inclusion rules (e.g., employeeType=Student). It then fetches the existing members of the specified security group.

The script iterates through the list of matching users and adds them to the security group if they are not already members. Additionally, it removes users from the group if they no longer meet the inclusion criteria or match any exclusion criteria.

The script also logs its activities to a log file to provide visibility into changes made to the group.

.NOTES
- Requires the Active Directory module for PowerShell.
- This script should be used with caution and tested in a controlled environment before running in production.
- Always verify the accuracy of inclusion and exclusion rules before execution.

.PARAMETER groupName
The name of the security group to be updated.

.PARAMETER includeAttributes
A hashtable of attributes and their values to include users in the group.

.PARAMETER excludeAttributes
A hashtable of attributes and their values to exclude users from the group.

.OUTPUTS
The script generates a log using the Write-Log function.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Define the name of the security group you want to update
$groupName = "GroupName"

# Define attributes to use as inclusion rules (e.g., employeeType, department, etc.)
$includeAttributes = @{
    "employeeType" = "Student"
}

# Define attributes to use as exclusion rules (e.g., userAccountControl, etc.)
$excludeAttributes = @{
    "userAccountControl" = 514  # 514 represents a disabled account
}

# Org specific info and script name which is used for the log file
$Global:org = "ORG"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR
$Global:scriptName = "AD Dynamic Group - $groupName"

# Function to log messages
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

Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# Get all users matching the inclusion rules
$users = Get-ADUser -Filter {Enabled -eq $true} -Properties $includeAttributes.Keys |
         Where-Object { $user = $_; $includeAttributes.GetEnumerator() | ForEach-Object { $user.$($_.Key) -eq $_.Value } }
Write-Log -Level "INFO" -Message "Found $($users.Count) users matching inclusion rules."

# Get the existing members of the security group using Get-ADGroup
$group = Get-ADGroup -Identity $groupName -Properties Members
$existingMembers = $group.Members | Where-Object { $_.objectClass -eq "user" }
Write-Log -Level "INFO" -Message "Found $($existingMembers.Count) existing members of group $($groupName)."

# Add users who are not already members of the group and meet inclusion rules
foreach ($user in $users) {
    if (-not ($existingMembers.SamAccountName -contains $user.SamAccountName)) {
        Add-ADGroupMember -Identity $groupName -Members $user
        Write-Log -Level "INFO" -Message "Added user $($user.SamAccountName) to group $($groupName)."
        Write-Host "Added user $($user.SamAccountName) to group $($groupName)."
    }
}

# Remove users who are no longer non-disabled or don't meet inclusion rules
foreach ($member in $existingMembers) {
    $user = Get-ADUser $member.SamAccountName
    $exclude = $false
    foreach ($rule in $excludeAttributes.GetEnumerator()) {
        if ($user.$($rule.Key) -eq $rule.Value) {
            $exclude = $true
            break
        }
    }
    if (-not $exclude) {
        $inclusionCheck = $true
        foreach ($rule in $includeAttributes.GetEnumerator()) {
            if ($user.$($rule.Key) -ne $rule.Value) {
                $inclusionCheck = $false
                break
            }
        }
        if (-not $inclusionCheck) {
            $exclude = $true
        }
    }

    if ($exclude) {
        Remove-ADGroupMember -Identity $groupName -Members $user -Confirm:$false
        Write-Log -Level "INFO" -Message "Removed user $($user.SamAccountName) from group $($groupName)."
        Write-Host "Removed user $($user.SamAccountName) from group $($groupName)."
    }
}

$membershipCount = ((Get-ADGroup "$groupName" -Properties member).member).count
Write-Log -Level "INFO" -Message "Group $($groupName) now has $($membershipCount) members."

Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"