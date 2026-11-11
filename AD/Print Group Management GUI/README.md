# Print Group Management GUI

A small Windows Forms app that lets school office staff manage who can print to which classroom printer, by adding and removing users from the printer security groups in their own school's OU. Built when a new printer contract gave every teacher a classroom printer.

| File | What it does |
|---|---|
| `ModifyPrinterGroups.ps1` | The GUI. Finds the signed-in user's school OU, lists the printer groups in that school's printer OU, and offers the school's staff for adding/removing (with search and autocomplete). |
| `Install.ps1` | Puts the GUI on a device: creates the org folders, downloads the script and icon from blob storage, copies the ActiveDirectory module if you packaged one, and creates a desktop shortcut. Can be wrapped as a Win32 app for Intune. |

## The ActiveDirectory module
The GUI needs Microsoft's **ActiveDirectory** PowerShell module. It uses whichever it finds:

1. **RSAT installed on the device** (`Rsat.ActiveDirectory.DS-LDS.Tools`), or
2. **A copy packaged with the installer.** Copy `C:\Windows\System32\WindowsPowerShell\v1.0\Modules\ActiveDirectory` from a machine that has RSAT into this folder before you build the `.intunewin`. `Install.ps1` copies it to `ProgramData\<org>\Scripts\Modules`.

The module isn't included in this repository because it's Microsoft's software, not mine to redistribute.

## Adapting it
The OU layout (school OUs containing Teachers, Office Staff, Classified Staff and a printer-groups OU) and the central-office special case are specific to my district. Edit the OU variables at the top of `ModifyPrinterGroups.ps1`, and the org name and blob URL at the top of `Install.ps1`.
