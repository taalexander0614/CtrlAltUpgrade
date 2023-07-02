<#
.SYNOPSIS
This script creates a shortcut to execute a printer group management GUI.

.DESCRIPTION
Description: In K-12 tech, we end up with a lot of devices that do not have a lot of disk space and even when imaging ran into low disk space problems from different people logging in and creating duplicate user profiles, 
    unused driver packages that were not not being sutomatically removed, windows update files that were being held onto (as they should but when a laptop have >2GB left, they need to go). Since we are moving to Intune, 
    we noticed that if we autopilot reset a device with low space, it would finish and still have low disk space because of the Windows.old folder so I wanted to get something that would completely clean up the storage and keep
    the student devices running. I love Intune Proactive Remediations but since the cleanup script will fail because of the time limit Microsoft has, I decided to just use a detection script to help us track the number of devices
    with issues and create a scheduled task to run the cleanup script. For some reason I had an issue getting the scheduled task to work when I directly executed the script, so I added a step creating a batch file that runs the
    script and just had the scheduled task execute it (I'm sure that was just me not knowing what I was doing but it works). If the detection script sees the device's free space is below a certain percent, it will create the batch
    file, download the disk cleanup script from Azure Blob Storage and create a scheduled task to run immediately before deleting itself. The disk cleanup script will delete the batch file but I am leaving the script itself on the
    device just because I don't want to end up going past my free storage limits in case devices end up running it multiple times and we use it for other stuff. 

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
You will also need to check the blob storage folder structure variables to ensure they match what is used in your organization.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Set your orginization and the desktop shortcut's name and where you want the shortcut to go. The ico file in your blob storage should be the same as $icon.
$Global:org = "ORG"
$Global:scriptName = "ScheduledDisk-CleanupDetection"
$Percent_Alert = 10
$remediationScriptName = "ScheduledDisk-CleanupRemediation"
$blobURL = "https://ORGintunestorage.blob.core.windows.net/intune"

# Define blob storage URL and necessary related variables. $scriptName should exactly match the name of the script in your blob storage
$scriptsBlob = "$blobURL/Scripts"
$scriptURL = "$scriptsBlob/$scriptName.ps1"
$scriptURL = "$scriptBlob/$remediationScriptName.ps1"

Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
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
# Start Log
Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

$scriptFolder = "$orgFolder\Scripts"
if (!(Test-Path $scriptFolder)) {
    Write-Log -Level "INFO" -Message "Creating $scriptFolder"
    New-Item $scriptFolder -ItemType Directory -Force | Out-Null
}

try {  
# Documenting the free disk space before running the script
Write-Log -Level "INFO" -Message "Detecting the amount of free space the drive has"
    Try {
        $Win32_LogicalDisk = Get-ciminstance Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}
        $Disk_Full_Size = $Win32_LogicalDisk.size
        $Disk_Free_Space = $Win32_LogicalDisk.Freespace
        $Total_size_NoFormat = [Math]::Round(($Disk_Full_Size))
        [int]$Free_Space_percent = '{0:N0}' -f (($Disk_Free_Space / $Total_size_NoFormat * 100),1)
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $prefreeSpaceGB, $pretotalSpaceGB and $prepercentFree : $($_.Exception.Message)"
       }
        
    If($Free_Space_percent -le $Percent_Alert) {
        Write-Log -Level "INFO" -Message "Free space percent: $Free_Space_percent, creating scheduled disk cleanup task"
        write-output "Free space percent: $Free_Space_percent"		

    Write-Log -Level "INFO" -Message "Starting the scheduled task creation section on the script"
        Try {
            Write-Log -Level "INFO" -Message "Checking if $script exists, and if not creating it"
            Try {
                if ((Test-Path -Path $script) -eq $false) {
                    Invoke-WebRequest -Uri $scriptURL -OutFile $script
                }
                if ((Test-Path -Path $script) -eq $true) {
                    Write-Log -Level "INFO" -Message "$script is already present"
                }
            }
            Catch {
                Write-Log -Level "ERROR" -Message "Unable to download and save $script from $scriptURL, continuing to attempt in case the script is already present: $($_.Exception.Message)"
            }
# Create batch file to execute with scheduled task that will then execute the powershell script            
            Try {
                $batchFile = "$scriptFolder\$remediationScriptName.bat"
                $batchFileContent = "@echo off`nPowerShell.exe -ExecutionPolicy Bypass -File `"$script`""
                $batchFileContent | Out-File -FilePath $batchFile -Encoding ASCII
                Write-Host "Batch file created at: $batchFile"
            }
            Catch {
                Write-Log -Level "ERROR" -Message "Unable to create $batchFile : $($_.Exception.Message)"
            }
# Create a new scheduled task
            Write-Log -Level "INFO" -Message "Creating the scheduled task"
            Try {
                $A = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$batchFile`""
                $T = New-ScheduledTaskTrigger -Once -At (get-date).AddSeconds(10); $t.EndBoundary = (get-date).AddSeconds(60).ToString('s')
                $S = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DeleteExpiredTaskAfter 00:00:30
                Register-ScheduledTask -Force -User System -TaskName "$org DiskCleanup" -Action $A -Trigger $T -Settings $S            
            }
            Catch {
                Write-Log -Level "ERROR" -Message "The scheduled task was not successfully created; the variable used for this step were $T, $A, $S, $batchFile : $($_.Exception.Message)"
                Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
                Exit 1
            }
        }
        Catch {
            Write-Log -Level "ERROR" -Message "Failed to create the scheduled task: $($_.Exception.Message)"
            Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
            Exit 1
        }
        Write-Log -Level "INFO" -Message "Completed the disk cleanup scheduled task creation script"
        Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
        EXIT 1		            
    }
    Else {                
        Write-Log -Level "INFO" -Message "Free space percent: $Free_Space_percent, not creating the scheduled disk cleanup task"
        write-output "Free space percent: $Free_Space_percent"		
        Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
        EXIT 0
    }
}
catch{
   Write-Log -Level "ERROR" -Message $_.Exception.Message
   Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
   Exit 1
}





