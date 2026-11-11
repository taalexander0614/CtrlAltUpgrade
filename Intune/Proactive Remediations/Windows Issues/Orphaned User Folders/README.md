# Orphaned User Folders

Removes user folders left in `C:\Users` after the account was deleted, which otherwise cause duplicate profile folders and fill small drives. Written up in [Tackling orphaned user folders: a PowerShell solution](https://www.ctrlaltupgrade.com/blog/orphaned-user-folders/).

| Script | What it does |
|---|---|
| `Detection.ps1` | Compares folders in `C:\Users` with the profiles registered in Windows and lists any without a profile (skipping `Public` and the cleanup folder). Exits 1 if it finds any. |
| `Remediation.ps1` | Deletes each orphaned folder, escalating if permissions get in the way: take ownership and grant SYSTEM full control, delete file by file, and finally move anything left into a cleanup folder. |

Tip from the script: run only the detection for a while first and export its output, so you can see which folder names come up before anything is deleted. Run as SYSTEM. Most scripts log to an organization folder (`$env:ProgramData\<org>` or `%APPDATA%\<org>`) and expect you to set the variables at the top (organization name, URLs, IDs) for your environment. Test in a pilot group before deploying widely.
