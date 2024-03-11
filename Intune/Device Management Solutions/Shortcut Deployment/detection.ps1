<#
.SYNOPSIS
    This script is used to detect if the shortcuts are present on the user's desktop and start menu.

.DESCRIPTION
    The script starts by logging its initiation. It then defines necessary variables including the organization folder, shortcut folder, and the path to the shortcut reference JSON file. 
    Next, it retrieves the JSON content from the shortcut reference file and processes each shortcut entry. For each shortcut, it checks if the shortcut is present on the user's desktop and start menu. 
    If the shortcut is present, it logs a warning. If the shortcut is not present, it logs a warning. 
    The script logs any warnings for invalid actions or the absence of an IP address. After processing all shortcuts, it creates a remediation file if any shortcuts are missing and exits the script.

.PARAMETER orgName
    Specifies the name of the organization.

.PARAMETER scriptName
    Specifies the name of the script.

.PARAMETER logLevel
    Specifies the logging level for the script. Valid values are DEBUG, INFO, WARN, and ERROR. The default value is INFO.

.NOTES
    - This script assumes the existence of a shortcut reference JSON file containing the necessary shortcut information for management.
    - It is essential to ensure that the script is executed with appropriate permissions to add or remove shortcuts.
    - Ensure the JSON file is correctly formatted with valid shortcut entries and actions.
    - The script employs logging to track its execution, providing insight into the actions taken and any encountered warnings or errors.
    - The logging function will create a log file in the organization's ProgramData or user's AppData\Roaming directory, depending on the context in which the script is executed.
    - Before executing the script in a production environment, thoroughly test it in a controlled setting to verify its functionality and ensure it meets organizational requirements.
#>

$Global:orgName = 'CtrlAltUpgrade'
$Global:scriptName = "Shortcut Deployment - Detection"
$Global:logLevel = "INFO"
$jsonUrl = "<URL to JSON file>"
$OneDrive = $false
$OneDriveCommercial = $true
$tenantId = '<Tenant ID>'
$appID = '<App ID>'
$appSecret = '<App Secret>'

Function Write-Log {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Level = "INFO",  # Set default value to "INFO"
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    # Validate outside of the param block so it can still be logged if the level paramater is wrong
    if ($PSBoundParameters.ContainsKey('Level')) {
        # Validate against the specified values
        if ($Level -notin ("DEBUG", "INFO", "WARN", "ERROR")) {
            $errorMessage = "$Level is an invalid value for Level parameter. Valid values are DEBUG, INFO, WARN, ERROR."
            Write-Error  $errorMessage
            $Message = "$errorMessage - $Message"
            $Level = "WARN"
        }
    }

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
            $Global:orgFolder = "$env:ProgramData\$orgName"
        }
        else {
            $Global:orgFolder = "$Home\AppData\Roaming\$orgName"
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
            else {
                # Check log file size and truncate if necessary
                $logFileInfo = Get-Item $logFile
                if ($logFileInfo.Length / 1MB -gt $maxLogSizeMB) {
                    $streamWriter = New-Object System.IO.StreamWriter($logFile, $false)
                    $streamWriter.Write("")
                    $streamWriter.Close()
                    Write-Log -Level "INFO" -Message "Log file truncated due to exceeding maximum size."
                }
            }
        }
        catch {
            Write-Error "Failed to create log directory or file: $_"
        }

        # Set log date stamp
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp [$Level] $Message"
        $streamWriter = New-Object System.IO.StreamWriter($logFile, $true)
        $streamWriter.WriteLine($LogEntry)
        $streamWriter.Close()
    }
}

function Get-AccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$tenantID,
        [Parameter(Mandatory = $true)]
        [string]$appID,
        [Parameter(Mandatory = $true)]
        [string]$appSecret
    )
    Write-Log -Message "Obtaining Auth Token"
    $accessTokenUrl = "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token"
    $tokenRequestBody = @{
        "grant_type"    = "client_credentials"
        "scope"         = "https://graph.microsoft.com/.default"
        "client_id"     = $appID
        "client_secret" = $appSecret
    }   
    Try {
        $tokenResponse = Invoke-RestMethod -Uri $accessTokenUrl -Method POST -Body $tokenRequestBody
    }
    Catch {
        Write-Log -Message "Failed to obtain Auth Token: $_"
    }
    Write-Log -Message "Obtained Auth Token"
    return $tokenResponse.access_token
}

