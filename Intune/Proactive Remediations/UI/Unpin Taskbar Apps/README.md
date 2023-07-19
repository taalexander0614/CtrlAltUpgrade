# Unpin Taskbar Apps Proactive Remediation Scripts

This directory contains two PowerShell scripts used for managing pinned apps on the taskbar in an Intune environment. These scripts are part of the CtrlAltUpgrade project, a collection of scripts and tools for K-12 systems administrators.

## Scripts

### `Detection.ps1`

This script checks for the presence of specified apps pinned to the taskbar. The apps to be checked are defined in the `$pinnedApps` array within the script. The script will automatically determine whether it is being run in the System or User context and adjust the path to check for the apps accordingly.

If any of the specified apps are found, the script will record the found apps and exit with a status of 1. If no apps are found, the script will exit with a status of 0.

The script outputs logs to a file in a directory specified by the `$orgFolder` variable.

[View Detection.ps1](https://github.com/taalexander0614/CtrlAltUpgrade/blob/main/Intune/Proactive%20Remediations/UI/Unpin%20Taskbar%20Apps/Detection.ps1)

### `Remediation.ps1`

This script unpins apps from the taskbar. The apps to be unpinned are defined in the `$pinnedApps` array within the script. Like the detection script, this script will also automatically determine whether it is being run in the System or User context and adjust the path for the apps accordingly.

The script will attempt to unpin each specified app and log the process. If an app is not pinned, it will be skipped.

The script outputs logs to a file in a directory specified by the `$orgFolder` variable.

[View Remediation.ps1](https://github.com/taalexander0614/CtrlAltUpgrade/blob/main/Intune/Proactive%20Remediations/UI/Unpin%20Taskbar%20Apps/Remediation.ps1)

## Usage

These scripts are designed to be used with the Proactive Remediations feature of Microsoft Intune. The `Detection.ps1` script is used to detect if a configuration is out of the desired state, and the `Remediation.ps1` script is used to bring the configuration back to the desired state.

To use these scripts, you will need to modify the app arrays and other variables at the top of the scripts to suit your needs. The `$pinnedApps` should be the exact names of the apps you wish to unpin. You will also need to check the log folder structure variables to ensure they match what is used in your organization.

These scripts have been tested on Windows 10 and 11 with PowerShell 5.1.

## Author

These scripts were created by Timothy Alexander. You can find more of his work on his [GitHub profile](https://github.com/taalexander0614).
