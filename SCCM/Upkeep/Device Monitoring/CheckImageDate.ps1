<#
.SYNOPSIS
Checks for devices that have not been imaged within a set number of years.

.DESCRIPTION
This script is designed to be used as an Intune Proactive Remediation script for Co-Managed devices or run through SCCM. 
It checks the age of a log file (SMSTS log) and returns the creation date. 
By comparing the creation date against a specified number of years, it identifies devices that have not been imaged within that timeframe. 
This allows organizations to easily determine if any devices need to be reimaged.

.INPUTS
None

.OUTPUTS
The script outputs the creation date of the SMSTS log and exits with status 1 if the creation date is older than the specified age.

.NOTES
- Tested on Windows 10 with PowerShell 5.1.
- This script can be used in conjunction with Intune Proactive Remediation for Co-Managed devices or run through SCCM.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Set the age (in years) to compare the log file's creation date against
$age = "4"

# Specify the file path of the log file
$filePath = "C:\Windows\CCM\Logs\smsts.log"

# Check if the log file exists
if (Test-Path $filePath) {
    # Get information about the file
    $file = Get-ChildItem $filePath
    $creationDate = $file.CreationTime.Date

    # Calculate the maximum age based on the specified years
    $maxAge = (Get-Date).AddYears(-$age).Date

    # Compare the creation date with the maximum age
    if ($creationDate -lt $maxAge) {
        # If the creation date is older than the maximum age, exit with status 1
        Write-Output $creationDate
        Exit 1
    }
    else {
        # If the creation date is within the maximum age, exit with status 0
        Write-Output $creationDate
        Exit 0
    }
}
else {
    # If the log file does not exist, output "No Date" and exit with status 0
    Write-Output "No Date"
    Exit 0
}

