# Intune Proactive Remediation for Managing Shortcuts

## Overview

This script is designed to help manage shortcuts across devices and users managed by Microsoft Intune. It involves the use of a detection script that references a JSON file stored in Azure Blob Storage and utilizes Microsoft Graph to query Azure Active Directory (AAD) groups and users for shortcut information. The script then creates reference shortcuts, checks for updates, and performs various remediation actions, such as copying or removing shortcuts, based on the information in the JSON file and the users/groups associated with the devices.

## Purpose

The purpose of this script is to ensure that users have the correct shortcuts on their desktops and in their start menus, manage shortcuts based on group and user membership, and handle shortcut updates efficiently.

## Features

- Utilizes Microsoft Graph to query Azure AD groups and users for shortcut information.
- Checks for updates to shortcuts based on information in the JSON file.
- Creates reference shortcuts for each user and device, handling edge cases like "All Devices" group.
- Handles cases where users have shortcuts they should not, missing shortcuts, or outdated shortcuts.

## JSON Data

The JSON file used by the script contains two main sections: `deployedShortcuts` and `shortcutIcons`.

- `deployedShortcuts` specifies the properties of each shortcut, such as name, version, icon, target, and more.
- `shortcutIcons` specifies the icons associated with the shortcuts and their corresponding URLs.

The JSON file used by the script contains two main sections: `deployedShortcuts` and `shortcutIcons`.

- `deployedShortcuts` specifies the properties of each shortcut, such as name, version, icon, target, and more.
- `shortcutIcons` specifies the icons associated with the shortcuts and their corresponding URLs.

### Types of Shortcuts and How to Specify Them in JSON

1. **Desktop Shortcut**

    To specify a desktop shortcut in the JSON, set the `desktop` property to `true`. Example:

    ```json
    "desktop": true
    ```

2. **Start Menu Shortcut**

    To specify a start menu shortcut in the JSON, set the `startMenu` property to `true`. Example:

    ```json
    "startMenu": true
    ```

3. **Open URL in Default Browser**

    To open a URL in the default web browser, set the `target` property to the URL and the `shortcutArgs` property to an empty string. Example:

    ```json
    "target": "https://www.example.com",
    "shortcutArgs": ""
    ```

4. **Open URL in Specified Browser**

    To open a URL in a specific browser, set the `target` property to the path of the browser's executable and the `shortcutArgs` property to the URL. Example:

    ```json
    "target": "C:\\Program Files (x86)\\Mozilla Firefox\\firefox.exe",
    "shortcutArgs": "https://www.example.com"
    ```

5. **Open FileShare with UNC Path**

    To open a file share with a UNC path, set the `target` property to the UNC path and leave the `shortcutArgs` property empty. Example:

    ```json
    "target": "explorer.exe",
    "shortcutArgs": "\\\\ANXSCCM\\Wallpapers"
    ```

6. **Open Application**

    To open an application, set the `target` property to the path of the application's executable and the `shortcutArgs` property to an empty string. Example:

    ```json
    "target": "C:\\Program Files\\MyApp\\MyApp.exe",
    "shortcutArgs": ""
    ```

7. **Open Application with Arguments**

    To open an application with arguments, set the `target` property to the path of the application's executable and the `shortcutArgs` property to the desired arguments. Example:

    ```json
    "target": "C:\\Program Files\\MyApp\\MyApp.exe",
    "shortcutArgs": "-arg1 -arg2"
    ```

8. **Custom Icon**

    To specify a custom icon for the shortcut, set the `iconKey` property to the name of the icon and the `iconLocation` property to the path of the icon file. Example:

    ```json
    "iconKey": "customIcon",
    "icoURL": "https://rcsintunestorage.blob.core.windows.net/intune/Icons/ICO/LJB.ico"
    ```

9. **Other Shortcut Properties**

    You can also set other properties of the shortcut, such as `windowStyle`, `hotKey`, and `workingDirectory`, as needed. Example:

    ```json
    "windowStyle": "0",
    "hotKey": "Ctrl+Shift+F",
    "workingDirectory": "C:\\Program Files\\MyApp"
    ```
