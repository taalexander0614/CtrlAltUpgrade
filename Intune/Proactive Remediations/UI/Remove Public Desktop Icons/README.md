# Remove Public Desktop Icons Proactive Remediation Scripts

This directory contains two PowerShell scripts used for managing shortcuts on the public desktop in an Intune environment. These scripts are part of the CtrlAltUpgrade project, a collection of scripts and tools for K-12 systems administrators.

## Scripts

### `Detection.ps1`

This script checks for the presence of specified shortcuts on the public desktop. The shortcuts to be checked are defined in the `$iconsToRemove` array within the script. The script will automatically determine whether it is being run in the System or User context and adjust the path to check for the shortcuts accordingly.

If any of the specified shortcuts are found, the script will record the found icons and exit with a status of 1. If no shortcuts are found, the script will exit with a status of 0.

The script outputs logs to a file in a directory specified by the `$orgFolder` variable.

[View Detection.ps1](https://github.com/taalexander0614/CtrlAltUpgrade/blob/main/Intune/Proactive%20Remediations/UI/Remove%20Public%20Desktop%20Icons/Detection.ps1)

### `Remediation.ps1`

This script removes shortcuts from the public desktop. The shortcuts to be removed are defined in the `$iconsToRemove` array within the script. Like the detection script, this script will also automatically determine whether it is being run in the System or User context and adjust the path for the shortcuts accordingly.

The script will attempt to remove each specified shortcut and log the process. If a shortcut does not exist, it will be skipped.

The script outputs logs to a file in a directory specified by the `$orgFolder` variable.

[View Remediation.ps1](https://github.com/taalexander0614/CtrlAltUpgrade/blob/main/Intune/Proactive%20Remediations/UI/Remove%20Public%20Desktop%20Icons/Remediation.ps1)

## Usage

These scripts are designed to be used with the Proactive Remediations feature of Microsoft Intune. The `Detection.ps1` script is used to detect if a configuration is out of the desired state, and the `Remediation.ps1` script is used to bring the configuration back to the desired state.

To use these scripts, you will need to modify the shortcut arrays and other variables at the top of the scripts to suit your needs. The `$iconsToRemove` should be the exact names of the shortcuts you wish to remove; the script will add the `.lnk` or `.url` extension as appropriate. You will also need to check the log folder structure variables to ensure they match what is used in your organization.

These scripts have been tested on Windows 10 and 11 with PowerShell 5.1.

## Author

These scripts were created by Timothy Alexander. You can find more of his work on his [GitHub profile](https://github.com/taalexander0614).
