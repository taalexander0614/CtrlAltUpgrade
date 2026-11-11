# Auto Apply Settings from JSON

`UpdateConfig.ps1` keeps an application's JSON settings files in line with copies you publish to Azure Blob Storage. It keeps a reference copy in the user's AppData; when the published file changes, it downloads it and updates the app's local settings and the reference.

The `Power Toys - Fancy Zones Example` folder shows it with PowerToys FancyZones layouts (`custom-layouts.json`, `default-layouts.json`, `settings.json`).

Set the blob storage URL, the app's settings folder and the file names at the top of the script. Run in the user context.
