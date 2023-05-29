<#
This is a detection script originally made as an Intune Proactive Remediation remove any user folders that do not have a corresponding user profile in the Windows registry. 
It excludes the "Public", "Cleanup", and "visio" folders from the check (I ran a script to pull all unique User folder names and "visio" was apparently something used in our environment). 
If it finds any such folders, it outputs their names and exits with a status code of 1. 
If it does not find any such folders, it exits with a status code of 0.
#>

# Check if the cleanup folder exists so we can have a list of devices to address later
# "Test-Path" is used to check if the specified file/folder exists.
if(test-path "C:\Users\Cleanup"){
    write-output "Cleanup folder exists"
}

# Pull all profiles from the registry
# An empty array $remainingProfileNames is declared.
$remainingProfileNames = @()

# The "Get-ChildItem" cmdlet is used to retrieve the profiles from the Windows registry. 
$remainingprofiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue

# Loop through all the remaining profiles
foreach ($remainingprofile in $remainingprofiles) {
    # For each profile, get the ImagePath which is the path of the user's profile directory.
    $remainingprofileImagePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($remainingprofile.PSChildName)" -Name ProfileImagePath | Select-Object -ExpandProperty ProfileImagePath

    # Replace the "C:\Users\" part of the path with an empty string to get the username, and append it to the $remainingProfileNames array.
    $remainingprofilenames += $remainingprofileImagePath -replace "C:\\Users\\", ""
}

# Pull all folders in C:\Users and compare with existing profiles (excluding Public, Cleanup and visio)
# Get a list of all the directories in C:\Users.
$folders = Get-ChildItem -Path "C:\Users" -Directory

# An empty array $nonMatchingFolders is declared.
$nonMatchingFolders = @()

# Loop through all the folders
foreach ($folder in $folders) {
    # If a folder's name does not exist in the $remainingProfileNames array and is not one of the following: "Public", "Cleanup", "visio", add it to the $nonMatchingFolders array.
    if ($remainingprofilenames -notcontains $folder.Name -and $folder.Name -notin "Public", "Cleanup", "visio") {
        $nonMatchingFolders += $folder
    }
}

# If folders are found that do not match Exit 1, otherwise Exit 0
# If there are any non-matching folders...
if (![string]::IsNullOrEmpty($nonMatchingFolders)) {  
    # Loop through all the non-matching folders and write their names to the output.
    foreach ($nonMatchingFolder in $nonMatchingFolders) {
        Write-Output "$nonMatchingFolder"
    }
    # Exit the script with a non-zero status code (1) to indicate that non-matching folders were found.
    Exit 1
}

# If there are no non-matching folders...
if ([string]::IsNullOrEmpty($nonMatchingFolders)) {
    # Exit the script with a zero status code (0) to indicate that no non-matching folders were found.
    Exit 0
}
