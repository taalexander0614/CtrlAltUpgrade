param (
    # Evergreen API Data
    [Parameter(Mandatory=$true)]
    [string]$appName,
    [string]$platform,
    [string]$type,
    [string]$language,
    [string]$architecture,
    [string]$installerType,
    [string]$date,
    [string]$size,
    [string]$channel,
    [string]$sha256,
    [string]$release,
    [string]$hash,
    # Not API Data
    [string]$customArgs,
    [switch]$Uninstall
)

$otherParams = @{}
$filterParams = $PSBoundParameters
# Array of parameter names to exclude
$excludedParams = @("customArgs", "Uninstall")

foreach ($excludedParam in $excludedParams) {
    if ($excludedParam -in $filterParams.Keys) {
        # Move the parameter to $otherParams
        $otherParams[$excludedParam] = $filterParams[$excludedParam]
        $filterParams.Remove($excludedParam)
    }
}

function Get-AppDownloadUrl {
    param (
        [hashtable]$filterParams
    )

    $evergreenApiBaseUrl = "https://evergreen-api.stealthpuppy.com/app/"

    # Construct the full API URL for the specific app
    $url = $evergreenApiBaseUrl + $appName
    Write-Host $url

    # Call the Evergreen API and get the response
    $response = Invoke-RestMethod -Uri $url

    # Convert the response to JSON and display it
    Write-Host "API Response:`n$(ConvertTo-Json $response -Depth 5)"

    # Remove the "appName" key from the $filterParams hashtable
    $filterParams.Remove("appName")

    # Filter the response based on the filter hash table
    $filteredVersions = @()

    # Filter by architecture priority (specified or system architecture)
    $architectures = @()
    if ($architecture) {
        $architectures += $architecture
    } else {
        $architectures += Get-SystemArchitecture
    }

    foreach ($architecture in $architectures) {
        foreach ($version in $response) {
            # Skip filtering for the appName key
            if ($version.Version -eq $appName) {
                continue
            }

            $match = $true
            foreach ($key in $filterParams.Keys) {
                if ($filterParams[$key] -and $version.$key -ne $filterParams[$key]) {
                    $match = $false
                    break
                }
            }
            if ($match -and $version.Architecture -eq $architecture) {
                $filteredVersions += $version
                break
            }
        }

        if ($filteredVersions.Count -gt 0) {
            break
        }
    }

    Write-Host "Pre-Follow Up Results:`n$filteredVersions"

    # If no versions match with all specified criteria, try with lower architectures and file types
    if ($filteredVersions.Count -eq 0) {
        $architectures = @("x64", "x86", "ARM64")
        $fileTypes = @(".msi", ".exe")

        foreach ($architecture in $architectures) {
            foreach ($fileType in $fileTypes) {
                $filteredVersions = $response | Where-Object {
                    $_.Architecture -eq $architecture -and $_.Type -eq $fileType
                }

                if ($filteredVersions.Count -gt 0) {
                    break
                }
            }

            if ($filteredVersions.Count -gt 0) {
                break
            }
        }
    }

    Write-Host "Post-Follow Up Results:`n$filteredVersions"
    if ($filteredVersions.Count -eq 0) {
        Write-Host "No entries found for the specified criteria." -ForegroundColor Yellow
        return $null
    }

    # Get the download URL from the first (and only) version
    $downloadUrl = $filteredVersions[0].URI
    Write-Host $downloadUrl

    # Return the download URL
    return $downloadUrl
}

# Function to download the installer using WebClient
function Invoke-InstallerDownload {
        param (
        [hashtable]$filterParams
    )

    try {
        # Get the download URL for the specific app and parameters
        $url = Get-AppDownloadUrl -filterParams $filterParams
        if (-not $url) {
            Write-Host "App '$appName' not found or no entries found for the specified parameters." -ForegroundColor Yellow
            return
        }

        # Create a temporary directory to store the downloaded installer
        $fileName = Split-Path -Leaf $url
        $outputPath = Join-Path -Path $env:TEMP -ChildPath $fileName

        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $outputPath)

        Return $outputPath
    } 
    catch {
        Write-Error "Error downloading installer: $_"
    }
}

