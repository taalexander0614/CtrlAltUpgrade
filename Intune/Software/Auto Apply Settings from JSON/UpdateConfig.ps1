<#
.SYNOPSIS
This script is used for downloading and updating settings via json files from Azure Blob Storage for an application.

.DESCRIPTION
The script first checks if the reference directory exists in the local user's AppData, and if not, it creates the directory. It then logs messages to a log file.

The script downloads JSON settings files from Azure Blob Storage and updates the local settings based on the comparison with the reference files. The script operates in the following way:

1. If the reference file does not exist, the script downloads the JSON settings files from Azure Blob Storage and saves them as the reference.
2. For each JSON settings file in the local directory, the script compares its content with the corresponding reference file.
3. If there is a difference between the local JSON settings file and the reference, the script downloads the JSON settings file from Azure Blob Storage and updates the local settings. It also updates the corresponding reference file.
4. If there is no difference between the local JSON settings file and the reference, the script skips the download and continues to the next file.

.PARAMETERS
None. The script uses predefined variables at the top to specify the Azure Blob Storage URL, local directory, and settings files to download.

.INPUTS
The script does not accept any inputs.

.OUTPUTS
The script does not return any outputs. It writes log messages to a file during the download and update process.

.EXAMPLE
PS> .\UpdateConfig.ps1

.NOTES
This script was created for downloading and updating settings from Azure Blob Storage for an application in my organization's environment. Update the variables at the top of the script as necessary to suit your needs.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

# Set the parameters
$blobBaseUrl = "https://container.blob.core.windows.net/intune/Software/Config/FancyZones"
$localDirectory = "$env:USERPROFILE\AppData\Local\Microsoft\PowerToys\FancyZones"
$settingsFiles = @(
    "settings.json",
    "default-layouts.json",
    "custom-layouts.json"
)

# Function to download file from Azure Blob Storage
function Invoke-SettingsDownload($fileUrl, $destination) {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($fileUrl, $destination)
}

# Function to check if a file needs to be downloaded based on content comparison
function Invoke-SettingsVerification($sourceFile, $destinationFile) {
    $sourceContent = Get-Content $sourceFile | ConvertFrom-Json
    $destinationContent = Get-Content $destinationFile | ConvertFrom-Json

    return ($sourceContent | ConvertTo-Json -Depth 100) -ne ($destinationContent | ConvertTo-Json -Depth 100)
}

# Function to check and update settings
function Invoke-SettingsUpdate() {
    # Create the reference directory if it doesn't exist
    $referenceDirectory = Join-Path $localDirectory "Reference"
    if (-not (Test-Path $referenceDirectory)) {
        New-Item -ItemType Directory -Path $referenceDirectory | Out-Null
    }

    # Check if each settings file exists and compare settings with the reference
    foreach ($file in $settingsFiles) {
        $localFilePath = Join-Path $localDirectory $file
        $referenceFilePath = Join-Path $referenceDirectory "$file.diff"

        # If the reference file exists and has the same content, no need to download
        if ((Test-Path $referenceFilePath) -and (-not (Invoke-SettingsVerification $localFilePath $referenceFilePath))) {
            Write-Host "Skipping download for $file as the content is up-to-date."
            continue
        }

        # Download the file from Azure Blob Storage and update the local settings
        $fileUrl = "$blobBaseUrl/$file"
        Write-Host "Downloading $fileUrl to $localFilePath"
        Invoke-SettingsDownload $fileUrl $localFilePath

        # Save the downloaded content as the reference file
        $localContent = Get-Content $localFilePath | ConvertFrom-Json
        $localContent | ConvertTo-Json -Depth 100 | Out-File -FilePath $referenceFilePath
        Write-Host "Reference content of $file saved to $referenceFilePath."
    }
}

# Run the function to check and update settings
Invoke-SettingsUpdate
