# This script checks if Windows is activated on the device
# It returns "Activated" if Windows is activated, and "Not Activated" otherwise

# Get the activation status from the SoftwareLicensingProduct class
$activationStatus = (Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object {$_.PartialProductKey -and $_.Name -like "*Windows*"}).LicenseStatus

# Compare the activation status with the possible values
# 0: Unlicensed
# 1: Licensed
# 2: Out-of-box grace period
# 3: Out-of-tolerance grace period
# 4: Non-genuine grace period
# 5: Notification
# 6: Extended grace

if ($activationStatus -eq 1) {
    # Get the current Windows edition
    $edition = (Get-WmiObject -query 'select * from Win32_OperatingSystem').Caption

    # Check if the edition is not Pro or Pro Education
    if ($edition -notmatch 'Education') {
        Write-Host "Test"
    }
} 
else {
    # Windows is not activated
    Write-Host "Not Activated"
    Exit 1
}