<#
.SYNOPSIS
This script creates a shortcut to execute a printer group management GUI.

.DESCRIPTION
This script will: 
    -Delete the batch file that ran it 
    -Run DISM to restore health 
    -Run DISM to cleanup any old components 
    -Delete the Windows Update Cache 
    -Run cleanmgr.

.NOTES
This script is probably super excessive for most situations.
I made this because AutoPilot resets were leaving massive Windows.old folders that would make a freshly reset device still have low disk space.

This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
You will also need to check the blob storage folder structure variables to ensure they match what is used in your organization.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Set your orginization, blob storage URL and necessary related variables. $scriptName should exactly match the name of the script in your blob storage
$Global:org = "ORG"
$Global:scriptName = "ScheduledDisk-CleanupRemediation"

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
$batchFile = "$scriptFolder\$scriptName.bat"
try { 
# Deleting batch file that triggered script
    if ((Test-Path -Path $batchFile) -eq $true) {
        Try {
            Write-Log -Level "INFO" -Message "Deleting $batchFile"
        Remove-Item -Force -Path $batchFile
        }
        Catch {
            Write-Log -Level "ERROR" -Message "Unable to delete $batchFile : $($_.Exception.Message)"
        }
    }
    if ((Test-Path -Path $batchFile) -eq $false) {
        Write-Log -Level "INFO" -Message "$batchFile does not exist"
    } 

# Documenting the free disk space before running the script
   Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has"
   Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $prescriptfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $prescripttotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $prescriptpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
        Write-Log -Level "INFO" -Message "Free space on $osDrive drive: $prescriptfreeSpaceGB GB ($prescriptpercentFree% free of $prescripttotalSpaceGB GB)"
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $prescriptfreeSpaceGB, $prescripttotalSpaceGB and $prescriptpercentFree : $($_.Exception.Message)"
    }

# Beginning Disk Cleanup Script
    Write-Log -Level "INFO" -Message "Beginning the disk cleanup script"

# Running Cleanmgr before/after DISM commands since if the device's disk space is too low it can interfere with DISM
# Documenting the free disk space before running Cleanmgr.exe
Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has before running Cleanmgr.exe"
Try {
    $osDrive = $env:SystemDrive
    $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
    $preCleanmgrfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
    $preCleanmgrtotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
    $preCleanmgrpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
    Write-Log -Level "INFO" -Message "Free space on $osDrive drive: $preCleanmgrfreeSpaceGB GB ($preCleanmgrpercentFree% free of $preCleanmgrtotalSpaceGB GB)"
}
Catch {
    Write-Log -Level "INFO" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $preCleanmgrfreeSpaceGB, $preCleanmgrtotalSpaceGB and $preCleanmgrpercentFree : $($_.Exception.Message)"
}

# Get the registry paths needed for volume cache
Try {
    $CleanmgrStartTime = Get-Date
    [string]$RegistryVolumeCachesRootPath = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    [string[]]$RegistryVolumeCachesPaths = Get-ChildItem -Path $RegistryVolumeCachesRootPath | Select-Object -ExpandProperty 'Name'
            
# Set registry entries for Cleanmgr settings
    [string]$RegistrySageSet = '5432'
    [string]$RegistryName = 'StateFlags' + $RegistrySageSet
    [string]$RegistryValue = '00000002'
    [string]$RegistryType = 'DWORD'
    ForEach ($RegistryVolumeCachesPath in $RegistryVolumeCachesPaths) {
        $null = New-ItemProperty -Path Registry::$RegistryVolumeCachesPath -Name $RegistryName -Value $RegistryValue -PropertyType $RegistryType -Force
    }
}
Catch {            
    Write-Log -Level "INFO" -Message "Unable to set required registry entries for Cleanmgr.exe: $($_.Exception.Message)"
}
Try {
    Write-Log -Level "INFO" -Message "Running Cleanmgr"
    Start-Process -FilePath 'CleanMgr.exe' -ArgumentList "/sagerun:$RegistrySageSet" -Wait
}
Catch {
    Write-Log -Level "INFO" -Message "Failed to successfully run cleanmgr: $($_.Exception.Message)"
}

