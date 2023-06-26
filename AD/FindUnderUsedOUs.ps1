<#
.SYNOPSIS
This script just checks all the OU's in AD to see which ones are probably not being utilized

.DESCRIPTION
This script is just checking every OU to see if it has ADObjects or child OU's and outputing a grid view of the underused.
It will cycle through every OU and create an array of all the OU's which contain no child OU's.
It will then cycle through all the childless OU's and output a list of the ones with less ADObjects than the number you set.
Once you have the list, you can look through and decide if any of them aren't needed anymore.

.NOTES
This is not something that should be turned into some automated cleanup script, it is just to help you see if there are any to clean up.
Requires the Active Directory module for PowerShell.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Number of ADObjects to determine $underUsedGroups
$objectCount = "5"

# Get all OUs in the domain
$allOUs = Get-ADOrganizationalUnit -Filter *

# Loop through each OU and check if it contains any child OUs
$UnderUsedOUs = @()
foreach ($ou in $allOUs) {
    $childOUs = Get-ADObject -Filter * -SearchBase $ou | Where-Object { ($_.distinguishedname -ne $ou.distinguishedname) -AND ($_.objectclass -eq "organizationalunit")}
    if ($childOUs.Count -eq 0) {
        $OUObjects = Get-ADobject -Filter * -SearchBase $ou
        if ($OUObjects.Count -lt $objectCount) {
            $UnderUsedOUs += $ou
        }
    }
}
# Output the underused OUs
$UnderUsedOUs | Select-Object @{Name="OUName"; Expression={$_.DistinguishedName}} | Out-GridView