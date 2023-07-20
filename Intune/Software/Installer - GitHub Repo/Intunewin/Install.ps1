<#
.SYNOPSIS
This script is used for installing or uninstalling software in an organization's environment.

.DESCRIPTION
The script first checks if the log directory exists, and if not, it creates the directory. It then logs messages to a log file.

The script operates in two modes: "Install" and "Uninstall".

In "Uninstall" mode, the script checks if the software is installed. If it is, the script attempts to uninstall the software, logging the process along the way.

In "Install" mode, the script downloads the software from a specified GitHub repository, logs the download process, and then installs the software. If a previous installer is detected, it is removed before the new installer is downloaded. After installation, the script checks for a software desktop shortcut and deletes it if it's found. It then cleans up the installer files.

.PARAMETERS
$fileType: The type of the file to download and install or uninstall. Can be "msi" or "exe".
$repoUrl: The URL of the GitHub repository from which to download the file.
$action: The operation to perform. Can be "Install" or "Uninstall".
$installParams: Optional. Additional command-line arguments for the installation command.
$uninstallParams: Optional. Additional command-line arguments for the uninstallation command.
$releaseTag: Optional. The release tag to use when retrieving the software. Defaults to "latest".

.INPUTS
The script does not accept any inputs.

.OUTPUTS
The script does not return any outputs. It writes log messages to a file during the download, installation, or uninstallation process.

.EXAMPLE
PS> .\install.ps1 -fileType "exe" -repoUrl "https://github.com/SafeExamBrowser/seb-win-refactoring" -action "Install"
PS> .\install.ps1 -fileType "exe" -repoUrl "https://github.com/SafeExamBrowser/seb-win-refactoring" -action "Install" -releaseTag "v3.5.0"
PS> .\install.ps1 -fileType "msi" -repoUrl "https://github.com/SafeExamBrowser/seb-win-refactoring" -action "Uninstall"

.NOTES
This script was created for use with my organization's resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
The script will automatically check whether it is running in the user or system context and place the log file accordingly.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("msi", "exe")]
    [string]$fileType,

    [Parameter(Mandatory=$true)]
    [string]$repoUrl,

    [Parameter(Mandatory=$true)]
    [ValidateSet("install", "uninstall")]
    [string]$action,

    [Parameter(Mandatory=$false)]
    [string]$installParams = "",

    [Parameter(Mandatory=$false)]
    [string]$uninstallParams = "",

    [Parameter(Mandatory = $false)]
    [string]$releaseTag = "latest"
)

$Global:org = "ORG"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

# Extract the GitHub repository name from the repoUrl and remove any special characters from the repoName to ensure it is a valid script name
$repoName = [regex]::Match($repoUrl, "(?<=\.com/)(.*?)(?=/)").Value
$scriptName = $repoName -replace "[^a-zA-Z0-9_-]", ""
$Global:scriptName = "GitHub-$scriptName"

# Function to log messages
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

# Function to get the latest release version from a GitHub repository
function Get-ReleaseVersion($repoUrl, $releaseTag) {
    Write-Log -Level "DEBUG" -Message "`$repoURL: $repoURL"
    Write-Log -Level "DEBUG" -Message "`$releaseTag: $releaseTag"
    $apiUrl = $repoUrl -replace "github.com", "api.github.com/repos"
    Write-Log -Level "DEBUG" -Message "`$apiURL: $apiURL"
    if ($releaseTag -eq "latest") {
        $apiUrl = "$apiUrl/releases/latest"
        Write-Log -Level "DEBUG" -Message "`$apiURL: $apiURL"
    } 
    else {
        $apiUrl = "$apiUrl/releases/tags/$releaseTag"
        Write-Log -Level "DEBUG" -Message "`$apiURL: $apiURL"
    }
    $release = Invoke-RestMethod -Uri $apiUrl
    Write-Log -Level "DEBUG" -Message "`$release: $($release.tag_name.Trim('v'))"
    return $release.tag_name.Trim('v')
}

function Get-ReleaseUrl($repoUrl, $releaseTag, $assetName) {
    $apiUrl = $repoUrl -replace "github.com", "api.github.com/repos"
    Write-Log -Level "DEBUG" -Message "Initial `$apiURL: $apiURL"
    if ($releaseTag -eq "latest") {
        $apiUrl = "$apiUrl/releases/latest"
        Write-Log -Level "DEBUG" -Message "`$apiURL: $apiURL"
    }
    else {
        $apiUrl = "$apiUrl/releases/tags/$releaseTag"
        Write-Log -Level "DEBUG" -Message "Completed `$apiURL: $apiURL"
    }
    try {
        $release = Invoke-RestMethod -Uri $apiUrl
        if ($releaseTag -eq "latest") {
            $asset = $release.assets | Where-Object { $_.name -like "*.$fileType" } | Select-Object -First 1
        } 
        else {
            $asset = $release.assets | Where-Object { $_.name -eq "*.$fileType" }
        }
        if ($asset) {
            return $asset.browser_download_url
        } 
        else {
            Write-Log -Level "ERROR" -Message "Asset '$assetName' not found in the release '$releaseTag'"
            return $null
        }
    } 
    catch {
        Write-Log -Level "ERROR" -Message "Failed to retrieve release from GitHub API: $($_.Exception.Message)"
        return $null
    }
}

# Start Script
Write-Log -Level "INFO" -Message "====================== Start $scriptName $action Log ======================"

# Get the URL of the release asset
$file_url = Get-ReleaseUrl -repoUrl $repoUrl -releaseTag $releaseTag -assetName "*.$fileType"

if ($file_url) {
    # Log the URL of the file
    Write-Log -Level "DEBUG" -Message "URL of the $fileType file: $file_url"

    # Define the path where the file will be saved
    $file_path = "$env:TEMP\seb-latest.$fileType"

    # Log the path where the file will be saved
    Write-Log -Level "DEBUG" -Message "Path where the $fileType file will be saved: $file_path"

    # Download the file
    Try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($file_url, $file_path)
        Write-Log -Level "INFO" -Message "Downloaded the $fileType file successfully."
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Error downloading installer: $_"
        Exit 1
    }

    if ($action -eq "install") {
        # Install the file
        if ($fileType -eq "exe") {
            Start-Process -FilePath $file_path -ArgumentList "/S $installParams" -Wait
        }
        else {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $file_path /qn $installParams" -Wait
        }
        Write-Log -Level "INFO" -Message "Installed the $fileType file successfully."
    }
    else {
        # Uninstall the file
        if ($fileType -eq "exe") {
            Start-Process -FilePath $file_path -ArgumentList "/uninstall /S $uninstallParams" -Wait
        }
        else {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $file_path /qn $uninstallParams" -Wait
        }
        Write-Log -Level "INFO" -Message "Uninstalled the $fileType file successfully."
    }

    # Remove the file
    Try {
        Write-Log -Level "DEBUG" -Message "Removing the $fileType file."
        Remove-Item $file_path -Force
        Write-Log -Level "INFO" -Message "Removed the $fileType file successfully."
    }
    Catch {
        Write-Log -Level "ERROR" -Message "Error removing the $fileType file: $_"
    }
}
else {
    Write-Log -Level "ERROR" -Message "Failed to retrieve the download URL for the $fileType file."
}

Write-Log -Level "INFO" -Message "====================== End $scriptName $action Log ======================"

