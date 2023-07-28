<#
.SYNOPSIS
This script creates icons and shortcuts for accessing network shares based on user-specific settings stored in a JSON file hosted on Azure Blob Storage.

.DESCRIPTION
The script reads user-specific icon settings from a JSON file hosted on Azure Blob Storage. It then creates icons for each user's network shares and sets up desktop shortcuts to open the network shares.

The script operates in the following way:

1. Fetches the user-specific icon settings from the Azure Blob Storage JSON file.
2. Downloads the necessary icon files and saves them in the user's AppData directory.
3. Creates individual PowerShell scripts for each user's icons based on the settings.
4. Sets up desktop shortcuts for each user to execute the corresponding PowerShell script.

.PARAMETERS
None. The script uses predefined variables at the top to specify the Azure Blob Storage URL and the JSON file containing user-specific icon settings.

.INPUTS
The script does not accept any inputs.

.OUTPUTS
The script does not return any outputs. It creates icons, scripts, and shortcuts based on the user-specific settings.

.EXAMPLE
PS> .\fileshares.ps1

.NOTES
This script was created to automate the process of setting up user-specific icons and shortcuts for accessing network shares in my organization's environment. Update the variables at the top of the script as necessary to suit your needs.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/IconShareAutomation
#>

# Azure Storage details
$storageAccountName = "storageaccount"
$containerName = "container"
$jsonFileName = "JSONFilePath.json"

function CreateScriptContent {
    param($iconName, $networkSharePath)

    @"
# This is an automatically generated script for $iconName
# Do not modify manually

# Check if the network share is accessible
if (Test-Path "$networkSharePath") {
    # Open the network share in File Explorer
    Invoke-Item "$networkSharePath"
}
else {
    # Show a message box notifying the user they are not on the company network
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("You are not connected to the company network. Please connect to the company network to access the file share.", "Network Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}
"@
}

# Fetch the logged-in username
$username = $env:USERNAME

# Generate the URL for the JSON file
$jsonDataUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/$jsonFileName"

try {
    # Download the JSON file
    $jsonData = Invoke-RestMethod -Uri $jsonDataUrl -Method Get

    # Find the network share settings for the current user
    $userNetworkShares = $jsonData.NetworkShares | Where-Object { $_.Users -contains $username }

    # Process each network share settings for the current user
    foreach ($userNetworkShare in $userNetworkShares) {
        $iconName = $userNetworkShare.IconName
        $iconUrl = $userNetworkShare.IconUrl
        $networkSharePath = $userNetworkShare.NetworkSharePath

        # Save the icon files to the AppData folder
        $appDataPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)
        $iconsFolderPath = Join-Path $appDataPath "RCS\Icons"
        New-Item -ItemType Directory -Force -Path $iconsFolderPath | Out-Null

        $iconPath = Join-Path $iconsFolderPath "$iconName.ico"

        # Check if the icon file already exists
        if (-not (Test-Path -Path $iconPath)) {
            (New-Object System.Net.WebClient).DownloadFile($iconUrl, $iconPath)
        }
        else {
            Write-Host "Icon file '$iconName.ico' already exists. Skipping download."
        }

        # Create the script content
        $scriptContent = CreateScriptContent -iconName $iconName -networkSharePath $networkSharePath

        # Save the script to %appdata%\RCS\Icons folder
        $scriptFilePath = Join-Path $iconsFolderPath "$iconName.ps1"

        # Check if the script file already exists
        if (-not (Test-Path -Path $scriptFilePath)) {
            $scriptContent | Out-File -FilePath $scriptFilePath -Encoding UTF8
        }
        else {
            Write-Host "Script file '$iconName.ps1' already exists. Skipping script creation."
        }

        # Create the desktop shortcut
        $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
        $shortcutPath = Join-Path $desktopPath "$iconName.lnk"

        # Check if the shortcut file already exists
        if (-not (Test-Path -Path $shortcutPath)) {
            $WshShell = New-Object -ComObject WScript.Shell
            $shortcut = $WshShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptFilePath`""
            $shortcut.IconLocation = $iconPath
            $shortcut.Save()
        }
        else {
            Write-Host "Shortcut file '$iconName.lnk' already exists. Skipping shortcut creation."
        }
    }

    if (-not $userNetworkShares) {
        Write-Host "No icons found for user '$username'."
    }
}
catch {
    Write-Host "Error occurred while downloading or processing the JSON data: $($_.Exception.Message)"
}
