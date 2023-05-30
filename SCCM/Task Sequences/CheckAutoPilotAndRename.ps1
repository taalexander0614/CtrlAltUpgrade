# This section is setting up the authentication information required for your Azure AD App.
# You would replace the placeholder text with your actual Client ID, Client Secret and Tenant ID.$ClientID = "Your Client ID"
$ClientID = "Your Client ID"
$ClientSecret = "Your Client Secret"
$TenantId = "Your Tenant ID"

# This line is setting up the LOCALAPPDATA environment variable. 
# It's typically required when the script is running in a system context (like during SCCM OSD), where this variable may not be set by default.
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")

# This line is defining the working directory as the temporary folder.
$WorkingDir = $env:TEMP

# The next section of the script is ensuring that PowerShellGet (a module manager) and PackageManagement (provides cmdlets for discovering, installing, updating and uninstalling PowerShell modules and other package types) are installed on the system.
# If these modules are not found, it downloads the necessary files and installs them.
if (!(Get-Module -Name PowerShellGet)){
    $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
    Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$WorkingDir\powershellget.2.2.5.zip"
    $Null = New-Item -Path "$WorkingDir\2.2.5" -ItemType Directory -Force
    Expand-Archive -Path "$WorkingDir\powershellget.2.2.5.zip" -DestinationPath "$WorkingDir\2.2.5"
    $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
    Move-Item -Path "$WorkingDir\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
    }

#PackageManagement from PSGallery URL
if (!(Get-Module -Name PackageManagement)){
    $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.7.nupkg"
    Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$WorkingDir\packagemanagement.1.4.7.zip"
    $Null = New-Item -Path "$WorkingDir\1.4.7" -ItemType Directory -Force
    Expand-Archive -Path "$WorkingDir\packagemanagement.1.4.7.zip" -DestinationPath "$WorkingDir\1.4.7"
    $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
    Move-Item -Path "$WorkingDir\1.4.7" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7"
    }

# Importing the PowerShellGet module which was ensured to be installed above
Import-Module PowerShellGet

# This section is installing and importing necessary modules for working with AutoPilot and Intune.
# These modules include commands and cmdlets for managing Windows AutoPilot and Microsoft Graph Intune services.
Install-Module -Name WindowsAutoPilotIntune -Force -AcceptLicense -SkipPublisherCheck
Import-Module -Name WindowsAutoPilotIntune -Force
Install-Module -Name Microsoft.Graph.Intune -Force -AcceptLicense -SkipPublisherCheck
Import-Module -Name Microsoft.Graph.Intune -Force
Install-Module -Name AzureAD -Force -AcceptLicense -SkipPublisherCheck
Import-Module -Name AzureAD -Force

# Creating a COM object to interact with the SCCM Task Sequence environment.
# This object allows the script to interact with the Task Sequence environment variables.
$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment

# Pulling in some variables from the task sequence environment.
# These variables will be used later in the script.
$TPMSupport = $TSEnv.Value('TPMSupport')
$displayName = $TSEnv.Value('OSDComputerName')

# Setting the group tag based on whether or not TPM is supported.
# The group tag determines which AutoPilot profile will be assigned to the device.
if ($TPMSupport -eq "True") {
    $groupTag = 'SelfDeploy'
}
else {
    $groupTag = 'UserDriven'
}

# Storing the group tag in the task sequence environment for later use.
$tsenv.Value('groupTag') = $groupTag
Write-Output "AutoPilot Profile: $groupTag"
Write-Output "Computer Name: $displayName"

# This section attempts to retrieve the serial number of the device using Windows Management Instrumentation Command-line (WMIC)
# If the serial number cannot be retrieved, an error is thrown and the 'ProfileAssigned' task sequence environment variable is set to "False"
Try {
    Write-Output "getting serial number"
    $serial = (wmic bios get serialnumber | Select-String '[\w\d-]+').Matches.Value | Select-Object -Skip 1
    Write-Output "Serial Number: $serial"
}
Catch {
    $tsenv.Value('ProfileAssigned') = "False"
    Throw "failed to get serial number"
}

# This section attempts to connect to Microsoft Graph using the provided tenant ID, application ID, and application secret.
# If the connection fails, an error is thrown and the 'ProfileAssigned' task sequence environment variable is set to "False"
Try {
    Write-Output "attempting to connect to MSGraph"
    $graph = Connect-MSGraphApp -Tenant $TenantId -AppId $ClientId -AppSecret $ClientSecret
}
Catch {
    $tsenv.Value('ProfileAssigned') = "False"
    Throw "failed to connect to MS-Graph"
}

# This section attempts to locate the device in the AutoPilot service using the serial number retrieved earlier.
# If the device cannot be located, an error is thrown and the 'ProfileAssigned' task sequence environment variable is set to "False"
Write-Output "Attempt to locate device by serial number $serial"
Try {
$device = (Get-AutopilotDevice -Serial $Serial)
}
Catch {
    $tsenv.Value('ProfileAssigned') = "False"
    Throw "failed to locate device by serial number $serial"
}

# If the device was successfully located, this section attempts to update the device's information in the AutoPilot service.
# After the device's information has been updated, the script initiates an AutoPilot Sync.
# If any of these operations fail, an error is thrown and the 'ProfileAssigned' task sequence environment variable is set to "False"
if ($null -ne $device) {
    Write-Output "Updating device info based on user input"
    Try {
        Set-AutoPilotDevice -id $device.id -groupTag $grouptag -ComputerName $displayName
        Write-Output "Updated device info, $groupTag and $displayName"
        Write-Output "Starting 10 second sleep, then invoking AutoPilot Sync"
        Start-Sleep -Seconds 10
        Try {
            Invoke-AutoPilotSync
            Write-Output "Invoked the AutoPilot Sync"
            $tsenv.Value('ProfileAssigned') = "True"
        }
        Catch {
            $tsenv.Value('ProfileAssigned') = "False"
            Throw "failed to initiate autopilot sync"
        }
    }
    Catch {
        $tsenv.Value('ProfileAssigned') = "False"
        Throw "failed to update device info"
    }
}
else {
    Write-Output "Device not found, will need to upload hash"
    $tsenv.Value('ProfileAssigned') = "False"
}

