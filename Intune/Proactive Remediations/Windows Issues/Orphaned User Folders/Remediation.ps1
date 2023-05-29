<#
This is a remediation script originally made as an Intune Proactive Remediation to clean up "orphaned" user folders on a Windows system. 
These folders may exist under C:\Users and are left over when a user account is deleted but their profile folder is not removed. 
The script identifies these folders by comparing the folders in C:\Users to the list of user profiles in the Windows Registry. 
If the script finds any folders that do not have a corresponding user profile, it attempts to delete them.
#>

# Set initial variables 
$ScriptName = "Orphaned User Folders"
$leftoverCleanup = "C:\Users\Cleanup"
$ORGFolder = "C:\Windows\ORG Resources"
$logFolder = "$ORGFolder\Logs"  
$logFile = "$ScriptName.log"

# Create necessary paths if they do not exist
If(!(test-path $ORGFolder)){new-item $ORGFolder -type directory -force | out-null}
If(!(test-path $logFolder)){new-item $logFolder -type directory -force | out-null}
$logPathDir = [System.IO.Path]::GetDirectoryName($logFolder)
if ((Test-Path -Path $logPathDir) -eq $false) {
  New-Item -ItemType Directory -Force -Path $logPathDir | Out-Null
}
if ((Test-Path -Path $logFolder) -eq $false) {
  New-Item -ItemType directory -Force -Path $logFolder | Out-Null
} 
$date = Get-Date
$logFile = $logFolder + "\" +  $logFile
Out-File $logFile -Append -InputObject "====================== $ScriptName ======================"
Out-File $logFile -Append -InputObject $date

# Check for any accounts found on system before running script
$startingProfileNames = @()
$profiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "S-1-5-21-*" }   
foreach ($profile in $profiles) {
    $profileImagePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($profile.PSChildName)" -Name ProfileImagePath | Select-Object -ExpandProperty ProfileImagePath
    $startingprofilenames += $profileImagePath -replace "C:\\Users\\", ""
}
Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") The accounts present on device: $startingProfileNames."

# Get all user profiles and compare with folders in C:\Users
Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Checking for orphaned folders."
$remainingProfileNames = @()
$remainingprofiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue  
foreach ($remainingprofile in $remainingprofiles) {
    $remainingprofileImagePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($remainingprofile.PSChildName)" -Name ProfileImagePath | Select-Object -ExpandProperty ProfileImagePath
    $remainingprofilenames += $remainingprofileImagePath -replace "C:\\Users\\", ""
}
$folders = Get-ChildItem -Path "C:\Users" -Directory