#Logging the amount of time deleting Cleanmgr took
$CleanmgrendTime = Get-Date
$Cleanmgrduration = New-TimeSpan $CleanmgrstartTime $CleanmgrendTime
$CleanmgrdurationString = "{0:hh\:mm\:ss}" -f $Cleanmgrduration
Write-Log -Level "INFO" -Message "Cleanmgr took $Cleanmgrdurationstring to run."
Write-Log -Level "INFO" -Message "Determining the amount of disk space cleanmgr freed up"

# Documenting the free disk space after deleting Cleanmgr
Try {
    $osDrive = $env:SystemDrive
    $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
    $postCleanmgrfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
    $postCleanmgrtotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
    $postCleanmgrpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
}
Catch {
    Write-Log -Level "INFO" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $postCleanmgrfreeSpaceGB, $postCleanmgrtotalSpaceGB and $postCleanmgrpercentFree : $($_.Exception.Message)"
}

Write-Log -Level "INFO" -Message "Free space before deleting Cleanmgr on $osDrive drive: $preCleanmgrfreeSpaceGB GB ($preCleanmgrpercentFree% free of $preCleanmgrtotalSpaceGB GB)"
Write-Log -Level "INFO" -Message "Free space after deleting Cleanmgr on $osDrive drive: $postCleanmgrfreeSpaceGB GB ($postCleanmgrpercentFree% free of $postCleanmgrtotalSpaceGB GB)"

# Compare percentages of free space before and after running cleanmgr
$CleanmgrpercentChange = [math]::Round(($postCleanmgrscriptpercentFree - $preCleanmgrscriptpercentFree), 2)
if ($CleanmgrpercentChange -gt 0) {
        Write-Log -Level "INFO" -Message "deleting Cleanmgr increased free space by $CleanmgrpercentChange% ($gbChange GB)"
    } elseif ($CleanmgrpercentChange -lt 0) {
        Write-Log -Level "INFO" -Message "deleting Cleanmgr decreased free space by $CleanmgrpercentChange% ($gbChange GB)"
    } else {
        Write-Log -Level "INFO" -Message "deleting Cleanmgr did not change free space percentage"
    }


# Documenting the free disk space before running DISM
Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has before running DISM.exe"
Try {
    $osDrive = $env:SystemDrive
    $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
    $preDISMfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
    $preDISMtotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
    $preDISMpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
    Write-Log -Level "INFO" -Message "Free space on $osDrive drive: $preDISMfreeSpaceGB GB ($preDISMpercentFree% free of $preDISMtotalSpaceGB GB)"
 }
 Catch {
    Write-Log -Level "INFO" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $preDISMfreeSpaceGB, $preDISMtotalSpaceGB and $preDISMpercentFree : $($_.Exception.Message)"
 }

# Run Dism.exe /restoreHealth to ensure any corruption is fixed before trying to optimize
    Write-Log -Level "INFO" -Message "Executing DISM with the following parameters: /Online /Cleanup-Image /RestoreHealth"
    Try {
        $DISMstartTime = Get-Date
        $startArgs = "/Online /Cleanup-Image /RestoreHealth"
        $processName = "Dism"
        $processArgs = "-ArgumentList $startArgs"
        $process = Start-Process $processName -ArgumentList $processArgs -PassThru    
    }
    Catch {
        Write-Log -Level "INFO" -Message "Failed to execute DISM with the following parameters: /Online /Cleanup-Image /StartComponentCleanup /ResetBase: $($_.Exception.Message)"
    }

# Wait for DISM to restore health
    Try {
        while ($process.HasExited -eq $false) {
            Write-Log -Level "INFO" -Message "DISM is still attempting to repair the Windows image, waiting 5 seconds before checking if it has completed again"
            Write-Log -Level "INFO" -Message "Process ID: $($process.Id)"
            Write-Log -Level "INFO" -Message "Process complete? $($process.HasExited)"
            Start-Sleep -Seconds 5
        }
    }
    Catch {
        Write-Log -Level "INFO" -Message "Failed wait for DISM restore health to complete: $($_.Exception.Message)"
    } 

# Run SFC /ScanNow to make any repairs now that the component store has been verified/repaired
Write-Log -Level "INFO" -Message "Executing SFC /ScanNow"
Try {
    $startArgs = "/ScanNow"
    $processName = "SFC"
    $processArgs = "-ArgumentList $startArgs"
    $process = Start-Process $processName -ArgumentList $processArgs -PassThru    
}
Catch {
    Write-Log -Level "INFO" -Message "Failed to executeSFC /ScanNow: $($_.Exception.Message)"
}

