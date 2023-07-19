# Delete Registry Keys Proactive Remediation Scripts

This directory contains two PowerShell scripts used for proactive remediation of registry keys in an Intune environment. These scripts are part of the CtrlAltUpgrade project, a collection of scripts and tools for K-12 systems administrators.

## Scripts

### `Detection.ps1`

This script checks for the presence of specified registry keys and logs their existence. It includes a logging function `Write-Log` that logs messages based on the priority of logging level. The log files are created in a directory based on the user or system context.

The script iterates through the specified registry keys and checks if they exist. If a key exists, the script logs the information and exits with code 1. If no keys are found, it logs the information and exits with code 0.

### `Remediation.ps1`

This script is similar to the `Detection.ps1` script but it actually removes the registry keys if they exist. It uses the same `Write-Log` function for logging.

The script iterates through the specified registry keys and checks if they exist. If a key exists, the script attempts to remove it and logs the information.

## Usage

To use these scripts, you should upload them to your Intune environment and set them up as Proactive Remediations. The `Detection.ps1` script should be set as the detection script, and the `Remediation.ps1` script should be set as the remediation script.

You can customize the scripts by modifying the `$keyPaths` array to specify the registry keys you want to delete.

Please note that these scripts require PowerShell version 5.1 or above.

## Author

Timothy Alexander

[GitHub](https://github.com/taalexander0614/CtrlAltUpgrade)
