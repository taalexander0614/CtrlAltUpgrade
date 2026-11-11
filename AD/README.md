# Active Directory

PowerShell scripts for Active Directory housekeeping. All need the **ActiveDirectory** module (RSAT) and were tested on Windows 10 with PowerShell 5.1.

| Script | What it does |
|---|---|
| `DynamicUserSecurityGroups.ps1` | Keeps a security group in sync with inclusion and exclusion rules (for example `employeeType=Student`), adding matching enabled users and removing ones that no longer match. Logs every change. |
| `OU-SecurityGroupSync.ps1` | Syncs the users or computers in a list of OUs into a security group, removing members that are no longer in those OUs. |
| `FindUnderUsedGroups.ps1` | Lists security groups that are empty or have fewer members than a threshold, in a grid view, so you can decide what to clean up. Report only. |
| `FindUnderUsedOUs.ps1` | Lists childless OUs with fewer objects than a threshold. Report only. |
| [`Print Group Management GUI/`](Print%20Group%20Management%20GUI/) | A Windows Forms tool that lets school staff add and remove people from their building's printer groups. |

The two sync scripts make changes: run them against a test group first and check the log. The two "Find" scripts only report.