# Wait for SFC to check the file system
Try {
    while ($process.HasExited -eq $false) {
        Write-Log -Level "INFO" -Message "SFC is still scanning the file system, waiting 5 seconds before checking if it has completed again"
        Write-Log -Level "INFO" -Message "Process ID: $($process.Id)"
        Write-Log -Level "INFO" -Message "Process complete? $($process.HasExited)"
        Start-Sleep -Seconds 5
    }
}
Catch {
    Write-Log -Level "INFO" -Message "Failed wait for SFC /ScanNow to complete: $($_.Exception.Message)"
} 
Write-Log -Level "INFO" -Message "SFC /ScanNow completed"

# Now that DISM has fixed potential corruption, running DISM again to cleanup uneeded components with the following parameters /Online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Log -Level "INFO" -Message "Executing DISM with the following parameters: /Online /Cleanup-Image /StartComponentCleanup /ResetBase"
    Try {
        $startArgs = "/Online /Cleanup-Image /StartComponentCleanup /ResetBase"
        $processName = "Dism"
        $processArgs = "-ArgumentList $startArgs"
        $process = Start-Process $processName -ArgumentList $processArgs -PassThru    
    }
    Catch {
        Write-Log -Level "INFO" -Message "Failed to execute DISM: $($_.Exception.Message)"
    }

# Wait for DISM to finish cleaning components that are no longer needed
    Try {
        while ($process.HasExited -eq $false) {
            Write-Log -Level "INFO" -Message "DISM is still removing older versions of components, waiting 10 seconds before checking if it has completed again"
            Write-Log -Level "INFO" -Message "Process ID: $($process.Id)"
            Write-Log -Level "INFO" -Message "Process complete? $($process.HasExited)"
            Start-Sleep -Seconds 5
        }
    }
    Catch {
        Write-Log -Level "INFO" -Message "Failed wait for the ComponentCleanup Task to Complete; the variable in use was $taskProcess : $($_.Exception.Message)"
    }  

#Logging the amount of time Dism.exe took
    $DISMendTime = Get-Date
    $DISMduration = New-TimeSpan $DISMstartTime $DISMendTime
    $DISMdurationString = "{0:hh\:mm\:ss}" -f $DISMduration
    Write-Log -Level "INFO" -Message "The process DISM.exe has completed. Duration: $DISMdurationString."

# Documenting the free disk space after running DISM.exe
    Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has after DISM.exe"
    Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $postDISMfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $postDISMtotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $postDISMpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
    }
    Catch {
        Write-Log -Level "INFO" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $postDISMfreeSpaceGB, $postDISMtotalSpaceGB and $postDISMpercentFree : $($_.Exception.Message)"
    }

    Write-Log -Level "INFO" -Message "Free space before the disk cleanup on $osDrive drive: $preDISMfreeSpaceGB GB ($preDISMpercentFree% free of $preDISMtotalSpaceGB GB)"
    Write-Log -Level "INFO" -Message "Free space after the disk cleanup on $osDrive drive: $postDISMfreeSpaceGB GB ($postDISMpercentFree% free of $postDISMtotalSpaceGB GB)"

# Compare percentages of free space before and after DISM.exe
    $DISMpercentChange = [math]::Round(($postDISMscriptpercentFree - $preDISMscriptpercentFree), 2)
    if ($DISMpercentChange -gt 0) {
        Write-Log -Level "WARN" -Message "DISM.exe increased free space by $DISMpercentChange% ($gbChange GB)"
    } elseif ($DISMpercentChange -lt 0) {
        Write-Log -Level "INFO" -Message "Dism.exe decreased free space by $DISMpercentChange% ($gbChange GB)"
    } else {
        Write-Log -Level "WARN" -Message "Dism.exe did not change free space percentage"
    }

# Documenting the free disk space before running Update Cache Cleanup
    Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has before running Update Cache Cleanup"
    Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $preUpdatefreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $preUpdatetotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $preUpdatepercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
        Write-Log -Level "INFO" -Message "Free space on $osDrive drive: $preUpdatefreeSpaceGB GB ($preUpdatepercentFree% free of $preUpdatetotalSpaceGB GB)"
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $preUpdatefreeSpaceGB, $preUpdatetotalSpaceGB and $preUpdatepercentFree : $($_.Exception.Message)"
    }

# Run update cache cleanup
    Write-Log -Level "INFO" -Message "Running update cache cleanup"
    $UpdatestartTime = Get-Date

