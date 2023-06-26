<#
.SYNOPSIS
This script provides a GUI for managing printer users in an Active Directory environment.
With a new printer contract, our schools decided to get classroom printers for every teacher...so I made a way for the schools to be able to handle staff changes.

.DESCRIPTION
This script creates a GUI that enables administrators to add and remove users from printer groups.
The GUI includes a dropdown to select a printer, a list box to display users, buttons to add and remove users, 
and a search box with autocomplete for adding users.

Our $centralOffice OU is tructured differently from the rest of the district, so it needed it's own set of logic.
This gets the OU of the user running it and checks for the parent OU (their school) to limit results.
Within a school, there are OU's for teachers, office staff, classified staff and printer security groups.
The printers they can choose from are the security group in the $generalPrinterOU of their school's OU.
The users they can choose from are the users in their school's OU.

.NOTES
This script is not very generalized but I tried to organze it so someone could see how to adapt it.
Requires the Active Directory module for PowerShell (Which I have being manually added and imported) and .NET Windows Forms.
Tested on Windows 10 with PowerShell 5.1.

.AUTHOR
Timothy Alexander
https://github.com/taalexander0614/CtrlAltUpgrade
#>

$org = "ORG"
$icon = "Printer User Management"

# Define OU's
$classifiedStaff = "OU=Classified Staff"
$officeStaff = "OU=Office Staff"
$teachers = "OU=Teachers"
$centralOffice = "OU=RapidIdentity Central Office Staff"
$centralOfficeParentOU = "OU=ORG Administrative Offices,DC=ORG,DC=Local"
$centralOfficePrinterOU = "OU=Groups - Printers,OU=ORG Central Office,OU=ORG Administrative Offices,DC=ORG,DC=Local"
$generalPrinterOU = "OU=Groups - Printers"

# Define the colors for the GUI
$backgroundColor = "Green"
$buttonTextColor = "Black"
$textColor = "Gold"

# Define the base folder for org resources and the needed sub-directories
$orgFolder = "$env:PROGRAMDATA\$org"
$ScriptFolder = "$orgFolder\Scripts"
$ModuleFolder = "$ScriptFolder\Modules"
$Module = "$ModuleFolder\ActiveDirectory"
$IconFolder = "$orgFolder\Icons"
$ShortcutIcon = "$IconFolder\$icon.ico"

# Import the required Windows Forms modules
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Import-Module "$Module\Microsoft.ActiveDirectory.Management.dll"

# Retrieve the current user's SID (Security Identifier)
$currentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
#$currentUserSid = "jamiegreene"
$currentuser = Get-ADUser -Identity $currentUserSid
$AllowedParentOU = $currentUser.DistinguishedName -replace '^.*?,.*?,', ''
$classifiedStaffOU = "$classifiedStaff,$AllowedParentOU"
$officeStaffOU = "$officeStaff,$AllowedParentOU"
$teachersOU = "$teachers,$AllowedParentOU"
$centralOfficeOU = "$centralOffice,$AllowedParentOU"

# Check if the user is in the $centralOfficeParentOU, if so adjust OU mapping accordingly
if ($AllowedParentOU -eq $centralOfficeParentOU) {
    $printerOU = $centralOfficePrinterOU
    $allowedUsers = Get-ADUser -Filter * -SearchBase $AllowedParentOU | Where-Object { $_.DistinguishedName -like "*,$centralOfficeOU" } | Select-Object -ExpandProperty Name
}
else {
    $printerOU = "$generalPrinterOU,$AllowedParentOU"
    $allowedUsers = Get-ADUser -Filter * -SearchBase $AllowedParentOU |
         Where-Object { $_.DistinguishedName -like "*,$classifiedStaffOU" -or
                        $_.DistinguishedName -like "*,$officeStaffOU" -or
                        $_.DistinguishedName -like "*,$teachersOU" } | Select-Object -ExpandProperty Name
}

$allowedPrinters = Get-ADGroup -Filter * -SearchBase $printerOU | Select-Object -ExpandProperty Name

# Define the colors for the GUI
$color1 = [System.Drawing.Color]::$backgroundColor
$color2 = [System.Drawing.Color]::$buttonTextColor
$color3 = [System.Drawing.Color]::$textColor

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = $icon
$form.Size = New-Object System.Drawing.Size(400, 450)
$form.StartPosition = "CenterScreen"

# Set the form icon
$FormIcon = [System.Drawing.Icon]::ExtractAssociatedIcon("$ShortcutIcon")
$form.Icon = $FormIcon

# Create a Panel for the background color
$panelBackground = New-Object System.Windows.Forms.Panel
$panelBackground.Location = New-Object System.Drawing.Point(0, 0)
$panelBackground.Size = $form.ClientSize
$panelBackground.BackColor = $color1

# Add the Panel to the form
$form.Controls.Add($panelBackground)

