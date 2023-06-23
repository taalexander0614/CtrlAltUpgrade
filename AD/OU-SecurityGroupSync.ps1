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

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>


# Define the Security Group
$ShadowGroup = "CN=Office 365 Device License,OU=Schools,DC=ORG,DC=Local"

# Define the target: 'User' or 'Computer'
$target = 'Computer'

# Define all the OU's that we want in the security group
$OUs = @()
$baseOUs = @(
    'OU=Computer Labs,OU=Workstations,OU=School Name,OU=High Schools,OU=Schools,DC=ORG,DC=local',
    'OU=Computer Labs,OU=Workstations,OU=School Name,OU=High Schools,OU=Schools,DC=ORG,DC=local'
    # Add additional OU's here
)

foreach ($baseOU in $baseOUs) {
    $OUs += Get-ADOrganizationalUnit -Filter 'Name -like "*"' -SearchBase $baseOU
}

# Remove any members of security group which are no longer in the OUs we targeted
$groupMembers = Get-ADGroupMember -Identity $ShadowGroup

foreach ($member in $groupMembers) {
    $memberInOU = $false
    foreach ($ou in $OUs) {
        if ($member.distinguishedName -like "*$($ou.distinguishedName)*") {
            $memberInOU = $true
            break
        }
    }
    if (-not $memberInOU) {
        Remove-ADPrincipalGroupMembership -Identity $member -MemberOf $ShadowGroup -Confirm:$false
    }
}

# Loop through all OUs individually
foreach ($ou in $OUs) {
    if ($target -eq 'User') {
        # Get all users within the current OU that are not already a member of the ShadowGroup
        $targetsToAdd = Get-ADUser -SearchBase $ou -SearchScope OneLevel -LDAPFilter "(!memberOf=$ShadowGroup)"
    } else {
        # Get all computers within the current OU that are not already a member of the ShadowGroup
        $targetsToAdd = Get-ADComputer -SearchBase $ou -SearchScope OneLevel -LDAPFilter "(!memberOf=$ShadowGroup)"
    }

    # For each of those targets
    foreach ($targetToAdd in $targetsToAdd) {
        # Add the target to the ShadowGroup
        Add-ADPrincipalGroupMembership -Identity $targetToAdd -MemberOf $ShadowGroup
        Write-Output "Added $targetToAdd to $ShadowGroup"
    }
}


