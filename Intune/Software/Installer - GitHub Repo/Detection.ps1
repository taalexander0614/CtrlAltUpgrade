<#
.SYNOPSIS
This script is used for detecting the installed version of a software and comparing it with the latest version available on a GitHub repository.

.DESCRIPTION
The script retrieves the installed version of the software from the Windows Registry. It then fetches the latest version of the software from the specified GitHub repository using the provided release tag or the latest version if no release tag is specified. Finally, it compares the installed version with the latest version and outputs a message indicating whether the software is installed and up-to-date.

.PARAMETERS
$repoUrl: The URL of the GitHub repository from which to fetch the latest version.
$releaseTag: The release tag or version of the software to retrieve. If not specified, the script fetches the latest version.
$appName: The name of the application as it appears in the Windows Registry.

.INPUTS
The script does not accept any inputs.

.OUTPUTS
The script outputs a message indicating whether the software is installed and up-to-date.

.EXAMPLE
PS> .\DetectionScript.ps1 -repoUrl "https://github.com/SafeExamBrowser/seb-win-refactoring" -releaseTag "latest" -appName "Safe Exam Browser (x64)"

.NOTES
This script assumes that the installed software is registered in the Windows Registry under "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall". If the software is registered differently, you may need to adjust the script accordingly.
The script also assumes that the version number of the software is stored in the 'DisplayVersion' property in the Registry. If this assumption does not hold true for the software you're working with, you may need to adjust the script accordingly.

The script uses a foreach loop to check the 'DisplayName' values within the uninstall keys in case the name is represented by a unique identifier such as '{C6556752-5DC0-436C-9C9E-D64C811F59E1}'.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# The URL of the GitHub repository, the desired release tag, and the name of the application as it appears in the Windows Registry
$repoUrl = "https://github.com/SafeExamBrowser/seb-win-refactoring"
$releaseTag = "latest"
$appName = "Safe Exam Browser (x64)"

$Global:org = "ORG"
$Global:scriptName = "$appName Detection"
$Global:logLevel = "INFO" # Valid values are DEBUG, INFO, WARN, ERROR

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

# Start Script
Write-Log -Level "INFO" -Message "====================== Start $scriptName Log ======================"

# Get the latest version from GitHub
$releaseVersion = Get-ReleaseVersion -repoUrl $repoUrl -releaseTag $releaseTag

# Get the "Uninstall" registry keys
$uninstallKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue

# Check if any of the "Uninstall" keys have the expected display name
$installed = $uninstallKeys | ForEach-Object {
    $displayName = Get-ItemProperty -Path $_.PSPath -Name "DisplayName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "DisplayName"
    $displayVersion = Get-ItemProperty -Path $_.PSPath -Name "DisplayVersion" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "DisplayVersion"   
    if ($displayName -eq $appName -and $displayVersion -ge $releaseVersion) {
        Write-Log -Level "DEBUG" -Message "Found $displayName at version $displayVersion"
        $true
    }
}



# Compare the installed version with the latest version
if ($installed) {
    Write-Output "$appName is installed and up-to-date."
    Write-Log -Level "INFO" -Message "$appName is installed and up-to-date."
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
} 
else {
    Write-Output "$appName is not installed or not up-to-date."
    Write-Log -Level "INFO" -Message "$appName is not installed or not up-to-date."
    Write-Log -Level "INFO" -Message "====================== End $scriptName Log ======================"
}