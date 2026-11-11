# SCCM (Configuration Manager)

| Script | What it does |
|---|---|
| `Imaging/UpdateAutopilotGraph.ps1` | Runs in a task sequence (or standalone): finds the device in Autopilot by serial number through the Graph REST API and updates its display name and group tag from `OSDComputerName` and `GroupTag`. No modules needed, so it works in Windows PE. Background in [this post](https://www.ctrlaltupgrade.com/blog/autopilot-in-sccm-task-sequences/). |
| `Upkeep/Clean Up Devices/CleanupDevicesNotInAD.ps1` | Removes inactive SCCM clients that no longer exist in Active Directory (or Intune, with co-management). |
| `Upkeep/Clean Up Devices/CleanupOldDevices.ps1` | Cleans up duplicate device records across AD, SCCM and Intune after a naming-scheme change, matching on the asset number at the end of the name and keeping the newest. |
| `Upkeep/Device Monitoring/CheckImageDate.ps1` | Reports devices that haven't been reimaged in a set number of years, from the age of the SMSTS log. Use as a detection script or run through SCCM. |

Both cleanup scripts start in audit mode (`$auditOnly = $true`): they only log what they would change. Review the log, then set it to `$false` to make changes.
