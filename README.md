# CtrlAltUpgrade

Scripts and tools I've built as a K-12 systems administrator: mostly PowerShell for Intune, SCCM and Active Directory, plus some Ansible, shell and n8n. Many have write-ups on my site, [ctrlaltupgrade.com](https://www.ctrlaltupgrade.com/#writing).

Everything here comes from real use in a school district and has been sanitized: organization names, servers and IDs are placeholders you set at the top of each script. Read a script before you run it, change the variables for your environment, and test on a pilot group first.

[![Lint](https://github.com/taalexander0614/CtrlAltUpgrade/actions/workflows/lint.yml/badge.svg)](https://github.com/taalexander0614/CtrlAltUpgrade/actions/workflows/lint.yml)

## What's inside

### Intune
| Tool | What it does |
|---|---|
| [Printer Deployment](Intune/Device%20Management%20Solutions/Printer%20Deployment/) | Installs and removes printers based on the device's Entra group membership and a JSON config. |
| [Shortcut Deployment](Intune/Device%20Management%20Solutions/Shortcut%20Deployment/) | Desktop and Start menu shortcuts by user or device group, from a JSON config. |
| [File Share Deployment](Intune/Device%20Configuration/Scripts/File%20Share%20Deployment/) | Per-user network share shortcuts with icons, from a JSON file in blob storage. |
| [macOS shell scripts](Intune/Device%20Configuration/MacOS/Shell%20Scripts/) | Stale user cleanup for shared Macs, Adobe custom package install, GMetrix plugins. |
| **Remediations: UI** | [Add Shortcuts](Intune/Proactive%20Remediations/UI/Add%20Shortcuts/) · [Remove Public Desktop Icons](Intune/Proactive%20Remediations/UI/Remove%20Public%20Desktop%20Icons/) · [Remove User Desktop Icons](Intune/Proactive%20Remediations/UI/Remove%20User%20Desktop%20Icons/) · [Unpin Taskbar Apps](Intune/Proactive%20Remediations/UI/Unpin%20Taskbar%20Apps/) |
| **Remediations: Windows** | [Orphaned User Folders](Intune/Proactive%20Remediations/Windows%20Issues/Orphaned%20User%20Folders/) · [Low Disk Space](Intune/Proactive%20Remediations/Windows%20Issues/Low%20Disk%20Space/) · [Basic Driver Issues](Intune/Proactive%20Remediations/Windows%20Issues/Basic%20Driver%20Issues/) · [Delete Registry Keys](Intune/Proactive%20Remediations/Windows%20Issues/Delete%20Registry%20Keys/) · [Windows Activations](Intune/Proactive%20Remediations/Windows%20Issues/Windows%20Activations/) |
| **Remediations: Software** | [Update Apps](Intune/Proactive%20Remediations/Software/Update%20Apps/) (winget upgrades with version pins and exclusions) |
| **Win32 app installers** | [WinGet Installer](Intune/Software/WinGet%20Installer/) · [Evergreen API Install Script](Intune/Software/Evergreen%20API%20Install%20Script/) · [Installer from a GitHub repo](Intune/Software/Installer%20-%20GitHub%20Repo/) · [Google Chrome Enterprise](Intune/Software/Google%20Chrome%20Enterprise/) |
| [Auto Apply Settings from JSON](Intune/Software/Auto%20Apply%20Settings%20from%20JSON/) | Keeps an app's JSON settings in line with copies in blob storage (PowerToys FancyZones example). |
| [Auto Deploy](Intune/Software/Auto%20Deploy/) | Work in progress: download an installer and package it as `.intunewin`. |
| [Upkeep](Intune/Upkeep/) | Graph scripts to remove duplicate device records and clear primary users. |

### SCCM, Active Directory and Microsoft Graph
| Tool | What it does |
|---|---|
| [SCCM](SCCM/) | Autopilot registration from a task sequence, stale and duplicate device cleanup (audit mode by default), image-age reporting. |
| [Active Directory](AD/) | Rule-based and OU-based group sync, reports of under-used groups and OUs, and a printer-group GUI for school staff. |
| [Microsoft Graph modules](Microsoft%20Graph/) | Access token, generic Graph call with paging, delta queries, send mail. |
| [Verkada](Verkada/) | Modules for the Verkada Access Control API: list and change access group membership. |

### Linux and automation
| Tool | What it does |
|---|---|
| [Linux Server Baseline](Ansible/Linux%20Server%20Baseline/) | Re-runnable Ansible baseline for Ubuntu: certificates, SSH, time, updates, Wazuh and Zabbix agents. [Write-up](https://www.ctrlaltupgrade.com/blog/linux-server-baseline-ansible/). |
| [Phishing Triage Score](n8n/Phishing%20Triage%20Score/) | Rule-based score for user-reported phishing in n8n, with a plain-language reason for every point. [Write-up](https://www.ctrlaltupgrade.com/blog/phishing-triage-score/). |

## Conventions
- **Variables at the top.** Each script starts with the values you change: organization name, URLs, tenant and app IDs.
- **Secrets stay out.** Scripts that call Graph or other APIs have placeholders like `<App Secret>`. Supply real values at run time (a secure store, Intune or Semaphore secrets, scheduled-task credentials); never commit them.
- **Logging.** Most PowerShell scripts log to an organization folder in `ProgramData` (SYSTEM) or `AppData` (user), and work out which context they're running in.
- **Detection and remediation pairs.** Intune Remediations folders have `Detection.ps1` and `Remediation.ps1`; detection exits 1 when there's something to fix.
- **Tested on** Windows 10/11 with PowerShell 5.1 unless a script says otherwise.

## Contributing
Issues and pull requests are welcome. Please describe what the change does and how you tested it. A lint check (PSScriptAnalyzer, ShellCheck, YAML and JavaScript syntax) runs on every push and pull request.

## License
GPL-3.0. See [LICENSE](LICENSE).