# Create a label for the security group drop-down
$labelGroup = New-Object System.Windows.Forms.Label
$labelGroup.Text = "Select Printer:"
$labelGroup.Location = New-Object System.Drawing.Point(20, 20)
$labelGroup.AutoSize = $true
$labelGroup.ForeColor = $color3
$labelGroup.Font = New-Object System.Drawing.Font($labelGroup.Font.FontFamily, $labelGroup.Font.Size, [System.Drawing.FontStyle]::Bold)


# Create a drop-down menu for security groups
$dropDownGroup = New-Object System.Windows.Forms.ComboBox
$dropDownGroup.Location = New-Object System.Drawing.Point(150, 20)
$dropDownGroup.Size = New-Object System.Drawing.Size(200, 20)
$dropDownGroup.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
# Set the FlatStyle to Flat to remove the white border
$dropDownGroup.FlatStyle = 'Flat'
# Set the background color
$dropDownGroup.BackColor = $color3
# Set the foreground color (text color)
$dropDownGroup.ForeColor = $color2
# Populate the drop-down menu with security groups
$dropDownGroup.Items.AddRange($allowedPrinters)

# Create a list box to display the users in the selected group
$listBoxUsers = New-Object System.Windows.Forms.ListBox
$listBoxUsers.Location = New-Object System.Drawing.Point(20, 60)
$listBoxUsers.Size = New-Object System.Drawing.Size(330, 200)
$listBoxUsers.SelectionMode = [System.Windows.Forms.SelectionMode]::One
# Set the border style to None to remove the white border
$listBoxUsers.BorderStyle = 'None'
# Set the background color
$listBoxUsers.BackColor = $color3
# Set the foreground color (text color)
$listBoxUsers.ForeColor = $color2
$listBoxUsers.Font = New-Object System.Drawing.Font($listBoxUsers.Font.FontFamily, $listBoxUsers.Font.Size, [System.Drawing.FontStyle]::Bold)


# Create a button for removing users
$buttonRemoveUser = New-Object System.Windows.Forms.Button
$buttonRemoveUser.Text = "Remove User"
$buttonRemoveUser.Location = New-Object System.Drawing.Point(20, 270)
$buttonRemoveUser.Size = New-Object System.Drawing.Size(100, 30)
$buttonRemoveUser.BackColor = $color3
$buttonRemoveUser.ForeColor = $color2
$buttonRemoveUser.Enabled = $false
# Set the FlatStyle to Flat
$buttonRemoveUser.FlatStyle = 'Flat'
# Modify the button's FlatAppearance
$buttonRemoveUser.FlatAppearance.BorderColor = $color3
$buttonRemoveUser.FlatAppearance.BorderSize = 2
$buttonRemoveUser.Font = New-Object System.Drawing.Font($buttonRemoveUser.Font.FontFamily, $buttonRemoveUser.Font.Size, [System.Drawing.FontStyle]::Bold)

# Create a label for the user search box
$labelSearch = New-Object System.Windows.Forms.Label
$labelSearch.Text = "Search Users:"
$labelSearch.Location = New-Object System.Drawing.Point(20, 320)
$labelSearch.AutoSize = $true
$labelSearch.ForeColor = $color3
$labelSearch.Font = New-Object System.Drawing.Font($buttonRemoveUser.Font.FontFamily, $buttonRemoveUser.Font.Size, [System.Drawing.FontStyle]::Bold)


# Create a search box for adding users
$textBoxSearch = New-Object System.Windows.Forms.TextBox
$textBoxSearch.Location = New-Object System.Drawing.Point(150, 320)
$textBoxSearch.Size = New-Object System.Drawing.Size(200, 20)
# Set the border style to None to remove the white border
$textBoxSearch.BorderStyle = 'None'
# Set the background color
$textBoxSearch.BackColor = $color3
# Set the foreground color (text color)
$textBoxSearch.ForeColor = $color2
$textBoxSearch.Font = New-Object System.Drawing.Font($textBoxSearch.Font.FontFamily, $textBoxSearch.Font.Size, [System.Drawing.FontStyle]::Bold)


# Set up autocomplete for the search box
$autoComplete = New-Object System.Windows.Forms.AutoCompleteStringCollection
$autoComplete.AddRange($allowedUsers)
$textBoxSearch.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::Suggest
$textBoxSearch.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::CustomSource
$textBoxSearch.AutoCompleteCustomSource = $autoComplete


# Create a button for adding users
$buttonAddUser = New-Object System.Windows.Forms.Button
$buttonAddUser.Text = "Add User"
$buttonAddUser.Location = New-Object System.Drawing.Point(20, 360)
$buttonAddUser.Size = New-Object System.Drawing.Size(100, 30)
$buttonAddUser.BackColor = $color3
$buttonAddUser.ForeColor = $color2
$buttonAddUser.Enabled = $false
# Set the FlatStyle to Flat
$buttonAddUser.FlatStyle = 'Flat'
# Modify the button's FlatAppearance
$buttonAddUser.FlatAppearance.BorderColor = $color3
$buttonAddUser.FlatAppearance.BorderSize = 2
$buttonAddUser.Font = New-Object System.Drawing.Font($buttonAddUser.Font.FontFamily, $buttonAddUser.Font.Size, [System.Drawing.FontStyle]::Bold)