$nonMatchingFolders = @()
foreach ($folder in $folders) {
    if ($remainingprofilenames -notcontains $folder.Name -and $folder.Name -notin "Public", "Cleanup", "visio") {
        $nonMatchingFolders += $folder
    }
}
# Loop through each folder and attempt to delete          
if (![string]::IsNullOrEmpty($nonMatchingFolders)) { 
    Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Orphaned folders found: $nonMatchingFolders."
    Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Attempting to delete orphaned folders from C:\Users." 
    foreach ($nonMatchingFolder in $nonMatchingFolders) {
        Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Attempting to delete $($nonMatchingFolder.FullName)."
        Try {
            Remove-Item $nonMatchingFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Catch {
            Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to delete $($nonMatchingFolder.FullName)"
        }
        Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Checking if $($nonMatchingFolder.FullName) still exists."
# If folder was not deleted, assign ownership and full control access to the System account before recursively deleting the folder while silently continuing on error                    
        if (Test-Path $nonMatchingFolder.FullName -PathType Container) {
            Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") $($nonMatchingFolder.FullName) still exists, so attempting to take ownership."
            Try {
                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Attempting to take ownership of duplicate folder $nonMatchingFolder."
                $directoryPath = $nonMatchingFolder.FullName
                $Acl = Get-Acl $directoryPath
                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                $Acl.SetOwner($Ar.IdentityReference)
                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                $Acl.SetAccessRule($Ar)
                Set-Acl -Path $directoryPath -AclObject $Acl -Verbose 2>&1 | Tee-Object -FilePath $logFile -Append
            }
            Catch {
                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to take ownership of $($nonMatchingFolder.FullName) : $($_.Exception.Message)"
            }
            Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Attempting to delete $($nonMatchingFolder.FullName)."
            Try {
                Remove-Item $nonMatchingFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            Catch {
                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to delete $($nonMatchingFolder.FullName)"
            }
            Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Checking if $($nonMatchingFolder.FullName) still exists."
# Check to see if the folder still exists so a more thorough attempt at deletion can be made if needed
            if (Test-Path $nonMatchingFolder.FullName -PathType Container) {
                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") $($nonMatchingFolder.FullName) still exists, so proceeding to delete childitems."
# Put all remaining child files individually into an array and loop through to take the same attept to chenge permissions and delete                   
                $files = Get-ChildItem $nonMatchingFolder.FullName -File -Recurse -Force
                foreach ($file in $files) {
                    if (Test-Path $file.FullName) {
                        Try {
                            Remove-Item $file.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Catch {
                            Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to remove $folder child file $file"
                            Try { 
# Retrieve the Access Control List (ACL) for the directory
                                $directoryPath = $file.FullName
                                $Acl = Get-Acl $directoryPath
                                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                                $Acl.SetOwner($Ar.IdentityReference)
                                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                                $Acl.SetAccessRule($Ar)
                                Set-Acl -Path $directoryPath -AclObject $Acl -Verbose 2>&1 | Tee-Object -FilePath $logFile -Append
                                Remove-Item $file.FullName -Recurse -Force 
                            } 
                            Catch {  
                                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to modify permissions/delete of $nonMatchingFolder child file $($file.FullName) : $($_.Exception.Message)"
                            }
                        }
                    }   
                }
# Put all remaining child folders individually into an array and loop through to make the same attempt to chenge permissions and delete 
                $containers = Get-ChildItem $nonMatchingFolder.FullName -Directory -Recurse -Force
                foreach ($container in $containers) {
                    if (Test-Path $container.FullName) {
                        Try {
                            Remove-Item $container.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Catch {
                            Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to remove $nonMatchingFolder child folder $container"
                            Try { 
                                $directoryPath = $container.FullName
                                $Acl = Get-Acl $directoryPath
                                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                                $Acl.SetOwner($Ar.IdentityReference)
                                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                                $Acl.SetAccessRule($Ar)
                                Set-Acl -Path $directoryPath -AclObject $Acl -Verbose 2>&1 | Tee-Object -FilePath $logFile -Append
                                Remove-Item $container.FullName -Recurse -Force 
                            } 
                            Catch {  
                                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to modify permissions/delete $nonMatchingFolder child folder $($container.FullName) : $($_.Exception.Message)"
                            }
                        }
                    }                         
                }
                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Attempting to delete $($nonMatchingFolder.FullName) again after deleting childitems."
                Try {
                    Remove-Item $nonMatchingFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
                Catch {
                    Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to delete $($nonMatchingFolder.FullName)"
                }
                if (Test-Path $nonMatchingFolder.FullName -PathType Container) {
                    Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") $($nonMatchingFolder.FullName) still exists; attempting to move to $leftoverCleanup."
# If folder still exists, move to $destnationFolder to clean up C:\Users and potentially prevent more duplication 
                    Try {
                        Move-Item -Path $nonMatchingFolder.FullName -Destination $leftoverCleanup
                        Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Successfully moved $($nonMatchingFolder.FullName) to $leftoverCleanup"

                    }
                    Catch {
                        Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") Failed to move $($nonMatchingFolder.FullName) : $($_.Exception.Message)"
                    }
                }
            }
            else {
                Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") $($nonMatchingFolder.FullName) does not still exist."
            }    
        }      
    }
}
else {
    Out-File $logFile -Append -InputObject "$(Get-Date -Format "HH:mm") No orphaned folders found. Exiting script."
}     




