# WinGet Installer (Win32 app)

Deploy any app that's in the Windows Package Manager as an Intune Win32 app.

| File | What it does |
|---|---|
| `Intunewin Files/Install.ps1` | Installs or uninstalls `-AppName` with winget (`-Action Install` or `Uninstall`). Optional `-shortcutName` removes the desktop shortcut after install; `-param` passes extra arguments to winget. Finds winget when running as SYSTEM. |
| `Detection Scripts/*.ps1` | Detection scripts for 7-Zip, Safe Exam Browser and VLC. Each checks `winget list` for the program named in `$ProgramName`; copy one and change the name for other apps. |

Package `Intunewin Files` once and reuse it for every app, changing only the install/uninstall command line and the detection script. Most scripts log to an organization folder (`$env:ProgramData\<org>` or `%APPDATA%\<org>`) and expect you to set the variables at the top (organization name, URLs, IDs) for your environment. Test in a pilot group before deploying widely.