function Invoke-GetAllUsers {
    param (
        [bool]$OneDrive,
        [bool]$OneDriveCommercial
    )
    # Define the ProfileList registry key path
    $profileListKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

    # Get all user SIDs from the ProfileList registry key
    $userSIDs = Get-ChildItem -Path $profileListKeyPath | ForEach-Object { $_.PSChildName }

    # Create an array to store user profiles
    $userProfiles = @()

    # Iterate through each SID and retrieve information
    foreach ($sid in $userSIDs) {
        # Get profile path for each SID
        $userProfileKeyPath = "$profileListKeyPath\$sid"
        $userProfilePath = (Get-ItemProperty -Path $userProfileKeyPath).ProfileImagePath
        $userName = $userProfilePath.Split("\")[-1]
        $userName = $userName -replace '\.RCS.*$',''
        # Get the Environment key path for the user
        $userEnvKeyPath = "Registry::HKEY_USERS\$sid\Environment"

        if ($OneDriveCommercial) {
            try {
                $userFolder = Get-ItemPropertyValue -Path $userEnvKeyPath -Name "OneDriveCommercial" -ErrorAction SilentlyContinue
            }
            catch {
                $userFolder = $null
            }
        }  
        elseif ($OneDrive) {
            try {
                $userFolder = Get-ItemPropertyValue -Path $userEnvKeyPath -Name "OneDrive" -ErrorAction SilentlyContinue
            }
            catch {
                $userFolder = $null
            }
        } 
        if (!$OneDrive -and !$OneDriveCommercial -or !$userFolder) {
            $userFolder = $user.ProfilePath
        }  

        if (($userName -ne "systemprofile") -and ($userName -ne "localservice") -and ($userName -ne "NetworkService")) {
            # Create a PSObject to store user information
            $userProfile = New-Object PSObject -Property @{
                SID = $sid
                UserName = $userName
                ProfilePath = $userFolder
                DesktopPath = "$userFolder\Desktop"
                StartMenuPath = "$userFolder\AppData\Roaming\Microsoft\Windows\Start Menu"
            }
            # Add the user's PSObject to the array
            $userProfiles += $userProfile
        }
    }
    # Create a PSObject to store computer information
    $userProfile = New-Object PSObject -Property @{
        SID = $env:ComputerName
        UserName = $env:ComputerName
        ProfilePath = "C:\Users\Public"
        DesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
        StartMenuPath = [Environment]::GetFolderPath("CommonStartMenu")
    }
    # Add the computer's PSObject to the array
    $userProfiles += $userProfile
    return $userProfiles
}

function Invoke-CreateShortcut {
    param (
        [Parameter(Mandatory = $true)]
        [string]$shortcutTarget,
        [Parameter(Mandatory = $true)]
        [string]$iconPath,
        [Parameter(Mandatory = $true)]
        [string]$shortcutPath,
        [Parameter(Mandatory = $false)]
        [string]$shortcutArgs,
        [Parameter(Mandatory = $true)]
        [string]$version,
        [Parameter(Mandatory = $false)]
        [string]$workingDirectory,
        [Parameter(Mandatory = $false)]
        [string]$WindowStyle,
        [Parameter(Mandatory = $false)]
        [string]$Hotkey
    )

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$shortcutTarget).exe") {
        $shortcutTargetPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$shortcutTarget).exe").'(Default)'
    }
    else {
        $shortcutTargetPath = $shortcutTarget
        Write-Log -Message "Failed to find target path for $shortcutName"
    }
    $WshShell = New-Object -comObject WScript.Shell
    $masterShortcut = $WshShell.CreateShortcut($shortcutPath)
    $masterShortcut.TargetPath = $shortcutTargetPath
    $masterShortcut.Arguments = $shortcut.shortcutArgs
    $masterShortcut.IconLocation = $iconPath
    $masterShortcut.Description = $($shortcut.version)
    $masterShortcut.WindowStyle = $shortcut.WindowStyle
    $masterShortcut.Hotkey = $shortcut.Hotkey
    $masterShortcut.WorkingDirectory = $shortcut.workingDirectory
    $masterShortcut.Save()
}

