# Auto Deploy (work in progress)

The start of an "app factory" for Intune.

| File | What it does |
|---|---|
| `packageApp.ps1` | Downloads an installer, fetches Microsoft's Win32 Content Prep Tool (`IntuneWinAppUtil.exe`) if needed, and packages the installer into a `.intunewin` file under `C:\IntuneAppFactory`. |
| `apps.json` | The intended input format: tenant/app details for upload, the Evergreen API URL, and a list of apps with version, channel, architecture and download URI. |

Uploading the package to Intune isn't implemented yet. For a finished approach to installing current versions, see [`Evergreen API Install Script`](../Evergreen%20API%20Install%20Script/).