# Start Update Cache Cleanup
    $UpdateFolder = "$env:SystemRoot\SoftwareDistribution\"
    if ((Test-Path -Path $UpdateFolder) -eq $true) {
        Try {
            Write-Log -Level "INFO" -Message "Stopping wuauserv service"
            Stop-Service -Name 'wuauserv' -Force -ErrorAction 'SilentlyContinue'
            Write-Log -Level "INFO" -Message "Deleting Software Distribution Folder"
            Remove-Item -Path $UpdateFolder -Recurse -Force
            Write-Log -Level "INFO" -Message "Restarting wuauserv service"
            Start-Service -Name 'wuauserv' -ErrorAction 'SilentlyContinue'  
        }
        Catch {
            Write-Log -Level "ERROR" -Message "Failed to execute Update Cache Cleanup: $($_.Exception.Message)"
            Exit 1
        }
    }

# Wait for the Update Cache Cleanup to finish
    Try {
        while ($process.HasExited -eq $false) {
            Write-Log -Level "INFO" -Message "Update Cache Cleanup is still running, waiting 5 seconds before checking if it has completed again"
            Write-Log -Level "INFO" -Message "Process ID: $($process.Id)"
            Write-Log -Level "INFO" -Message "Process complete? $($process.HasExited)"
            Start-Sleep -Seconds 5
        }
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to wait for the Update Cache Cleanup to Complete: $($_.Exception.Message)"
    }  

#Logging the amount of time Update Cache Cleanup took
    $UpdateendTime = Get-Date
    $Updateduration = New-TimeSpan $UpdatestartTime $UpdateendTime
    $UpdatedurationString = "{0:hh\:mm\:ss}" -f $Updateduration
    Write-Log -Level "INFO" -Message "The process Update Cache Cleanup has completed. Duration: $UpdatedurationString."

# Documenting the free disk space after running Update Cache Cleanup
    Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has after Update Cache Cleanup"
    Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $postUpdatefreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $postUpdatetotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $postUpdatepercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $postUpdatefreeSpaceGB, $postUpdatetotalSpaceGB and $postUpdatepercentFree : $($_.Exception.Message)"
    }

    Write-Log -Level "INFO" -Message "Free space before the Update Cache Cleanup on $osDrive drive: $preUpdatefreeSpaceGB GB ($preUpdatepercentFree% free of $preUpdatetotalSpaceGB GB)"
    Write-Log -Level "INFO" -Message "Free space after the Update Cache Cleanup on $osDrive drive: $postUpdatefreeSpaceGB GB ($postUpdatepercentFree% free of $postUpdatetotalSpaceGB GB)"

# Compare percentages of free space before and after Update Cache Cleanup
    $UpdatepercentChange = [math]::Round(($postUpdatescriptpercentFree - $preUpdatescriptpercentFree), 2)
    if ($UpdatepercentChange -gt 0) {
        Write-Log -Level "WARN" -Message "Update Cache Cleanup increased free space by $UpdatepercentChange% ($gbChange GB)"
    } elseif ($UpdatepercentChange -lt 0) {
        Write-Log -Level "INFO" -Message "Update Cache Cleanup decreased free space by $UpdatepercentChange% ($gbChange GB)"
    } else {
        Write-Log -Level "WARN" -Message "Update Cache Cleanup did not change free space percentage"
    }

# Documenting the free disk space before running Cleanmgr.exe
    Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has before running Cleanmgr.exe"
    Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $preCleanmgrfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $preCleanmgrtotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $preCleanmgrpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
        Write-Log -Level "INFO" -Message "Free space on $osDrive drive: $preCleanmgrfreeSpaceGB GB ($preCleanmgrpercentFree% free of $preCleanmgrtotalSpaceGB GB)"
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $preCleanmgrfreeSpaceGB, $preCleanmgrtotalSpaceGB and $preCleanmgrpercentFree : $($_.Exception.Message)"
    }

# Starting second run of Cleanmgr to finish up
    Try {
        Write-Log -Level "INFO" -Message "Running Cleanmgr"
        Start-Process -FilePath 'CleanMgr.exe' -ArgumentList "/sagerun:$RegistrySageSet" -Wait
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to successfully run cleanmgr: $($_.Exception.Message)"
    }

