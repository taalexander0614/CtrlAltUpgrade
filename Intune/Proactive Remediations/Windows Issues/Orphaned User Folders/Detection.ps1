<#
.SYNOPSIS
This is a detection script originally made as an Intune Proactive Remediation remove orphaned user folders. 

.DESCRIPTION
This script looks for folders in C:\Users that were left over when a user account was deleted. 
It identifies orphaned folders by comparing the folders in C:\Users to the list of user profiles in the Windows Registry. 
If the script finds any folders, it outputs their names and exits with a exit code of 1.
If it does not find any such folders, it exits with a exit code of 0. 

.NOTES
When checking C:\Users, the script ignores the Public folder and the Cleanup folder the Remediation script creates.
I would recommend running the detection script for a while so you can export the PreRemediationDetection Output and see if any folder names stand out.
After running the remediation you could uncomment the test-path for the cleanup folder and see what devices you may want to check out

This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Check if the cleanup folder exists so we can have a list of devices to address later
#if(test-path "C:\Users\Cleanup"){
#    write-output "Cleanup folder exists"
#}

# Pull all profiles from the registry
$remainingProfileNames = @()
$remainingprofiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue

# Loop through all the remaining profiles
foreach ($remainingprofile in $remainingprofiles) {
    # For each profile, get the ImagePath which is the path of the user's profile directory.
    $remainingprofileImagePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($remainingprofile.PSChildName)" -Name ProfileImagePath | Select-Object -ExpandProperty ProfileImagePath

    # Replace the "C:\Users\" part of the path with an empty string to get the username, and append it to the $remainingProfileNames array.
    $remainingprofilenames += $remainingprofileImagePath -replace "C:\\Users\\", ""
}

# Pull all folders in C:\Users and compare with existing profiles (excluding Public and Cleanup)
$folders = Get-ChildItem -Path "C:\Users" -Directory
$nonMatchingFolders = @()

# Loop through all the folders
foreach ($folder in $folders) {
    # If a folder's name does not exist in the $remainingProfileNames array and is not one of the following: "Public" or "Cleanup", add it to the $nonMatchingFolders array.
    if ($remainingprofilenames -notcontains $folder.Name -and $folder.Name -notin "Public", "Cleanup", "visio") {
        $nonMatchingFolders += $folder
    }
}

# If folders are found that do not match Exit 1, otherwise Exit 0
if (![string]::IsNullOrEmpty($nonMatchingFolders)) {  
    # Loop through all the non-matching folders and write their names to the output.
    foreach ($nonMatchingFolder in $nonMatchingFolders) {
        Write-Output "$nonMatchingFolder"
    }
    Exit 1
}

# If there are no non-matching folders...
if ([string]::IsNullOrEmpty($nonMatchingFolders)) {
    Exit 0
}
