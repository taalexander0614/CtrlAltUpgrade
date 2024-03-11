# Intune Proactive Remediation for Printer Deployment

This script automates printer deployment on Windows 10/11 devices using an Intune Proactive Remediation. It checks the membership of the device in specified Azure AD groups and installs or removes the assigned printers accordingly.

## Usage

### Prerequisites

- Ensure the Intune environment is properly configured and the devices are enrolled.
- The script must run with administrative privileges.
- PowerShell execution policy should allow running scripts.
- Azure App Registration with App permissions for Directory.Read.All and Device.Read.All

### Configuration

1. Modify the script with your organization's specific details:
   - `$Global:orgName`: Your organization's name.
   - `$Global:scriptName`: Name of the script.
   - `$Global:logLevel`: Set the desired logging level (`DEBUG`, `INFO`, `WARN`, `ERROR`).
   - `$jsonUrl`: URL to the JSON file containing printer deployment information.
   - `$tenantId`, `$appID`, `$appSecret`: Azure AD tenant ID, Application ID, and Application Secret for authentication.

2. Format the JSON file according to the provided template:

   ```json
   {
       "Categories": [
           "computerlab"
       ],
       "Printers": [
           {
               "PrinterName": "ExampleLab",
               "IpAddress": "10.0.0.1",
               "PrinterPath": "\\\\PrintServer\\PrinterName",
               "Categories": {
                    "computerlab"
               }
               "Groups": [
                   {
                   "Name": "Group1",
                   "ID": "group_id_here"
                   }
               ]
           }
       ]
   }
   ```

   - `Categories`: Array containing categories to organize printers (e.g., `"computerlab"`).
   - `Printers`: Array containing printers.
   - `Name`: Name of the printer.
   - `IpAddress`: IP address printer.
   - `PrinterPath`: UNC path of the printer to be installed.
   - `Categories`: Categories corresponding to options in the "Categories" array.
   - `Groups`: Array containing Azure AD groups with printer assignments.
     - `Name`: Name of the Azure AD group.
     - `ID`: ID of the Azure AD group.

3. Upload the json file somewhere it can be referenced in the script (Azure Blob Storage or even a public GitHub repo)

4. Deploy the detection and remediation scripts to a group using Intune Proactive Remediations

## Functions

### Write-Log

- Logs messages with different severity levels (`DEBUG`, `INFO`, `WARN`, `ERROR`) to a log file.

### Get-AccessToken

- Obtains an access token for Microsoft Graph API authentication.

### Invoke-GetComputerGroups

- Retrieves the computer's group memberships using Microsoft Graph API.

### Main Script Logic

- Obtains an access token.
- Downloads printer deployment information from the provided JSON URL.
- Creates json containing all groups the computer is a member of.
- Gets all currently installed printers.
- Iterates through each printer to be added.
- Uses groups from json to determine whether printers should be added or removed
- Installs printers if not already installed.
- Removes printers if they are installed.

## Disclaimer

- Ensure proper testing in a non-production environment before deploying to production.
- Review and understand the implications of script execution in your environment.
