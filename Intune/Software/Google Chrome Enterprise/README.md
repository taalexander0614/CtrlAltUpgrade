# Google Chrome Enterprise (Win32 app)

| File | What it does |
|---|---|
| `Intunewin/Chrome.ps1` | Install command (`-action Install`) downloads the current Chrome Enterprise MSI, installs it and removes the desktop shortcut. Uninstall command (`-action Uninstall`) removes Chrome. |
| `Detection.ps1` | Custom detection script: checks the uninstall registry keys for Google Chrome. |

Package the `Intunewin` folder with the Win32 Content Prep Tool and use `Detection.ps1` as the app's detection rule. Most scripts log to an organization folder (`$env:ProgramData\<org>` or `%APPDATA%\<org>`) and expect you to set the variables at the top (organization name, URLs, IDs) for your environment. Test in a pilot group before deploying widely.
