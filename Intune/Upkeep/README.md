# Intune upkeep

Scheduled maintenance against Intune through Microsoft Graph, using an Entra ID app registration (client credentials). Set `$tenantID`, `$appID` and `$secret` at the top, and keep the real secret out of the script (a secure store or scheduled-task credential).

| Script | What it does |
|---|---|
| `IntuneDeviceCleanup.ps1` | Finds managed devices that share a serial number and deletes all but the newest record. |
| `RemoveAllPrimaryUsers.ps1` | Removes the primary user from every Windows device, for shared devices that shouldn't be tied to one person. |

Both delete or change records in Intune. Try them against a small filter or a test tenant first.
