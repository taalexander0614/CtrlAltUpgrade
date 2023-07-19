<#
.SYNOPSIS
Script to check for available updates using Winget and perform upgrades based on specified conditions.

.DESCRIPTION
This script uses the Winget command-line tool to check for available updates and performs upgrades based on specified conditions. It allows excluding certain packages from being updated and specifies version requirements for updates.

.PARAMETER $programs
An array of objects specifying the programs and their required versions for updates. Each object should have the following properties:
- Name: The name of the program.
- Version: The required version for the update. Leave it empty to allow any available version.

.PARAMETER $noUpdates
An array of package IDs for which updates should be skipped. Packages with matching IDs will not be considered for upgrades.

.NOTES
- Ensure that the Winget command-line tool is installed and available in the system's PATH.
- This script requires PowerShell version 5.1 or above.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Switch that will either update all programs that are not on the skip updates, or limit it to the specified programs
$updateAll = $true

# Comment $programs to allow all available updates for programs not in $noUpdates
$programs = @(
    [PsCustomObject]@{ Name = "Microsoft.Teams"; Version = "1.6.0.0000" },
    [PsCustomObject]@{ Name = "Adobe.Acrobat.Reader.64-bit"; Version = "" }
)

$noUpdates = @(
    "Zoom.Zoom",
    "Microsoft.VCRedist.2015",
    "Google.Chrome"
)


$Global:org = "ORG"
$Global:scriptName = "WinGet AutoUpdate"
$Global:logLevel = "DEBUG" # Valid values are DEBUG, INFO, WARN, ERROR

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

function Get-SoftwareUpgradeList {
    # resolve winget_exe
    $winget_exe = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    if ($winget_exe.count -gt 1) {
        Write-Log -Level "INFO" -Message "WinGet has multiple versions installed, using latest version" 
        $winget_exe = $winget_exe[-1].Path
    }
    if (!$winget_exe) {
        Write-Log -Level "ERROR" -Message "Winget not installed"
        Return 1
    }

    class Software {
        [string]$Name
        [string]$Id
        [string]$Version
        [string]$AvailableVersion
    }

    $upgradeResult = & $winget_exe upgrade | Out-String
    $lines = $upgradeResult.Split([Environment]::NewLine)

    # Find the line that starts with Name, it contains the header
    $fl = 0
    while (-not $lines[$fl].StartsWith("Name")) {
        $fl++
    }

    # Line $i has the header, we can find char where we find ID and Version
    $idStart = $lines[$fl].IndexOf("Id")
    $versionStart = $lines[$fl].IndexOf("Version")
    $availableStart = $lines[$fl].IndexOf("Available")

    # Now cycle through the packages and split accordingly
    $upgradeList = @()
    for ($i = $fl + 1; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line.Length -gt ($availableStart + 1) -and -not $line.StartsWith('-')) {
            $nameRaw = $line.Substring(0, $idStart).TrimEnd()
            $name = $nameRaw -replace '[^\x00-\x7F]', ''
            $id = $line.Substring($idStart).TrimStart('¦ ').Split(' ')[0].TrimEnd()

            # Remove leading "¦" character and trailing spaces from the ID
            $id = $id -replace '^\s*¦', '' -replace '\s+$'

            # Extract the version and available version from the line
            $version = $line.Substring($versionStart, $availableStart - $versionStart).TrimEnd()
            
            if ($line[$versionStart] -eq '<') {
                $version = $line.Substring($versionStart).Split(' ', 3)[0] + ' ' + $line.Substring($versionStart).Split(' ', 3)[1]
            } 
            elseif ($line.Substring($versionStart) -match '^\S\s') {
                $version = $line.Substring($versionStart + 2).Split(' ')[0].TrimEnd()
            }
            else {
                $version = $line.Substring($versionStart).Split(' ')[0]
            }

            $available = [regex]::Matches($line.Substring($availableStart), '\d+(?:\.\d+)+').Value

            $software = [Software]::new()
            $software.Name = $name
            $software.Id = $id
            $software.Version = $version
            $software.AvailableVersion = $available

            $upgradeList += $software
        }
    }
    return $upgradeList
}

Write-Log -Level "INFO" -Message "====================== Start $scriptName Detection Log ======================"

$softwareUpgradeList = Get-SoftwareUpgradeList
#$softwareUpgradeList | Format-Table
    
$updatesAvailable = $null
foreach ($package in $softwareUpgradeList) {
    $skipUpgrade = $noUpdates | Where-Object { $package.Id -like "*$_*" }
    if ($skipUpgrade) {
        Write-Log -Level "WARN" -Message "No updates allowed for $($package.Id)"
    } 
    else {       
        if ($null -ne $programs) {
            $program = $programs | Where-Object { $package.Id -like "*$($_.Name)*" }           
            if ($null -ne $program) {
                if ([string]::IsNullOrEmpty($program.Version)) {
                    Write-Log -Level "DEBUG" -Message "$($package.Id) Update available: Current - $($package.Version), Available - $($package.AvailableVersion)"
                    $updatesAvailable += $package.Id
                }
                elseif ($package.Version -lt $program.Version) {
                    Write-Log -Level "DEBUG" -Message "$($package.Id) Update Available: Enforced version - $($program.Version), Installed version - $($package.Version)"
                    $updatesAvailable += $package.Id
                }
                else {
                    Write-Log -Level "DEBUG" -Message "Version Limited: Enforced version - $($program.Version), Available version - $availableVersion)"
                }
            } 
            else {
                if ($updateAll -eq $true) {
                    Write-Log -Level "DEBUG" -Message "$($package.Id) Update available: Current - $($package.Version), Available - $($package.AvailableVersion)"
                    $updatesAvailable += $package.Id
                }
                else {
                    Write-Log -Level "WARN" -Message "No updates allowed for $($package.Id)"
                }     
            }
        } 
        else {
            Write-Log -Level "DEBUG" -Message "No updates found"
        }
    }
}

if ($updatesAvailable) {
    Write-Log -Level "INFO" -Message "Updates available for $($updatesAvailable.Count) packages"
    Write-Log -Level "INFO" -Message "====================== End $scriptName Detection Log ======================"
    Exit 1
} 
else {
    Write-Log -Level "INFO" -Message "No updates available"
    Write-Log -Level "INFO" -Message "====================== End $scriptName Detection Log ======================"
    Exit 0
}