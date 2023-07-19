# Update Apps Proactive Remediation Scripts

This directory contains two PowerShell scripts used for proactive remediation of software updates in an Intune environment. These scripts are part of the CtrlAltUpgrade project, a collection of scripts and tools for K-12 systems administrators.

## Scripts

### `Detection.ps1`

This script uses the Winget command-line tool to check for available updates and performs upgrades based on specified conditions. It allows excluding certain packages from being updated and specifies version requirements for updates.

The script includes a logging function `Write-Log` that logs messages based on the priority of logging level. The log files are created in a directory based on the user or system context.

The `Get-SoftwareUpgradeList` function is used to get a list of software that can be upgraded. It uses the Winget command-line tool to check for available updates.

The script then iterates through the software upgrade list and checks if updates are available for each package. It also checks if updates are allowed for the package based on the `$noUpdates` array and the `$programs` array. If updates are available, the script logs the information and exits with code 1. If no updates are available, it logs the information and exits with code 0.

### `Remediation.ps1`

This script is similar to the `Detection.ps1` script but it actually performs the upgrades if updates are available and allowed. It uses the same `Write-Log` function for logging and the `Get-SoftwareUpgradeList` function to get the list of software that can be upgraded.

The script then iterates through the software upgrade list and checks if updates are available for each package. It also checks if updates are allowed for the package based on the `$noUpdates` array and the `$programs` array. If updates are available and allowed, the script performs the upgrade using the Winget command-line tool and logs the information.

## Usage

To use these scripts, you should upload them to your Intune environment and set them up as Proactive Remediations. The `Detection.ps1` script should be set as the detection script, and the `Remediation.ps1` script should be set as the remediation script.

You can customize the scripts by modifying the `$programs` array to specify the programs and their required versions for updates, and the `$noUpdates` array to specify the package IDs for which updates should be skipped.

Please note that these scripts require the Winget command-line tool to be installed and available in the system's PATH, and they require PowerShell version 5.1 or above.