# Add controls to the Panel
$panelBackground.Controls.Add($labelGroup)
$panelBackground.Controls.Add($dropDownGroup)
$panelBackground.Controls.Add($listBoxUsers)
$panelBackground.Controls.Add($buttonRemoveUser)
$panelBackground.Controls.Add($labelSearch)
$panelBackground.Controls.Add($textBoxSearch)
$panelBackground.Controls.Add($buttonAddUser)

# Event handler for security group selection
$dropDownGroup.Add_SelectedIndexChanged({
    $selectedGroup = $dropDownGroup.SelectedItem.ToString()
    # Retrieve the users in the selected group and populate the list box
    $usersInGroup = Get-ADGroupMember -Identity $selectedGroup | Where-Object {$_.objectClass -eq "user"}
    $listBoxUsers.Items.Clear()
    foreach ($user in $usersInGroup) {
        $listBoxUsers.Items.Add($user.Name)
    }
    # Enable the remove button if a user is selected
    if ($listBoxUsers.SelectedIndex -ne -1) {
        $buttonRemoveUser.Enabled = $true
    }
    else {
        $buttonRemoveUser.Enabled = $false
    }
})

# Event handler for user selection in the list box
$listBoxUsers.Add_SelectedIndexChanged({
    # Enable the remove button if a user is selected
    if ($listBoxUsers.SelectedIndex -ne -1) {
        $buttonRemoveUser.Enabled = $true
    }
    else {
        $buttonRemoveUser.Enabled = $false
    }
})

# Event handler for removing users
$buttonRemoveUser.Add_Click({
    $selectedUser = $listBoxUsers.SelectedItem.ToString()
    $selectedGroup = $dropDownGroup.SelectedItem.ToString()
    
    # Retrieve the user object from Active Directory
    $userObject = Get-ADUser -Filter "Name -eq '$selectedUser'"

    if ($userObject) {
        # Remove the user from the group
        Remove-ADGroupMember -Identity $selectedGroup -Members $userObject.DistinguishedName -Confirm:$false

        Write-Host "Removing user: $selectedUser from group: $selectedGroup"

        # Remove the user from the list box
        $listBoxUsers.Items.Remove($selectedUser)

        # Clear the selection
        $listBoxUsers.ClearSelected()
    }
    else {
        Write-Host "User not found: $selectedUser"
    }

    # Disable the remove button
    $buttonRemoveUser.Enabled = $false
})


# Event handler for adding users
$buttonAddUser.Add_Click({
    $selectedUser = $textBoxSearch.Text.Trim()
    $selectedGroup = $dropDownGroup.SelectedItem.ToString()

    # Retrieve the user object from Active Directory
    $userObject = Get-ADUser -Filter "Name -eq '$selectedUser'"
    
    if ($userObject) {
        # Add the user to the group
        Add-ADGroupMember -Identity $selectedGroup -Members $userObject
        # Add the user to the list box, clear search and clear selection
        $listBoxUsers.Items.Add($selectedUser)
        $textBoxSearch.Clear()
        $listBoxUsers.ClearSelected()
    }
    else {
        $NotFoundform = New-Object System.Windows.Forms.Form 
        $OKButton.Icon = $OrgIcon
        $NotFoundform.Text = "Error"
        $NotFoundform.BackColor = $color1
        $NotFoundform.Size = New-Object System.Drawing.Size(200,100)
        $NotFoundform.StartPosition = 'CenterScreen'
    
        $NotFoundlabel = New-Object System.Windows.Forms.Label
        $NotFoundlabel.Text = "User not found: $selectedUser"
        $NotFoundlabel.AutoSize = $true
        $NotFoundlabel.ForeColor = $color2
    
        $OKButton = New-Object System.Windows.Forms.Button
        $OKButton.Text = "OK"
        $OKButton.Dock = 'Bottom'
        $OKButton.add_Click({ $NotFoundform.Close() })
        # Set the FlatStyle to Flat
        $OKButton.FlatStyle = 'Flat'
        # Modify the button's FlatAppearance
        $OKButton.FlatAppearance.BorderColor = $color3
        $OKButton.FlatAppearance.BorderSize = 2
        $OKButton.Font = New-Object System.Drawing.Font($OKButton.Font.FontFamily, $OKButton.Font.Size, [System.Drawing.FontStyle]::Bold)
    
        $NotFoundform.Controls.Add($NotFoundlabel)
        $NotFoundform.Controls.Add($OKButton)
    
        $NotFoundform.ShowDialog()   
    }

    # Disable the add button
    $buttonAddUser.Enabled = $false
})



# Event handler for search box text change
$textBoxSearch.Add_TextChanged({
    # Enable the add button if the search box has text
    if ($textBoxSearch.Text.Trim().Length -gt 0) {
        $buttonAddUser.Enabled = $true
    }
    else {
        $buttonAddUser.Enabled = $false
    }
})

# Add event handler for form closing
$form.Add_FormClosing({
    $form.Dispose()
})

# Display the form
[System.Windows.Forms.Application]::EnableVisualStyles() 
$form.ShowDialog() | Out-Null
