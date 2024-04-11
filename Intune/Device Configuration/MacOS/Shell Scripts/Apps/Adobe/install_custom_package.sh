#!/bin/bash

# This script works but is definitely a work in progress. I have too many other things I need to focus on right now to tinker with it.

# Script to download and install Adobe software
# This script will download the a custom package of Adobe software you have created in the Adobe Admin Console
# The package will be downloaded from a local IIS server and installed on the Mac
# The script will also uninstall any existing Adobe software before installing the new package

## TODO: Some computers already have the correct software but also other versions side by side.
######## Might be good to check and remove at least the apps where the years don't match in $app_to_install
# Primary variables
org_name="CtrlAltUpgrade" # Name of the organization
package_name="Mac Lab Suite - 2023" # Name of the package from Adobe Admin Console
iis_ip="10.24.15.52" # IP Address of the IIS server
apps_to_install=(
    "/Applications/Adobe Photoshop 2023/Adobe Photoshop 2023.app"
    "/Applications/Adobe Illustrator 2023/Adobe Illustrator.app"
    "/Applications/Adobe Dreamweaver 2021/Adobe Dreamweaver 2021.app"
    "/Applications/Adobe InDesign 2023/Adobe InDesign 2023.app"
    "/Applications/Adobe Lightroom CC/Adobe Lightroom.app"
    "/Applications/Adobe Premiere Pro 2023/Adobe Premiere Pro 2023.app"
    "/Applications/Adobe Bridge 2023/Adobe Bridge 2023.app"
    "/Applications/Adobe Media Encoder 2023/Adobe Media Encoder 2023.app"
)

# URLs
mac_directory="http://$iis_ip/LocalSoftwareHosting/Adobe/MacOS"
package_url="$mac_directory/$package_name.zip"
uninstall_url="https://deploymenttools.acp.adobeoobe.com/Uninstall/Mac/AdobeUninstaller.dmg"

# Local directories
org_temp_directory="/Users/Shared/tmp_$org_name"
org_log_directory="/var/log/$org_name"
log_directory="$org_log_directory/$package_name"
log="$log_directory/$package_name - $(date '+%Y-%m-%d %H%M').log"

# Function to handle errors and log messages
handle_error() {
    local message="$1"
    echo "[$(date)] | $message" >> "$log"
    rm -rf "$temp_directory" # Remove entire $temp_directory
    exit 1
}

# Function to handle spaces in url
urlencode() {
  local path="$1"
  local encoded_path

  encoded_path=$(echo "$path" | sed -e 's/ /%20/g')
  echo "$encoded_path"
}

# Create the org log directory if it doesn't exist
if [ ! -d "$org_log_directory" ]; then
    mkdir -p "$org_log_directory"
fi
# Create the log directory if it doesn't exist
if [ ! -d "$log_directory" ]; then
    mkdir -p "$log_directory"
fi

# Start logging
exec 1>>"$log" 2>&1

echo "##############################################################"
echo "# Starting install of $package_name"
echo "############################################################"

echo "Checking if apps are already installed"
### TODO: would not hurt to check the specific versions for each app (or at least the ones used by GMetrix) but I am just trying to get it deployed since clases have started
# Iterate over the array and check each application
missing=false
for app in "${apps_to_install[@]}"; do
    if [ ! -d "$app" ]; then
        missing=true
        break
    fi
done

# Check if the missing flag is set and echo a message
if [ "$missing" = false ]; then
    echo "All apps are already installed, exiting script..."
    exit 0
fi

# Ensure the custom temp directories exists and create them if not
echo "Checking for org tmp directory: $org_temp_directory"
if [ ! -d "$org_temp_directory" ]; then
echo "Temp directory not present, creating and giving read/write permissions for 'everyone'"
    mkdir -p "$org_temp_directory"
    chmod -R 777 "$org_temp_directory" # Give read/write permissions for everyone
fi

temp_directory="$org_temp_directory/$package_name"

echo "Checking for custom tmp directory: $temp_directory"
if [ ! -d "$temp_directory" ]; then
echo "Temp directory not present, creating and giving read/write permissions for 'everyone'"
    mkdir -p "$temp_directory"
    chmod -R 777 "$temp_directory" # Give read/write permissions for everyone
fi

# Download and extract necessary installation files to ensure script doesn't time out after uninstalling
echo "Uninstall URL: $uninstall_url"
encoded_uninstall_url=$(urlencode "$uninstall_url")
echo "Uninstall Encoded URL: $encoded_uninstall_url"

echo "Install URL: $package_url"
encoded_install_url=$(urlencode "$package_url")
echo "Install Encoded URL: $encoded_install_url"

echo "Downloading $encoded_install_url to $temp_directory/$package_name.zip"
curl --retry 5 \
     --retry-delay 5 \
     --connect-timeout 15 \
     -o "$temp_directory/$package_name.zip" \
     -v \
     "$encoded_install_url"
if [ $? -ne 0 ]; then
    handle_error "Failed to download $package_name.zip, exiting script..."
fi

echo "Unzipping $temp_directory/$package_name.zip to $temp_directory"
unzip "$temp_directory/$package_name.zip" -d "$temp_directory" > /dev/null || handle_error "Failed to unzip package, exiting script..."

# Uninstallation process
echo "Downloading $encoded_uninstall_url to $temp_directory/AdobeUninstaller.dmg"
curl -o "$temp_directory/AdobeUninstaller.dmg" "$encoded_uninstall_url" || handle_error "Failed to download AdobeUninstaller.dmg, exiting script..."
echo "Mounting $temp_directory/AdobeUninstaller.dmg to $temp_directory/mount"
hdiutil attach "$temp_directory/AdobeUninstaller.dmg" -nobrowse -mountpoint "$temp_directory/mount" || handle_error "Failed to attach AdobeUninstaller.dmg, exiting script..."
uninstaller_path="$temp_directory/mount/AdobeUninstaller"
echo "Uninstaller Path: $uninstaller_path"
if [ -f "$uninstaller_path" ] && [ -x "$uninstaller_path" ]; then
    echo "AdobeUninstaller is present and executable."
    sudo "$uninstaller_path" --all
    # Continue with the rest of your script
else
    echo "AdobeUninstaller is not available or not executable."
    # Handle the error, perhaps exit the script or provide an error message
fi
echo "Detaching $temp_directory/mount"
hdiutil detach "$temp_directory/mount"
echo "Deleting $temp_directory/AdobeUninstaller.dmg"

# Installation process
echo "Determining Build directory based on $temp_directory"
build_directory=$(find "$temp_directory" -name "Build" -type d -print -quit)

if [ -d "$build_directory" ]; then
    echo "Determining package directory based on $build_directory"
    pkg_directory=$(find "$build_directory" -name "*_Install.pkg" -type d -print -quit)
    if [ -d "$pkg_directory" ]; then
        echo "Installing from $pkg_directory"
        sudo installer -pkg "$pkg_directory" -target / >> "$log" 2>&1 || handle_error "Installation failed, check logs for details..."
        echo "Installation completed successfully."
        rm -rf "$temp_directory" # Remove entire $temp_directory
        exit 0
    else
        handle_error "Package directory not found, exiting script..."
    fi
else
    handle_error "Build directory not found, exiting script..."
fi