function Invoke-GetGroupMembers {
    param (
        [string]$group,
        [string]$accessToken
    )
    $membersList = @()
        # Retrieve group members from Microsoft Graph
        $getGroupMembersUrl = "https://graph.microsoft.com/v1.0/groups/$group/members"
        $headers = @{
            Authorization    = "Bearer $accessToken"
            ConsistencyLevel = "eventual"
        }
        $members = @()
        do {
            $groupMembers = Invoke-RestMethod -Uri $getGroupMembersUrl -Headers $headers -Method GET -ContentType "application/json"
            $members += $groupMembers.value | Select-Object '@odata.type', userPrincipalName, displayName
            $getGroupMembersUrl = $groupMembers.'@odata.nextLink'
        } while ($getGroupMembersUrl)
        Write-Log -Message "$group members: $($members.Count)"
        foreach ($member in $members) {
            if ($($member.'@odata.type') -eq "#microsoft.graph.user") {
                $membersList += $member.userPrincipalName.Replace("@richmond.k12.nc.us", "")
            } 
            if ($($member.'@odata.type') -eq "#microsoft.graph.device") {
                $membersList += $member.displayName
            } 
        }
    return $membersList
}

function Invoke-GetUsersGroups {
    param(
        [string]$username
    )
    # Get a list of JSON files in the directory
    $jsonFiles = Get-ChildItem $userGroupsPath -Filter *.json

    # Initialize an empty list to store group names the user is in
    $userGroups = @()

    # Loop through each file and check if $username is found in the file
    foreach ($jsonFile in $jsonFiles) {
        $userInGroup = $null
        $groupID = $null
        $groupID = $jsonFile.BaseName
        $userInGroup = Get-Content -Path $jsonFile.FullName | Where-Object { $_ -eq $username }
        if ($userInGroup) {
            $userGroups += $groupID  # Add the file name (without .json) to the array
        }
    }
    return $userGroups
}

function Invoke-IconDownload {
    param(
        [object]$jsonData
    )
    $iconKeys = @()

    foreach ($shortcut in $jsonData.deployedShortcuts) {
        $iconKeys += $shortcut.iconKey
    }

    $iconKeys
}

####################
# Start Script
####################

Write-Log -Message "Starting $scriptName"

####################
# Variables
####################

$orgFolder = Join-Path $env:ProgramData $orgName
$shortcutFolder = Join-Path $orgFolder "Shortcuts"
$shortcutReferenceFile = Join-Path $shortcutFolder "deployments.json"
$userGroupsPath = Join-Path $shortcutFolder "Groups"
$referenceFilePath = Join-Path $shortcutFolder $shortcutReferenceFile
$remediationFilePath = Join-Path $shortcutFolder "remediation.json"

####################
# Upkeep
####################

# Remove the remediation file if it exists
if (Test-Path $remediationFilePath) {
    Remove-Item $remediationFilePath -Force
}

# Check if the directory exists; if not, create it
if (-not (Test-Path -Path $shortcutFolder -PathType Container)) {
    New-Item -Path $shortcutFolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $userGroupsPath -PathType Container)) {
    New-Item -Path $userGroupsPath -ItemType Directory -Force
}

####################
# Get Data
####################

# Get the local file's content and the remote file's Last-Modified header to see if it needs to be updated
$updateFile = $true
if (Test-Path $referenceFilePath) {
    $response = Invoke-WebRequest -Uri $jsonUrl -Method Head -UseBasicParsing
    $remoteLastModified = [DateTime]::ParseExact($response.Headers["Last-Modified"], "ddd, dd MMM yyyy HH:mm:ss 'GMT'", $null)
    if ((Get-Item $referenceFilePath).LastWriteTimeUtc -ge $remoteLastModified) {
        $updateFile = $false
    }
}

