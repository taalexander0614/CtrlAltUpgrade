<#
.SYNOPSIS
This script creates a shortcut to execute a printer group management GUI.

.DESCRIPTION
The script performs the following actions:
- Checks if RSAT (Remote Server Administration Tools) are installed on the computer and installs them if they are not.
- Creates the necessary directories on the local machine if they do not exist.
- Downloads a script and an icon file from the organization blob storage if they are not already present.
- Copies the "ActiveDirectory" PowerShell module to the Modules directory.
- Creates a shortcut to run the downloaded PowerShell script, sets an icon for it, and places the shortcut on the common desktop.

.EXAMPLE
To install the GUI, you can manually run the script with the ActiveDirectory module in the same directory or or wrap it in an Intunewin 

.NOTES
This script was created for use with my organizations resources and expects certain folder structures and file names. Update the variables at the top of the script as necessary to suit your needs.
I prefer an org folder in both ProgramData and AppData so things can stay organized whether running things in the System or User context.

You will also need to check the blob storage folder structure variables to ensure they match what is used in your organization.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>


# Set your orginization and the desktop shortcut's name and where you want the shortcut to go. The ico file in your blob storage should be the same as $icon.
$org = "ORG"
$icon = "Printer User Management"
$ScriptName = "ModifyPrinterGroups"
$Blob = "https://ORGintunestorage.blob.core.windows.net/intune"

# Define blob storage URL and necessary related variables. $ScriptName should exactly match the name of the script in your blob storage
$IconBlob = "$Blob/Icons"
$ScriptsBlob = "$Blob/Scripts"
$ScriptURL = "$ScriptsBlob/$ScriptName.ps1"
$IconURL = "$IconBlob/$icon.ico"

# Requirded PS Module
$Module = "ActiveDirectory"

# Define the base folder for org resources and the needed sub-directories
$orgFolder = "$env:PROGRAMDATA\$org"
$ScriptFolder = "$orgFolder\Scripts"
$ModuleFolder = "$ScriptFolder\Modules"
$IconFolder = "$orgFolder\Icons"
$ShortcutIcon = "$IconFolder\$icon.ico"
$Script = "$ScriptFolder\$ScriptName.ps1"

# Set the location for the shortcut
$ShortcutLocation = [Environment]::GetFolderPath("CommonDesktop")

##### Not sure if the RAT tools are required if you copy over the module folder. Just uncomment if needed
<# 
# If RSAT tools are not installed, install them
$rsatCapability = "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
$rsatInstalled = Get-WindowsCapability -Online | Where-Object {$_.Name -eq $rsatCapability -and $_.State -eq "Installed"}
if (!$rsatInstalled) {
    Write-Host "RSAT tools are not installed. Installing RSAT..."
    Add-WindowsCapability -Online -Name $rsatCapability -ErrorAction Stop
    Write-Host "RSAT tools installed successfully."
}
else {
    Write-Host "RSAT tools are already installed."
}
#>

# Create necessary folders if they don't already exist
If(!(test-path $orgFolder)){new-item $orgFolder -type directory -force | out-null}
If(!(test-path $ScriptFolder)){new-item $ScriptFolder -type directory -force | out-null}
If(!(test-path $ModuleFolder)){new-item $ModuleFolder -type directory -force | out-null}
If(!(test-path $IconFolder)){new-item $IconFolder -type directory -force | out-null}

# Download the script and icon files if they don't already exist
If(!(test-path -Path $ShortcutIcon)){invoke-webrequest -Uri $IconURL -OutFile $ShortcutIcon}
If(!(test-path -Path $Script)){invoke-webrequest -Uri $ScriptURL -OutFile $Script}

# Copy the module to the Modules folder
If(!(test-path -Path "$ModuleFolder\$Module")){Copy-Item -Path ".\$Module" -Destination $ModuleFolder -Recurse}

# Create the shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$ShortcutLocation\$icon.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""
$Shortcut.IconLocation = $ShortcutIcon
$Shortcut.Save()
