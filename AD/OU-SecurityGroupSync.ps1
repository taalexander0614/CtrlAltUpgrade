<#
.SYNOPSIS
This script OU's to a security group in an Active Directory (AD) environment. The script targets specific Organizational Units (OUs) and syncs either the computer or user objects in those OUs with the membership of the security group based on the choice at the start of the script.

.DESCRIPTION
The script first prompts the user to specify whether to target users or computers. It then identifies a list of OUs specified in the script. 

The script performs two main actions:

1. The script removes any members of the security group which are no longer in the targeted OUs. This is done by examining the 'distinguishedName' of each group member and checking whether it matches the pattern of the chosen targets (users or computers). Any members that do not match this pattern are removed from the security group.

2. The script loops through each OU individually and adds the chosen targets (either users or computers) in them to the security group. This is done by examining each object in the OU and checking whether it is already a member of the security group. Any objects that are not already members of the security group are added to the group.

.INPUTS
The script prompts the user to input a choice at the start (either 'users' or 'computers').

.OUTPUTS
The script outputs a message for each object added to the security group.

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$Global:org = "ORG"
$Global:scriptName = "OU-SecurityGroupSync"
# Define the Security Group
$securityGroup = "CN=Office 365 Device License,OU=Schools,DC=ORG,DC=Local"
# Define the target: 'User' or 'Computer'
$target = 'Computer'
# Define all the OU's that we want in the security group
$baseOUs = @(
    'OU=Computer Labs,OU=Workstations,OU=School Name,OU=High Schools,OU=Schools,DC=ORG,DC=local',
    'OU=Computer Labs,OU=Workstations,OU=School Name,OU=High Schools,OU=Schools,DC=ORG,DC=local'
    # Add additional OU's here
)

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
        Write-Log -Level "INFO" -Message "Failed to create log directory or file: $_"
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
Write-Log -Level "INFO" -Message "Target: $target"
Write-Log -Level "INFO" -Message "Security Group: $securityGroup"
Write-Log -Level "INFO" -Message "Current OUs: $baseOUs"

$OUs = @()
foreach ($baseOU in $baseOUs) {
    Write-Log -Level "INFO" -Message "Getting OUs in $baseOU"
    $OUs += Get-ADOrganizationalUnit -Filter 'Name -like "*"' -SearchBase $baseOU
}
Write-Log -Level "INFO" -Message "OUs to target: $OUs"

# Remove any members of security group which are no longer in the OUs we targeted
$groupMembers = Get-ADGroupMember -Identity $securityGroup

foreach ($member in $groupMembers) {
    $memberInOU = $false
    foreach ($ou in $OUs) {
        if ($member.distinguishedName -like "*$($ou.distinguishedName)*") {
            $memberInOU = $true
            break
        }
    }
    if (-not $memberInOU) {
        Write-Log -Level "INFO" -Message "Removing $member from $securityGroup"
        Remove-ADPrincipalGroupMembership -Identity $member -MemberOf $securityGroup -Confirm:$false
    }
}

# Loop through all OUs individually
foreach ($ou in $OUs) {
    if ($target -eq 'User') {
        # Get all users within the current OU that are not already a member of the ShadowGroup
        Write-Log -Level "INFO" -Message "Getting users in $ou"
        $targetsToAdd = Get-ADUser -SearchBase $ou -SearchScope OneLevel -LDAPFilter "(!memberOf=$securityGroup)"
    } else {
        # Get all computers within the current OU that are not already a member of the ShadowGroup
        Write-Log -Level "INFO" -Message "Getting computers in $ou"
        $targetsToAdd = Get-ADComputer -SearchBase $ou -SearchScope OneLevel -LDAPFilter "(!memberOf=$securityGroup)"
    }

    # For each of those targets
    foreach ($targetToAdd in $targetsToAdd) {
        # Add the target to the ShadowGroup
        Add-ADPrincipalGroupMembership -Identity $targetToAdd -MemberOf $securityGroup
        Write-Log -Level "INFO" -Message "Added $targetToAdd to $securityGroup"
    }
}

Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"


