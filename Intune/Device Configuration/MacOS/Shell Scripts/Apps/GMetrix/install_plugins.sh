#!/bin/bash

# Script to download and install GMetrix extensions for Adobe software
# This script will download the latest version of the GMetrix extensions for Adobe software
# If run on a schedule, it will only download the extensions if they have been updated since the last download

ORG_NAME="CtrlAltUpgrade"

# URLs
package_name="GMetrix Extensions"
package_url="https://releases.gmetrix.net/lita/adobe/latest/AdobePlugins.zip"

# Local directories
org_temp_directory="/Users/Shared/tmp_$ORG_NAME"
org_log_directory="/var/log/$ORG_NAME"
log_directory="$org_log_directory/$package_name"
log="$log_directory/$package_name - $(date '+%Y-%m-%d %H%M').log"

# Define the downloaded date file
date_last_downloaded="/var/log/RCS/gmetrix_extensions_date.txt"

# Define the destination folder
DEST_FOLDER="/Library/Application Support/Adobe/CEP/extensions/"

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

# Check if the destination folder exists
if [ ! -d "$DEST_FOLDER" ]; then
    echo "$DEST_FOLDER does not exist, verify Adobe software is installed"
    exit 0
fi

echo "Checking if extensions are already up to date"
# Check if the download date file exists and if the zip file from the URL has been modified since the last download
if [ -f "$date_last_downloaded" ]; then
    last_downloaded=$(cat "$date_last_downloaded")
    last_modified=$(curl -sI "$package_url" | grep -i "last-modified" | awk -F': ' '{print $2}')

    if [ "$last_downloaded" == "$last_modified" ]; then
        echo "No new updates available."
        echo "Last downloaded: $last_downloaded"
        echo "Last modified: $last_modified"
        exit 0
    fi
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

# Delete the existing zip file and extracted folder if they exist
rm -f "$temp_directory/AdobePlugins.zip"
rm -rf "$temp_directory/AdobePlugins"

# Download and extract necessary installation files
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

# Move into the extracted directory
cd "$temp_directory/AdobePlugins"

# Loop through each zip file in the directory
for zip_file in *.zip; do
    # Check if the zip file matches the naming pattern we're interested in
    if [[ "$zip_file" == "gmetrix.lita.adobe."*".zip" ]]; then
        echo "Extracting $zip_file to $DEST_FOLDER"
        # Delete the existing folder if it exists
        rm -rf "${DEST_FOLDER}${zip_file%.zip}"

        # Extract the folder to the desired location
        unzip "$zip_file" -d "${DEST_FOLDER}${zip_file%.zip}" > /dev/null
        # Extract node_modules.zip in the node_modules folder to the node_modules folder
        if [ -f "${DEST_FOLDER}${zip_file%.zip}/node_modules/node_modules.zip" ]; then
            echo "Extracting node_modules.zip to ${DEST_FOLDER}${zip_file%.zip}/node_modules/"
            unzip "${DEST_FOLDER}${zip_file%.zip}/node_modules/node_modules.zip" -d "${DEST_FOLDER}${zip_file%.zip}/node_modules/" > /dev/null
        fi
    fi
done

# Remove the entire tmp directory
echo "Removing temp directory: $temp_directory"
rm -rf "$temp_directory" || handle_error "Failed to remove temp directory, exiting script..."

# Save the last modified date of the zip file to the date file
echo "Saving last modified date of $package_name.zip to $date_last_downloaded"
echo "$last_modified" > "$date_last_downloaded"

echo "##############################################################"
echo "# Completed install of $package_name"
echo "############################################################"


