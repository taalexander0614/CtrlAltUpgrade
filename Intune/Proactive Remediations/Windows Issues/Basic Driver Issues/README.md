# Basic Driver Issues

An Intune Remediation pair for devices with missing or disabled drivers.

| Script | What it does |
|---|---|
| `Detection.ps1` | Uses WMI to find devices with missing or disabled drivers and logs them. Exits 1 if it finds any. |
| `Remediation.ps1` | Searches Windows Update (through the Microsoft.Update API) for pending driver updates, downloads and installs them, and reports whether a reboot is needed. |

Run as SYSTEM. Most scripts log to an organization folder (`$env:ProgramData\<org>` or `%APPDATA%\<org>`) and expect you to set the variables at the top (organization name, URLs, IDs) for your environment. Test in a pilot group before deploying widely.
