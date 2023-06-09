<#
.SYNOPSIS
This script checks for shortcuts on the start menu and/or desktop.

.DESCRIPTION
This script will check for the icons added in the array below and if any are not found, it will use Write-Output to record the missing icons and Exit 1

-This script will automatically determine whether it is being run in the System or User context and adjust the path to check for the shortcuts accordingly.

.OUTPUTS
The script outputs logs to a file in the directory specified by $orgFolder.

.EXAMPLE
.\Detection.ps1 -shortcutGroup Device -location Start

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
Tested on Windows 10 and 11 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

## Since detection scripts don't take parameters, just switch to the one you want, save it and upload

# Shortcut group
$shortcutGroup = "Device"
#$shortcutGroup = "Staff"
#$shortcutGroup = "Teacher"
#$shortcutGroup = "Principal"
#$shortcutGroup = "Cameras"
#$shortcutGroup = "Media"
#$shortcutGroup = "FileShare"

# Shortcut location
#$location = "Start"
$location = "Desktop"
#$location = "Both"

# Org specific infor and script name which is used for the log file
$Global:org = "ORG"
$Global:scriptName = "Icons - $shortcutGroup"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

## Add the icons you want to the group you want
$shortcuts = @()
if ($shortcutGroup -eq "Device") {
    $Shortcuts += @{ Name = "NCEdCloud"; Target = "https://www.targeturl.com" }
    $Shortcuts += @{ Name = "Clever"; Target = "https://www.targeturl.com" }
    $Shortcuts += @{ Name = "Safe Exam Browser"; Target = "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.exe" }
}
if ($shortcutGroup -eq "Staff") {
    $shortcuts += @{ Name = "Timekeeper"; Target = "https://www.targeturl.com" }
    $shortcuts += @{ Name = "IT Workorder"; Target = "https://www.targeturl.com" }
}
if ($shortcutGroup -eq "Teacher") {
    $shortcuts += @{ Name = "Trip Direct"; Target = "https://www.targeturl.com" }
    $shortcuts += @{ Name = "Educator Handbook"; Target = "https://www.targeturl.com" }
}
if ($shortcutGroup -eq "Principal") {
    $shortcuts += @{ Name = "School Messenger"; Target = "https://www.targeturl.com" }
    $shortcuts += @{ Name = "Educator Handbook"; Target = "https://www.targeturl.com" }
    $shortcuts += @{ Name = "School Cameras"; Target = "https://www.targeturl.com" }
}
if ($shortcutGroup -eq "Cameras") {
    $shortcuts += @{ Name = "School Cameras"; Target = "https://www.targeturl.com" }
}
if ($shortcutGroup -eq "Media") {
    $Shortcuts += @{ Name = "Circulation Desk Software"; Target = "https://www.targeturl.com" }
}
if ($shortcutGroup -eq "FileShare") {
    $Shortcuts += @{ Name = "FileShare"; Target = "\\ORGServer\ShareFolder" }
}

## The rest of the script does not need to be modified
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

Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"
Write-Log -Level "INFO" -Message "Shortcut Selection set to $shortcutGroup"
Write-Log -Level "INFO" -Message "Shortcuts to be checked: $($shortcuts.Name)"

# Determine whether the script is running in user or system context
$userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($userName -eq "NT AUTHORITY\SYSTEM") {
    Write-Log -Level "INFO" -Message "Script is running in system context"
    $startMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$org"
    $desktopPath = "$env:Public\Desktop"
}
else {
    Write-Log -Level "INFO" -Message "Script is running in user context"
    $startMenuPath = "$Home\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\$org"
    $desktopPath = "$Home\Desktop"
}

$shortcutDetectionCount = @()
$missingStartMenuShortcuts = @()  
$missingDesktopShortcuts = @()
Write-Log -Level "INFO" -Message "Working Start Menu Path: $startMenuPath"
Write-Log -Level "INFO" -Message "Working Desktop Path: $desktopPath"


Try {
    ForEach ($shortcut in $shortcuts){
        if ($location -eq "Desktop" -or $location -eq "Both") {
            if (!(test-path -Path "$desktopPath\$($shortcut.Name).lnk")) {
                $shortcutDetectionCount += 1; $missingDesktopShortcuts += $shortcut.Name
                Write-Log -Level "INFO" -Message "$($shortcut.Name) missing from desktop"
            }
        }
        if ($location -eq "Start Menu" -or $location -eq "Both") {
            if (!(test-path -Path "$startMenuPath\$($shortcut.Name).lnk")) {
                $shortcutDetectionCount += 1; $missingStartMenuShortcuts += $shortcut.Name
                Write-Log -Level "INFO" -Message "$($shortcut.Name) missing from start menu"
            }
        }    
    }
}
Catch {
    Write-Log -Level "ERROR" -Message "Failed to run detection for shortcuts: $_"
    Write-Output "Failed to run detection for shortcuts: $_"
}
## Check to see if any shortcuts were missing
if ($shortcutDetectionCount.Count -ne 0) {
    If ($missingStartMenuShortcuts.Count -ne 0) {
    Write-Output "Missing Start Menu Shortcuts: $missingStartMenuShortcuts"
    Write-Log -Level "INFO" -Message "Missing Start Menu Shortcuts: $missingStartMenuShortcuts"
    }
    if ($missingDesktopShortcuts.Count -ne 0) {
    Write-Output "Missing Desktop Shortcuts: $missingDesktopShortcuts"
    Write-Log -Level "INFO" -Message "Missing Desktop Shortcuts: $missingDesktopShortcuts"
    }
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
    Exit 1
}
else {
    Write-Log -Level "INFO" -Message "No missing shortcuts"
    Write-Output "No missing shortcuts"
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
    Exit 0
}
