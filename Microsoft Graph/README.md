# Microsoft Graph helper modules

Small PowerShell modules for calling Microsoft Graph with an app registration. Import the ones you need with `Import-Module`.

| Module | Function |
|---|---|
| `Get-AccessToken.psm1` | Gets an app-only access token (client credentials) from `-tenantID`, `-appID`, `-appSecret`. |
| `Invoke-MSGraphCall.psm1` | Calls any Graph endpoint, with optional method, body, `$select`, `$filter`, `$search`, consistency level and extra headers. Follows paging. |
| `Invoke-DeltaCheck.psm1` | Runs a delta query on an endpoint and returns the changes plus the delta link for the next check. |
| `Invoke-SendEmail.psm1` | Sends mail as a mailbox through Graph, with CC/BCC and an optional attachment. |

```powershell
Import-Module .\Get-AccessToken.psm1, .\Invoke-MSGraphCall.psm1
$token = Get-AccessToken -tenantID $tenant -appID $app -appSecret $secret
Invoke-MSGraphCall -accessToken $token -endpoint 'deviceManagement/managedDevices' -select 'deviceName,serialNumber'
```
Grant the app only the Graph permissions your calls need.
