# macOS shell scripts (Intune)

Shell scripts for Macs managed through Intune. Each logs to `/var/log/<org>/<script name>/`; set the organization name at the top.

| Script | What it does |
|---|---|
| `cleanup_users.sh` | Deletes local user accounts (UID 501 and up) that have never signed in or haven't signed in for `days_since_login` days (default 90), skipping the accounts in `exempt_users`. Useful for shared lab Macs. |
| `Apps/Adobe/install_custom_package.sh` | Downloads a custom Adobe package (built in the Adobe Admin Console) from an internal web server, removes existing Adobe apps, and installs the package. Set `package_name`, `iis_ip` and `apps_to_install`. Marked work in progress in the script. |
| `Apps/GMetrix/install_plugins.sh` | Downloads the GMetrix extensions for Adobe apps and installs them into the CEP extensions folder, so students can use them without admin rights. On a schedule it only re-downloads when there's a newer release. |

`cleanup_users.sh` deletes accounts and their data. Run it on a test Mac first and check the exemption list.
