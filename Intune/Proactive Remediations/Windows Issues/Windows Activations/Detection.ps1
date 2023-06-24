<#
.SYNOPSIS
This PowerShell script checks if Windows is activated on the device and also checks the Windows version.

.DESCRIPTION
It will always return the Windows version, removing "Microsoft" if it is the first word of the string. 
If Windows is activated, it will check the version. 
If the version is not Home, it will display "Installed" and exit with status 0. 
If the version is Home, it will display "Home version" and also exit with status 0. 
If Windows is not activated, it will display the meaning of the activation status and exit with status 1.

.INPUTS
None

.OUTPUTS
The script outputs information about the activation status and version of Windows.
It will output a detection code based on the activation status and Windows version.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Get the activation status from the SoftwareLicensingProduct class
$activationStatus = (Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object {$_.PartialProductKey -and $_.Name -like "*Windows*"}).LicenseStatus

# Get the Windows version and remove "Microsoft " from the start of the string if it exists
$windowsVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
$windowsVersion = $windowsVersion.TrimStart("Microsoft ")

# Compare the activation status with the possible values
# 0: Unlicensed
# 1: Licensed
# 2: Out-of-box grace period
# 3: Out-of-tolerance grace period
# 4: Non-genuine grace period
# 5: Notification
# 6: Extended grace

if ($activationStatus -eq 1) {
    # Windows is activated
    if ($windowsVersion -like "*Home*") {
        # It's a Home version
        Write-Output $windowsVersion
        Exit 1
    } 
    else {
        # It's not a Home version
        Write-Output $windowsVersion
        Exit 0
    }
    
} 
else {
    # Windows is not activated
    switch ($activationStatus) {
        0 { Write-Output "Unlicensed" }
        2 { Write-Output "Out-of-box grace period" }
        3 { Write-Output "Out-of-tolerance grace period" }
        4 { Write-Output "Non-genuine grace period" }
        5 { Write-Output "Notification" }
        6 { Write-Output "Extended grace" }
        default { Write-Output "Unknown activation status" }
    }
    Exit 1
}