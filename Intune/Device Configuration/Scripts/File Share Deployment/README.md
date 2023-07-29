# Icon Share Automation

This repository contains a PowerShell script designed to automate the process of setting up user-specific icons and shortcuts for accessing network shares in an organization's environment. The script fetches user-specific icon settings from a JSON file hosted on Azure Blob Storage and creates icons and shortcuts based on these settings.

## Usage

To use the script, follow the instructions below:

1. Clone or download this repository to your local machine.

2. Ensure you have PowerShell installed on your computer.

3. Open the `fileshares.ps1` script in a text editor.

4. Update the following variables at the top of the script to match your Azure Blob Storage details:

   ```powershell
   $storageAccountName = "your_storage_account_name"
   $containerName = "your_container_name"
   $jsonFileName = "your_json_file_path.json"
   ```

   Replace `"your_storage_account_name"` with your Azure Storage account name, `"your_container_name"` with the container name where the JSON file is stored, and `"your_json_file_path.json"` with the actual path to your JSON file in the container.

5. Save the changes to the `fileshares.ps1` script.

6. Open PowerShell and navigate to the folder containing the `fileshares.ps1` script.

7. Execute the script by running the following command:

   ```powershell
   PS> .\fileshares.ps1
   ```

   The script will perform the following steps:

   1. Fetch the logged-in username.
   2. Download the JSON file from Azure Blob Storage.
   3. Find the network share settings for the current user in the JSON data.
   4. Process each network share settings for the current user.
   5. Save the icon files to the user's AppData folder.
   6. Create individual PowerShell scripts for each user's icons.
   7. Set up desktop shortcuts for each user to execute the corresponding PowerShell script.

## JSON Data Structure

The JSON file should have the following structure:

```json
{
  "NetworkShares": [
    {
      "IconName": "Icon1",
      "IconUrl": "https://your_icon_url1.ico",
      "NetworkSharePath": "\\\\server\\share1",
      "Users": [
        "User1",
        "User2"
      ]
    },
    {
      "IconName": "Icon2",
      "IconUrl": "https://your_icon_url2.ico",
      "NetworkSharePath": "\\\\server\\share2",
      "Users": [
        "User3",
        "User4"
      ]
    }
  ]
}
```

The `NetworkShares` array contains objects representing network shares, with each object having the following properties:

- `IconName`: The name of the icon and the generated script related to the network share.
- `IconUrl`: The URL to the icon file used for the network share.
- `NetworkSharePath`: The network share path that the icon will open when executed.
- `Users`: An array of usernames for which the network share and icon will be set up.

Make sure the JSON file contains the appropriate settings for your organization's network shares.

## Notes

This script was created to simplify the process of setting up user-specific icons and shortcuts for accessing network shares in an organization's environment. If you encounter any issues or have suggestions for improvement, feel free to contribute by submitting an issue or pull request in this [GitHub repository](https://github.com/taalexander0614/CtrlAltUpgrade).

Happy icon sharing!