# Download the file if not already present or it needs to be updated
if ($updateFile) {
    Write-Log -Message "Updating $referenceFilePath because it does not exist or the remote file is newer"
    Invoke-WebRequest -Uri $jsonUrl -Method Get -ContentType "application/json" -OutFile $referenceFilePath
}
else {
    Write-Log -Message "Reference file is up to date"
}

# Load the JSON data from the file
$jsonData = Get-Content $referenceFilePath -Raw | ConvertFrom-Json

# Get MSGraph Access Token
$accessToken = Get-AccessToken -tenantID $tenantID -appID $appID -appSecret $appSecret

####################
# Main Logic
####################

# Initialize an empty array to store the group IDs
$allGroups = @()

# Loop through $jsonData.deployedShortcuts
foreach ($shortcut in $jsonData.deployedShortcuts) {
    # Check if the 'groups' property is an array and not empty
    if ($shortcut.groups -is [array] -and $shortcut.groups.Count -gt 0) {
        # Add the group ID(s) to $allGroups
        $allGroups += $shortcut.groups
    }
}
foreach ($group in $allGroups) {
    $updateGroups = $true
    $groupReferenceFile = Join-Path $userGroupsPath "$group.json"
    if (Test-Path $groupReferenceFile) {
        if ((Get-Item $groupReferenceFile).LastWriteTime -ge (Get-Date).AddDays(-4)) {
            $updateGroups = $false
        }
    }
    if ($updateGroups -and $group -ne "All Devices") {
        $membersList = @()
        $membersList = Invoke-GetGroupMembers -group $group -accessToken $accessToken
        Set-Content -Path $groupReferenceFile -Value $membersList -Encoding UTF8
    }
}

# Get a list of directories in C:\Users, excluding the default folders, and store the names in an array
$userProfiles = Invoke-GetAllUsers -OneDrive $OneDrive -OneDriveCommercial $OneDriveCommercial

# Loop through each user and get the groups they are in
foreach ($user in $userProfiles) {
    $userGroups = $null
    $userGroups = Invoke-GetUsersGroups -username $user.UserName
    Add-Member -InputObject $user -MemberType NoteProperty -Name "Groups" -Value $userGroups
}

$shortcutsToDelete = @()
$shortcutsToAdd = @() 
$masterShortcutFolder = Join-Path $shortcutFolder "Shortcuts" 
if (!(Test-Path $masterShortcutFolder)) {
    New-Item -Path $masterShortcutFolder -ItemType Directory -Force
}

