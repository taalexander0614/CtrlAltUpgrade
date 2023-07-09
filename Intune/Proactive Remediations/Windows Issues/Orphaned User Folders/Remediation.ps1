<#
.SYNOPSIS
This is a remediation script originally made as an Intune Proactive Remediation to clean up "orphaned" user folders on a Windows system. 

.DESCRIPTION
This script looks for folders in C:\Users that were left over when a user account was deleted. 
It identifies orphaned folders by comparing the folders in C:\Users to the list of user profiles in the Windows Registry. 
If the script finds any folders that do not have a corresponding user profile, it attempts to delete them.
If it fails to delete them because of permissions issues, it will continue trying a few ways before moving the to the Cleanup folder it creates.

.NOTES
When checking C:\Users, the script ignores the Public folder and the Cleanup folder it creates

This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Set initial variables 
$Global:org = "ORG"
$Global:scriptName = "Orphaned User Folders"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR
$leftoverCleanup = "C:\Users\Cleanup"

Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    # Compare the priority of logging level
    $LogPriority = @{
        "DEBUG" = 0
        "INFO"  = 1
        "WARN"  = 2
        "ERROR" = 3
    }
    if($LogPriority[$Level] -ge $LogPriority[$Global:logLevel]) {
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
            Write-Output "Failed to create log directory or file: $_"
        }
        # Set log date stamp
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp [$Level] $Message"
        $streamWriter = New-Object System.IO.StreamWriter($logFile, $true)
        $streamWriter.WriteLine($LogEntry)
        $streamWriter.Close()
    }
}
# Start Log
Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# Check for any accounts found on system before running script
$startingProfileNames = @()
$profiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "S-1-5-21-*" }   
foreach ($profile in $profiles) {
    $profileImagePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($profile.PSChildName)" -Name ProfileImagePath | Select-Object -ExpandProperty ProfileImagePath
    $startingprofilenames += $profileImagePath -replace "C:\\Users\\", ""
}
Write-Log -Level "INFO" -Message "The accounts present on device: $startingProfileNames."

# Get all user profiles and compare with folders in C:\Users
Write-Log -Level "INFO" -Message "Checking for orphaned folders."
$remainingProfileNames = @()
$remainingprofiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue  
foreach ($remainingprofile in $remainingprofiles) {
    $remainingprofileImagePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($remainingprofile.PSChildName)" -Name ProfileImagePath | Select-Object -ExpandProperty ProfileImagePath
    $remainingprofilenames += $remainingprofileImagePath -replace "C:\\Users\\", ""
}
$folders = Get-ChildItem -Path "C:\Users" -Directory

$nonMatchingFolders = @()
foreach ($folder in $folders) {
    if ($remainingprofilenames -notcontains $folder.Name -and $folder.Name -notin "Public", "Cleanup") {
        $nonMatchingFolders += $folder
    }
}
# Loop through each folder and attempt to delete          
if (![string]::IsNullOrEmpty($nonMatchingFolders)) { 
    Write-Log -Level "INFO" -Message "Orphaned folders found: $nonMatchingFolders."
    Write-Log -Level "INFO" -Message "Attempting to delete orphaned folders from C:\Users." 
    foreach ($nonMatchingFolder in $nonMatchingFolders) {
        Write-Log -Level "INFO" -Message "Attempting to delete $($nonMatchingFolder.FullName)."
        Try {
            Remove-Item $nonMatchingFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Catch {
            Write-Log -Level "ERROR" -Message "Failed to delete $($nonMatchingFolder.FullName)"
        }
        Write-Log -Level "INFO" -Message "Checking if $($nonMatchingFolder.FullName) still exists."
        # If folder was not deleted, assign ownership and full control access to the System account before recursively deleting the folder while silently continuing on error                    
        if (Test-Path $nonMatchingFolder.FullName -PathType Container) {
            Write-Log -Level "WARN" -Message "$($nonMatchingFolder.FullName) still exists, so attempting to take ownership."
            Try {
                Write-Log -Level "INFO" -Message "Attempting to take ownership of duplicate folder $nonMatchingFolder."
                $directoryPath = $nonMatchingFolder.FullName
                $Acl = Get-Acl $directoryPath
                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                $Acl.SetOwner($Ar.IdentityReference)
                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl","Allow")
                $Acl.SetAccessRule($Ar)
                Set-Acl -Path $directoryPath -AclObject $Acl -Verbose 2>&1 | Tee-Object -FilePath $logFile -Append
            }
            Catch {
                Write-Log -Level "ERROR" -Message "Failed to take ownership of $($nonMatchingFolder.FullName) : $($_.Exception.Message)"
            }
            Write-Log -Level "INFO" -Message "Attempting to delete $($nonMatchingFolder.FullName)."
            Try {
                Remove-Item $nonMatchingFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            Catch {
                Write-Log -Level "ERROR" -Message "Failed to delete $($nonMatchingFolder.FullName)"
            }
            Write-Log -Level "INFO" -Message "Checking if $($nonMatchingFolder.FullName) still exists."

            # Check to see if the folder still exists so a more thorough attempt at deletion can be made if needed
            if (Test-Path $nonMatchingFolder.FullName -PathType Container) {
                Write-Log -Level "WARN" -Message "$($nonMatchingFolder.FullName) still exists, so proceeding to delete childitems."

                # Put all remaining child files individually into an array and loop through to take the same attept to chenge permissions and delete                   
                $files = Get-ChildItem $nonMatchingFolder.FullName -File -Recurse -Force
                foreach ($file in $files) {
                    if (Test-Path $file.FullName) {
                        Try {
                            Remove-Item $file.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Catch {
                            Write-Log -Level "ERROR" -Message "Failed to remove $folder child file $file"
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
                                Write-Log -Level "ERROR" -Message "Failed to modify permissions/delete of $nonMatchingFolder child file $($file.FullName) : $($_.Exception.Message)"
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
                            Write-Log -Level "WARN" -Message "Failed to remove $nonMatchingFolder child folder $container"
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
                                Write-Log -Level "ERROR" -Message "Failed to modify permissions/delete $nonMatchingFolder child folder $($container.FullName) : $($_.Exception.Message)"
                            }
                        }
                    }                         
                }
                Write-Log -Level "INFO" -Message "Attempting to delete $($nonMatchingFolder.FullName) again after deleting childitems."
                Try {
                    Remove-Item $nonMatchingFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
                Catch {
                    Write-Log -Level "ERROR" -Message "Failed to delete $($nonMatchingFolder.FullName)"
                }
                if (Test-Path $nonMatchingFolder.FullName -PathType Container) {
                    Write-Log -Level "INFO" -Message "$($nonMatchingFolder.FullName) still exists; attempting to move to $leftoverCleanup."
                    # If folder still exists, move to $destinationFolder to clean up C:\Users and potentially prevent more duplication 
                    Try {
                        Move-Item -Path $nonMatchingFolder.FullName -Destination $leftoverCleanup
                        Write-Log -Level "INFO" -Message "Successfully moved $($nonMatchingFolder.FullName) to $leftoverCleanup"

                    }
                    Catch {
                        Write-Log -Level "ERROR" -Message "Failed to move $($nonMatchingFolder.FullName) : $($_.Exception.Message)"
                    }
                }
            }
            else {
                Write-Log -Level "INFO" -Message "$($nonMatchingFolder.FullName) does not still exist."
            }    
        }      
    }
}
else {
    Write-Log -Level "INFO" -Message "No orphaned folders found. Exiting script."
} 
Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"




