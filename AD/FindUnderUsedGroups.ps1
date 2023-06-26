<#
.SYNOPSIS
This script just checks all the groups in AD to see which ones are probably not being utilized

.DESCRIPTION
This script is just checking the number of objects in every AD security group and outputing a grid view of them.
One list will be all the groups with no objects in them and the other will be ones with less than the number you set.
Once you have the lists, you can look through and decide if any of them aren't needed anymore.

.NOTES
This is not something that should be turned into some automated cleanup script, it is just to help you see if there are any to clean up.
Requires the Active Directory module for PowerShell.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Number of ADObjects to determine $underUsedGroups
$objectCount = "3"

# Get all ADGroups in the domain
$allGroups = Get-ADGroup -Filter *

# Loop through each ADGroup and see if it contains 0 or less than 3 ADObjects
$EmptyGroups = @()
$UnderUsedGroups = @()
foreach ($group in $allGroups) {
    $GroupCount = (Get-ADGroup $group -Properties *).Member.Count
    if ($GroupCount -lt $objectCount -and $GroupCount -ne 0) {
        $UnderUsedGroups += $group
    }
    if ($GroupCount -eq 0) {
        $EmptyGroups += $group
    }
}
# Output the underused OUs
$EmptyGroups | Select-Object @{Name="GroupName"; Expression={$_}} | Out-GridView
$UnderUsedGroups | Select-Object @{Name="GroupName"; Expression={$_}} | Out-GridView

