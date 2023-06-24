<#
.SYNOPSIS
This script checks if a specified program is installed using the Windows Package Manager (winget).

.DESCRIPTION
The script sets the name of the program to check in the $ProgramName variable. 
It then attempts to resolve the path of the winget executable. If multiple versions of winget are found, it chooses the latest.

The script then checks if winget is installed. If not, it throws an error. 
If winget is installed, it uses the winget list command to check if the specified program is installed. 
If the program is found, it outputs "Found it!".

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$ProgramName = "VideoLAN.VLC"

# resolve winget_exe
$winget_exe = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
if ($winget_exe.count -gt 1) {
    $winget_exe = $winget_exe[-1].Path
}

if (!$winget_exe) {
    Write-Error "Winget not installed"
}
else {
    $wingetPrg_Existing = & $winget_exe list --id $ProgramName --exact --accept-source-agreements
        if ($wingetPrg_Existing -like "*$ProgramName*") {
        Write-Host "Found it!"
    }
}