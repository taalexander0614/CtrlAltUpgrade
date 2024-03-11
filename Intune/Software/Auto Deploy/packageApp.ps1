$tempFolder = "C:\IntuneAppFactory\Temp"
$AppName = "MicrosoftEdge"
$AppURL = "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/8ec28e1e-d2ae-4d26-b1e6-324aa5318db1/MicrosoftEdgeEnterpriseX64.msi"
$desiredPlatform = "Windows"
$desiredChannel = "Stable"
$desiredRelease = "Enterprise"
$desiredArchitecture = "x64"
# Get installer file name using the URL and type using the extension
$InstallerFileName = $AppURL -replace '^.*\/', ''
$InstallerType = $InstallerFileName -replace '^.*\.', ''

function Invoke-IntuneWinPackager {
    param (
        [string]$appName,
        [string]$appURL,
        [string]$installerFileName,
        [string]$installerType,
        [string]$intuneWinAppUtilPath,
        [string]$tempFolder
    )

    # Build paths dynamically
    $InstallerFolder = Join-Path $tempFolder "InputFolder\$AppName"
    $InstallerPath = Join-Path $installerFolder "$InstallerFileName.$InstallerType"
    $OutputFolder = Join-Path $tempFolder "OutputFolder\$AppName"

    # Create the installer folder if it doesn't exist
    if (-not (Test-Path $InstallerFolder)) {
        New-Item -ItemType Directory -Path $InstallerFolder | Out-Null
    }

    # Download the installer using webClient
    Write-Host "Downloading installer..."
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($appURL, $InstallerPath)

    # Check if the installer file exists
    if (-not (Test-Path $InstallerPath)) {
        Write-Error "Installer file not found. Make sure the path is correct."
        return
    }

    # Create the output folder if it doesn't exist
    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    # Build the command to package the installer
    $CommandLine = "$IntuneWinAppUtilPath -c $InstallerFolder -s $InstallerPath -o $OutputFolder"

    # Execute the command
    Invoke-Expression $CommandLine

    Write-Host "Installer packaged successfully. IntuneWin file created in: $OutputFolder"
}

$rootPath = "C:\IntuneAppFactory"
$toolsPath = Join-Path $rootPath "Tools"
$intuneWinAppUtilPath = Join-Path $toolsPath "IntuneWinAppUtil.exe"
$IntuneWinAppUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.5.zip"

if (-not (Test-Path $toolsPath)) {
    New-Item -ItemType Directory -Path $toolsPath | Out-Null
}

if (-not (Test-Path $intuneWinAppUtilPath)) {
    Write-Host "IntuneWinAppUtil.exe not found. Downloading..."
    # Generate temporary file and folder
    $TempFolder = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "IntuneWinAppUtilTemp")
    $ZipFilePath = Join-Path $TempFolder "IntuneWinAppUtil.zip"
    $ExtractedFolderPath = Join-Path $TempFolder "ExtractedFolder"

    # Download the zip file
    Invoke-WebRequest -Uri $IntuneWinAppUrl -OutFile $ZipFilePath

    # Check if the zip file exists
    if (-not (Test-Path $ZipFilePath)) {
        Write-Error "Zip file not found. Make sure the path is correct."
        return
    }

    # Create the folder to extract files if it doesn't exist
    if (-not (Test-Path $ExtractedFolderPath)) {
        New-Item -ItemType Directory -Path $ExtractedFolderPath | Out-Null
    }

    # Unzip the contents
    Write-Host "Extracting files..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFilePath, $ExtractedFolderPath)

    Write-Host "Files extracted to: $ExtractedFolderPath"

    # Copy the IntuneWinAppUtil.exe file to the tools folder, automatically determining the name of the folder
    $IntuneWinAppUtilFolder = Get-ChildItem -Path $ExtractedFolderPath | Where-Object {$_.PSIsContainer}
    $IntuneWinAppUtilPath = Join-Path $IntuneWinAppUtilFolder.FullName "IntuneWinAppUtil.exe"
    Copy-Item -Path $IntuneWinAppUtilPath -Destination $toolsPath -Force
    $intuneWinAppUtilPath = Join-Path $toolsPath "IntuneWinAppUtil.exe"


    # Optionally, clean up the temporary folder when done
    Remove-Item -Path $TempFolder -Recurse -Force
}

if(-not (Test-Path $rootPath)) {
    New-Item -ItemType Directory -Path $rootPath | Out-Null
}


if (-not (Test-Path $tempFolder)) {
    New-Item -ItemType Directory -Path $tempFolder | Out-Null
}


$evergreenApiBaseUrl = "https://evergreen-api.stealthpuppy.com/app/"

# Construct the full API URL for the specific app
$url = $evergreenApiBaseUrl + $appName
Write-Host $url

# Call the Evergreen API and get the response
$appInfo = Invoke-RestMethod -Uri $url

# Find the matching installer URL
$matchingInstaller = $appInfo | Where-Object {
    $_.Platform -eq $desiredPlatform -and
    $_.Channel -eq $desiredChannel -and
    $_.Release -eq $desiredRelease -and
    $_.Architecture -eq $desiredArchitecture
}

if ($null -ne $matchingInstaller) {
    Write-Host "Matching Installer URL: $($matchingInstaller.URI)"
    Invoke-IntuneWinPackager -AppName $AppName -AppURL $matchingInstaller.URI -InstallerFileName $InstallerFileName -InstallerType $InstallerType -IntuneWinAppUtilPath $IntuneWinAppUtilPath -tempFolder $tempFolder
} else {
    Write-Warning "No matching installer found for the specified criteria."
}