foreach ($shortcut in $jsonData.deployedShortcuts) {
    $iconName = "$($shortcut.iconKey).ico"
    $iconPath = Join-Path $shortcutFolder $iconName
    $masterShortcutPath = Join-Path $masterShortcutFolder "$($shortcut.name).lnk" 
    $iconURL = ($jsonData.shortcutIcons | Where-Object { $_.name -eq $($shortcut.iconKey) }).icoURL

    if (!(Test-Path $iconPath)){
        Write-Log -Message "Downloading icon $iconName from $iconURL because it does not exist locally"
        Invoke-WebRequest -Uri $iconUrl -Method Get -ContentType "application/json" -OutFile $iconPath
    }
    else {
        $localIcon = Get-Item $iconPath
        $remoteIcon = Invoke-WebRequest -Uri $iconUrl -Method Head -UseBasicParsing
        $remoteLastModified = [DateTime]::ParseExact($remoteIcon.Headers["Last-Modified"], "ddd, dd MMM yyyy HH:mm:ss 'GMT'", $null)
        if ($localIcon.LastWriteTimeUtc -lt $remoteLastModified) {
            Write-Log -Message "Updating icon $iconName from $iconURL because it is out of date"
            Invoke-WebRequest -Uri $iconUrl -Method Get -ContentType "application/json" -OutFile $iconPath
        }
        else {
            Write-Log -Message "Icon $iconName is up to date"
        }
    }
    
    $createNewReferenceShortcut = $true
    if (Test-Path $masterShortcutPath) {
        $obj = New-Object -ComObject WScript.Shell
        $existingShortcut = $obj.CreateShortcut($masterShortcutPath)
        if ($existingShortcut.Description -eq $shortcut.version) {
            Write-Log -Message "Master shortcut for $($shortcut.name).lnk is up to date"
            $createNewReferenceShortcut = $false
        }
    }
    if ($createNewReferenceShortcut) {
        Write-Log -Message "Updating master shortcut for $($shortcut.name).lnk because it does not exist or the remote file is newer"
        Invoke-CreateShortcut -shortcutTarget $shortcut.Target -iconPath $iconPath -shortcutPath $masterShortcutPath -shortcutArgs $shortcut.shortcutArgs -version $shortcut.version -workingDirectory $shortcut.workingDirectory -WindowStyle $shortcut.WindowStyle -Hotkey $shortcut.Hotkey
    }

    foreach ($user in $userProfiles) {
        $startMenuShortcutPath = $null
        $desktopStartMenuPath = $null
        $startMenuShortcutPath = Join-Path $user.StartMenuPath $shortcut.Name
        $desktopStartMenuPath = Join-Path $user.DesktopPath $shortcut.Name

        if ($shortcut.users -contains $user.UserName -or ($userGroups | ForEach-Object { $_ -in $shortcut.groups })) {
            if ($shortcut.desktop) {
                if (!(Test-Path $desktopStartMenuPath) -or $createNewReferenceShortcut) {
                    $shortcutsToAdd += @{
                        path = $masterShortcutPath
                        destination = $desktopStartMenuPath
                    }
                    Write-Log -Message "Current shortcut $($shortcut.name).lnk is missing from $desktopStartMenuPath"
                }
            }
            else {
                if (Test-Path $desktopStartMenuPath) {
                    $shortcutsToDelete += $desktopStartMenuPath
                    Write-Log -Message "Current shortcut $($shortcut.name).lnk is not supposed to be in $desktopStartMenuPath"
                } 
            }
            if ($shortcut.startMenu) {
                if (!(Test-Path $startMenuShortcutPath) -or $createNewReferenceShortcut) {
                    $shortcutsToAdd += @{
                        path = $masterShortcutPath
                        destination = $startMenuShortcutPath
                    }
                    Write-Log -Message "Current shortcut $($shortcut.name).lnk is missing from $($user.UserName)'s start menu"
                } 
            }
            else {
                if (Test-Path $startMenuShortcutPath) {
                    $shortcutsToDelete += $startMenuShortcutPath
                    Write-Log -Message "Current shortcut $($shortcut.name).lnk is not supposed to be on $($user.UserName)'s start menu"
                } 
            }
        } else {
            if (Test-Path $desktopStartMenuPath) {
                $shortcutsToDelete += $desktopStartMenuPath
                Write-Log -Message "Expired shortcut $($shortcut.name).lnk is present at $desktopStartMenuPath"
            } 
            if (Test-Path $startMenuShortcutPath) {
                $shortcutsToDelete += $startMenuShortcutPath
                Write-Log -Message "Expired shortcut $($shortcut.name).lnk is present at $desktopStartMenuPath"
            } 
        }
    }
}  
if ($shortcutsToAdd.Count -gt 0 -or $shortcutsToDelete.Count -gt 0) {
    Write-Log -Message "Creating remediation file"
    $remediationActions = @{
        delete = $shortcutstodelete
        create = $shortcutstoadd
    }
    
    $json = $remediationActions | ConvertTo-Json -Depth 4
    
    Set-Content -Path $remediationFilePath -Value $json -Encoding UTF8
}

if (Test-Path $remediationFilePath) {
    Write-Output "Remediation Required"
    Write-Log -Message "Remediation Required"
    Exit 1
} else {
    Write-Output "No Remediation Required"
    Write-Log -Message "No Remediation Required"
    Exit 0
}



