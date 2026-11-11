#!/bin/bash

org_name="CtrlAltUpgrade"
exempt_users=("Administrator" "CtrlAltUpgrade")
days_since_login=90 # Number of days since login for a profile to be deleted

script_name="User Profile Cleanup"
org_log_directory="/var/log/$org_name"
log_directory="$org_log_directory/$script_name"
log="$log_directory/$script_name - $(date '+%Y-%m-%d %H%M').log"

check_stale_user() {
    local days_since_login=$1
    local username=$2
    current_date=$(date +%s) # Get the current date in seconds
    MIN_UID=501 # Minimum UID for regular users

    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        echo "User '$username' does not exist."
        return 1  # Return 1 for error
    fi

    # Check if user's UID is a number and within the range for regular users
    uid=$(dscl . -read /Users/$username UniqueID | awk '{print $2}')
    if [[ $uid =~ ^[0-9]+$ ]] && [ "$uid" -ge "$MIN_UID" ]; then
        # Get the last login time for the user
        last_login=$(last -n 1 $username | awk '{print $4,$5,$6}')
        echo "Processing $username."

        # Check if the user has ever logged in
        if [[ "$last_login" == *'never logged in'* ]]; then
            echo "Deleting $username. Never logged in."
            return 1  # Return 1 for delete
        else
            # Convert last login time to seconds
            last_login_sec=$(date -j -f "%b %d %H:%M" "$last_login" +%s 2>/dev/null)

            # Check if last login is more than 3 months old
            if [ $(( (current_date - last_login_sec) / (60*60*24) )) -ge $days_since_login ]; then
                echo "Deleting $username. Last login more than $days_since_login days ago."
                return 1  # Return 1 for delete
            else
                echo "Not deleting $username. Last login: $last_login."
                return 0  # Return 0 for no action needed
            fi
        fi
    fi
}

delete_user() {
    local username=$1

    # Check if the username is provided
    if [ -z "$username" ]; then
        echo "Error: No username provided."
        return 1
    fi

    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        echo "Error: User '$username' does not exist."
        return 1
    fi

    # Delete the user account
    echo "Deleting user profile: $username."
    if sysadminctl -deleteUser "$username" -secure; then
        echo "Successfully deleted user '$username'."
    else
        echo "Error: Failed to delete user '$username'."
        return 1
    fi

    # Remove the user's home directory (if it still exists)
    local home_dir="/Users/$username"
    if [ -d "$home_dir" ]; then
        echo "Removing home directory for user '$username'..."
        if rm -rf "$home_dir"; then
            echo "Successfully removed home directory for '$username'."
        else
            echo "Error: Failed to remove home directory for '$username'."
            return 1
        fi
    else
        echo "Home directory for '$username' not found or already removed."
    fi

    return 0
}


# Start logging
mkdir -p "$log_directory"
exec 1>>"$log" 2>&1

echo "##############################################################"
echo "# Starting $script_name"
echo "############################################################"

# Get the list of users from Open Directory (ignoring _* system users)
user_list=$(dscl . list /Users | grep -v '^_')

for username in $user_list; do
    # Skip exempt users (exact name match)
    is_exempt=false
    for exempt in "${exempt_users[@]}"; do
        if [[ "$username" == "$exempt" ]]; then
            is_exempt=true
            break
        fi
    done
    if [[ "$is_exempt" == true ]]; then
        echo "Skipping exempt: $username"
        continue
    fi

    # Check if the user is stale, capture return value, and delete if needed
    check_stale_user "$days_since_login" "$username"
    result=$? 
    if [ "$result" -eq 1 ]; then
        delete_user "$username"
    fi
done

echo "##############################################################"
echo "# Ending $script_name"
echo "############################################################"