#Logging the amount of time deleting Cleanmgr took
    $CleanmgrendTime = Get-Date
    $Cleanmgrduration = New-TimeSpan $CleanmgrstartTime $CleanmgrendTime
    $CleanmgrdurationString = "{0:hh\:mm\:ss}" -f $Cleanmgrduration
    Write-Log -Level "INFO" -Message "Cleanmgr took $Cleanmgrdurationstring to complete."
    Write-Log -Level "INFO" -Message "Determining the amount of disk space cleanmgr freed up"

# Documenting the free disk space after deleting Cleanmgr
    Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $postCleanmgrfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $postCleanmgrtotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $postCleanmgrpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $postCleanmgrfreeSpaceGB, $postCleanmgrtotalSpaceGB and $postCleanmgrpercentFree : $($_.Exception.Message)"
    }

    Write-Log -Level "INFO" -Message "Free space before deleting Cleanmgr on $osDrive drive: $preCleanmgrfreeSpaceGB GB ($preCleanmgrpercentFree% free of $preCleanmgrtotalSpaceGB GB)"
    Write-Log -Level "INFO" -Message "Free space after deleting Cleanmgr on $osDrive drive: $postCleanmgrfreeSpaceGB GB ($postCleanmgrpercentFree% free of $postCleanmgrtotalSpaceGB GB)"

# Compare percentages of free space before and after running cleanmgr
    $CleanmgrpercentChange = [math]::Round(($postCleanmgrscriptpercentFree - $preCleanmgrscriptpercentFree), 2)
    if ($CleanmgrpercentChange -gt 0) {
            Write-Log -Level "WARN" -Message "deleting Cleanmgr increased free space by $CleanmgrpercentChange% ($gbChange GB)"
        } elseif ($CleanmgrpercentChange -lt 0) {
            Write-Log -Level "INFO" -Message "deleting Cleanmgr decreased free space by $CleanmgrpercentChange% ($gbChange GB)"
        } else {
            Write-Log -Level "WARN" -Message "deleting Cleanmgr did not change free space percentage"
        }

# Documenting the free disk space after running the script
   Write-Log -Level "INFO" -Message "Recording the amount of free space the drive has after running the disk cleanup script"
    Try {
        $osDrive = $env:SystemDrive
        $osVolume = Get-CimInstance -ClassName CIM_LogicalDisk | Where-Object DeviceID -eq $osDrive
        $postscriptfreeSpaceGB = [math]::Round($osVolume.FreeSpace / 1GB, 2)
        $postscripttotalSpaceGB = [math]::Round($osVolume.Size / 1GB, 2)
        $postscriptpercentFree = [math]::Round(($osVolume.FreeSpace / $osVolume.Size) * 100, 2)
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Failed to determine the amount of free disk space; the variables in use were $osDrive, $osVolume, $postscriptfreeSpaceGB, $postscripttotalSpaceGB and $postscriptpercentFree : $($_.Exception.Message)"
    }
    
    Write-Log -Level "INFO" -Message "Free space before the disk cleanup on $osDrive drive: $prescriptfreeSpaceGB GB ($prescriptpercentFree% free of $prescripttotalSpaceGB GB)"
    Write-Log -Level "INFO" -Message "Free space after the disk cleanup on $osDrive drive: $postscriptfreeSpaceGB GB ($postscriptpercentFree% free of $postscripttotalSpaceGB GB)"
    
# Compare percentages of free space before and after disk cleanup script
    $percentChange = [math]::Round(($postscriptpercentFree - $prescriptpercentFree), 2)
    if ($percentChange -gt 0) {
        Write-Log -Level "WARN" -Message "Disk cleanup increased free space by $percentChange% ($gbChange GB)"
    } elseif ($percentChange -lt 0) {
        Write-Log -Level "INFO" -Message "Disk cleanup decreased free space by $percentChange% ($gbChange GB)"
    } else {
        Write-Log -Level "WARN" -Message "The disk cleanup script did not change free space percentage"
    }

#Logging the amount of time the disk cleanup script took
    $ScriptendTime = Get-Date
    $Scriptduration = New-TimeSpan $ScriptstartTime $ScriptendTime
    $ScriptdurationString = "{0:hh\:mm\:ss}" -f $Scriptduration
    Write-Log -Level "INFO" -Message "Completed the disk cleanup script. Duration: $Scriptdurationstring."
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
}
Catch {
    Write-Log -Level "ERROR" -Message $_.Exception.Message
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
    Exit 1
}