# Function to install the application
function Install-App {
    param (
        [hashtable]$otherParams,
        [hashtable]$filterParams
    )

    try {
        # Download the installer
        $installerFile = Invoke-InstallerDownload -filterParams $filterParams
        $installerFile

        # Get the file extension to determine the file type
        $fileType = [System.IO.Path]::GetExtension($installerFile)
        $fileType

        # Install the application
        if ($fileType -eq ".exe") {
            if ($customArgs) {
                Start-Process -FilePath $installerFile -ArgumentList $customArgs -Wait
            }
            else {
                Start-Process -FilePath $installerFile -ArgumentList "/s /v/qn" -Wait
            }
        } 
        elseif ($fileType -eq ".msi") {
            # For MSI installers, we need to use msiexec and pass custom install parameters if provided
            if ($customArgs) {
                $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installerFile /quiet /norestart" -PassThru
                $uninstallProcess.WaitForExit()
            }
            else {
                $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installerFile $customArgs" -PassThru
                $uninstallProcess.WaitForExit()
            }

        }
        # Check for exit code to see if the uninstallation was successful
        if ($uninstallProcess.ExitCode -eq 0) {
            Write-Host "Install complete." -ForegroundColor Green
        } else {
            Write-Host "Install failed with exit code $($uninstallProcess.ExitCode)." -ForegroundColor Red
        }

        # Clean up the downloaded installer file
        Remove-Item $installerFile -Force
    } 
    catch {
        Write-Error "Error installing the application: $_"
    }
}

# Function to uninstall the application
function Uninstall-App {
    param (
        [hashtable]$otherParams,
        [hashtable]$filterParams
    )

    try {
        # Download the installer
        $installerFile = Invoke-InstallerDownload -filterParams $filterParams
        Write-Host "Install file: $installerFile"

        # Get the file extension to determine the file type
        $fileType = [System.IO.Path]::GetExtension($installerFile)
        $fileType

        if ($fileType -eq ".exe") {
            Write-Host "Uninstalling $appName...type exe" -ForegroundColor Yellow
            if ($customArgs) {
                Write-Host "Custom arguments provided: $customArgs" -ForegroundColor Yellow
                Start-Process -FilePath $installerFile -ArgumentList $customArgs -Wait
            }
            else {
                Write-Host "No custom arguments provided" -ForegroundColor Yellow
                Start-Process -FilePath $installerFile -ArgumentList "/uninstall /passive /norestart" -Wait
            }
            Write-Host "Uninstall complete." -ForegroundColor Green
        } 
        elseif ($fileType -eq ".msi") {
            Write-Host "Uninstalling $appName...type msi" -ForegroundColor Yellow
            if ($customArgs) {
                Write-Host "Custom arguments provided: $customArgs" -ForegroundColor Yellow
                $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $installerFile $customArgs" -PassThru
                $uninstallProcess.WaitForExit()
            }
            else {
                Write-Host "No custom arguments provided" -ForegroundColor Yellow
                $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $installerFile /quiet /norestart" -PassThru
                $uninstallProcess.WaitForExit()
            }
            # Check for exit code to see if the uninstallation was successful
            if ($uninstallProcess.ExitCode -eq 0) {
                Write-Host "Uninstall complete." -ForegroundColor Green
            } else {
                Write-Host "Uninstall failed with exit code $($uninstallProcess.ExitCode)." -ForegroundColor Red
            }
        }

        # Clean up the downloaded uninstaller file
        Remove-Item $installerFile -Force
    } 
    catch {
        Write-Error "Error uninstalling the application: $_"
    }
}

# Function to get the system architecture (x86, x64, or ARM)
function Get-SystemArchitecture {
    try {
        $isArm = Get-WmiObject Win32_ComputerSystem | ForEach-Object { $_.SystemType -match "ARM" }

        if ($isArm) {
            return "ARM64"
        } 
        elseif ([System.Environment]::Is64BitOperatingSystem) {
            return "x64"
        } 
        else {
            return "x86"
        }
    } 
    catch {
        Write-Error "Error getting system architecture: $_"
    }
}

# Determine whether to install or uninstall based on the switches
try {
    if ($Uninstall) {
        Uninstall-App -otherParams $otherParams -filterParams $filterParams
    }
    else {
        Install-App -otherParams $otherParams -filterParams $filterParams
    }
} 
catch {
    Write-Error "Error executing the requested operation: $_"
}
