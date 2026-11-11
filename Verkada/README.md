# Verkada API modules

PowerShell modules for the Verkada API (Access Control groups and users).

| Module | What it does |
|---|---|
| `Invoke-VerkadaApi.psm1` | Base call: sends a request to a Verkada endpoint with your API key (`x-api-key`) and returns the response. |
| `Invoke-GetVerkadaGroupUsers.psm1` | Lists the users in an access group with their user and access details. |
| `add_remove_users_from_groups.psm1` | Adds a user to, or removes one from, an access group by external ID. |

Create an API key in Verkada Command with only the permissions you need, and pass it in at run time; don't save it in a script.
