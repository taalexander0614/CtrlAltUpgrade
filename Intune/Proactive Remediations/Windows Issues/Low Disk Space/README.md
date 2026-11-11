# Low Disk Space

Keeps low-storage student devices usable. Written after Autopilot resets kept leaving large `Windows.old` folders behind, so a freshly reset device still had no space.

A full cleanup takes longer than Intune allows a remediation script to run, so this works differently from a normal pair:

| Script | What it does |
|---|---|
| `ScheduledDisk-CleanupDetection.ps1` | Run as the Remediation's detection script. Flags devices with low free space (so you can track how many there are) and sets up a scheduled task that runs the cleanup. |
| `ScheduledDisk-CleanupRemediation.ps1` | Run by that scheduled task: DISM restore health and component cleanup, Windows Update cache removal and `cleanmgr`, then removes the batch file that launched it. |

The script itself calls this "probably super excessive for most situations". It's aimed at small drives that keep filling up. Most scripts log to an organization folder (`$env:ProgramData\<org>` or `%APPDATA%\<org>`) and expect you to set the variables at the top (organization name, URLs, IDs) for your environment. Test in a pilot group before deploying widely.
