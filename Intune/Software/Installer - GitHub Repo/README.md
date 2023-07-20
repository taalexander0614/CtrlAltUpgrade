# Software Deployment Script

This script is designed for installing or uninstalling software in an organization's environment. It supports downloading files from a specified GitHub repository and performing installation or uninstallation based on the specified action.

## Motivation

This script was created to address the need for automated software deployment during the device enrollment process, specifically for Autopilot scenarios. I was using WinGet to ensure I was always installing the latest version of Safe Exam Browser on devices but during the device enrollment status page for Self Deploy, it was failing a decent amount. I read in a few places that WinGet would not work until after the first time a user logged in (it worked sometimes during the ESP though, so I don't know....). The goal was to provide a reliable method for installing or uninstalling Safe Exam, ensuring that the latest version is deployed to the devices without encountering errors and having to wait for a second or third try once the device is in the hands on end users.

## Prerequisites

- Windows 10 with PowerShell 5.1 or later.

## Usage

1. Download the install script and modify the $Global:ORG variable.

2. Wrap the install script in an intunewin.

3. Deploy as an app with the desired parameters using the following command:

```powershell
.\install.ps1 -fileType <fileType> -repoUrl <repoUrl> -action <action> -installParams <installParams> -uninstallParams <uninstallParams> -releaseTag <releaseTag>
``````

4. Replace the following placeholders with the appropriate values:
    - fileType: The type of the file to download and install or uninstall. Can be "msi" or "exe".
    - repoUrl: The URL of the GitHub repository from which to download the file.
    - action: The operation to perform. Can be "install" or "uninstall".
    - installParams (optional): Additional command-line arguments for the installation command.
    - uninstallParams (optional): Additional command-line arguments for the uninstallation command.
    - releaseTag (optional): The release tag to use when retrieving the software. Defaults to "latest".

5. Download the detection script and update before adding to deployment.


## Examples
Install an executable file from a GitHub repository:
```powershell
.\install.ps1 -fileType "exe" -repoUrl "https://github.com/your-repo/your-app" -action "install"
```
Install a specific version of an executable file from a GitHub repository:
```powershell
.\install.ps1 -fileType "exe" -repoUrl "https://github.com/your-repo/your-app" -action "install" -releaseTag "v1.0"
```

Uninstall an MSI file using a custom uninstallation parameter:
```powershell
.\install.ps1 -fileType "msi" -repoUrl "https://github.com/your-repo/your-app" -action "uninstall" -uninstallParams "/quiet"
```


## Notes
- IMPORTANT: I made this for, and tested it solely with, Safe Exam Browser. That was my current need but I wanted to make something that I could reuse for applications not available in Intune's new Microsoft Store app deployment method.
- This script was created for use in my organization's environment and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
- The script will automatically check whether it is running in the user or system context and place the log file accordingly.
- Tested on Windows 10 with PowerShell 5.1.

## Contributing

Contributions to this repository are welcome. If you encounter any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
