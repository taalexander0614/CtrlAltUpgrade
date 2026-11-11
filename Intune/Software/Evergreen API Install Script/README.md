# App Installer Script - Readme

This script is designed to help users install or uninstall applications from the Evergreen API using PowerShell. The script takes various parameters to filter and select the appropriate version of the application to install or uninstall. The Evergreen API provides information about available application versions, architectures, sizes, and more.

You can directly look around in the API at [SwaggerHub](https://app.swaggerhub.com/apis/stealthpuppy/evergreen-api/1.0.0#/app/) or look at StealthPuppy's [Evergreen App Tracker](https://stealthpuppy.com/apptracker/) for a list of everything there.

## How to Use the Script

1. **Prerequisites**: Ensure you have PowerShell installed on your system.

2. **Script Execution Policy**: Before running the script, ensure that PowerShell execution policy allows running scripts. If not already set, run the following command in an elevated PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass
```

3. **Script Execution**: To use the script, execute it via PowerShell, passing the required and optional parameters. The only required parameter is `$appName`, which is the name of the application you want to install or uninstall.

4. **Optional Parameters**: While `$appName` is the only required parameter, you will typically want to include additional parameters to ensure you get the specific version of the application you desire. The parameters to include depend on the application and its available versions. Below are the optional parameters you can include:
    - ### Set from the Evergreen API values
        - `$platform`: Specify the platform for which you want to install or uninstall the application (e.g., Windows, macOS, Linux).
        - `$type`: Specify the type of installer used by the application (.exe, .msi).
        - `$language`: Specify the langaue attribute reported by the Evergreen API.
        - `$architecture`: You can specify the architecture of the system on which the application will be installed. Possible values are "x64", "x86", and "ARM64." If not specified, the script will attempt to detect the system architecture automatically.
        - `$installerType`: Specify the type of installer to be used, such as "online" or "offline." This parameter may not be required for all applications.
        - `$date`: Specify the release date of the application version you want to install. This is an optional parameter.
        - `$size`: Specify the size of the application installer. This is an optional parameter.
        - `$channel`: Specify the release channel of the application, such as "stable," "beta," or "dev." This is an optional parameter.
        - `$sha256`: Specify the SHA256 hash value of the application installer. This is an optional parameter.
        - `$release`: Specify the release number or version of the application you want to install. This is an optional parameter.
        - `$hash`: Specify the hash value of the application installer. This is an optional parameter.
    - ### Script Specific
        - `$customArgs`: If the application requires any custom arguments during installation or uninstallation, you can specify them in this parameter. For example, if the installer supports silent installation, you can provide the necessary arguments here.
        - `$uninstall`: Switch to tell the script you want to uninstall the application. The default behavior of the script is to install.

## Script Behavior

The script works as follows:

1. **Get-AppDownloadUrl**: This function communicates with the Evergreen API to get the download URL for the specific app and parameters. It filters the response based on the provided parameters, including architecture, type, and other relevant details.

2. **Invoke-InstallerDownload**: This function calls `Get-AppDownloadUrl` to retrieve the download URL for the application installer. It then downloads the installer using WebClient and returns the path to the downloaded file.

3. **Install-App**: This function handles the installation of the application. It calls `Invoke-InstallerDownload` to get the installer file, determines the file type, and installs the application using appropriate methods (Start-Process for .exe and msiexec for .msi).

4. **Uninstall-App**: This function is similar to `Install-App` but is used to uninstall the application. It retrieves the uninstaller, determines the file type, and uninstalls the application using the appropriate uninstallation commands.

5. **Get-SystemArchitecture**: This function is used to determine the system architecture (x86, x64, ARM64) automatically in case the -architecture parameter was not set.

## Examples

To install an application, use the script as follows:

```powershell
.\install.ps1 -appName "ExampleApp" -platform "Windows" -type ".exe" -channel "stable"
```

To uninstall an application, include the `-Uninstall` switch:

```powershell
.\install.ps1 -appName "ExampleApp" -platform "Windows" -type ".exe" -channel "stable" -Uninstall
```

To deploy Zoom wrapped in an Intunewin, the install command should be like:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -windowstyle hidden -executionpolicy bypass -file .\install.ps1 -appName "Zoom" -platform "meetings" -type "msi" -customArgs '/norestart ZoomAutoUpdate=1 zNoDesktopShortCut=True zConfig="AU2_EnableAutoUpdate=Enabled"'
```

Remember to verify the parameters and values before using the script to ensure correct installation or uninstallation of applications. Also, please note that the Evergreen API URL in the script (`$evergreenApiBaseUrl`) may need to be updated if the API location changes.