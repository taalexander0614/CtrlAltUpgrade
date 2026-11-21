# Palo Alto unblocked threats (Wazuh rules)

Four Wazuh rules for Palo Alto Networks firewall Threat logs that raise an alert only when a person needs to look:

| Rule | Level | Fires on |
|---|---|---|
| 100200 | 12 | A high or critical threat the firewall only logged (the action was not a block) |
| 100201 | 3 | The same threat on the same destination again within an hour |
| 100202 | 12 | A DNS lookup the firewall sinkholed, any severity |
| 100203 | 3 | The same signature from the same source again within 24 hours |

Blocked threats keep their normal built-in rules, so they stay searchable in the dashboard without paging anyone. The two level 3 rules take over for repeats, so one scan or one infected device gives one alert.

Write-up: [Only alerting on the firewall threats that got through](https://www.ctrlaltupgrade.com/blog/firewall-threats-that-got-through/).

## What you need
- Wazuh manager with Palo Alto Threat logs arriving over syslog and decoded by the built-in Palo Alto decoder and rules
- Something listening for your alert level (an integration, email alerts, or just a dashboard filter)

## Install
1. Check the parent rule IDs (64501-64504) against your Wazuh version's built-in Palo Alto rules, and change the four rule IDs if they clash with your own custom rules.
2. Copy `paloalto_unblocked_rules.xml` to `/var/ossec/etc/rules/` (owner `root`, group `wazuh`, mode 640).
3. Test before restarting: `/var/ossec/bin/wazuh-analysisd -t`, then paste a few real Threat log lines into `/var/ossec/bin/wazuh-logtest` and check which rule each one lands on. Paste the same line three times to see the repeat rule take over.
4. Restart `wazuh-manager`.

To roll back, delete the file and restart the manager.

## Things to check
- **Sinkhole source.** If your devices use an internal DNS server, the sinkholed lookup may come from that server, not the device. You'll need the DNS server's query log to find which device asked.
- **Volume.** How many sinkhole alerts you get depends on whether your Anti-Spyware profile uses the sinkhole action and what else filters DNS and web traffic first. If it's noisy, drop 100202 to a lower level or narrow it by severity.
- **Privacy.** Threat logs can include usernames (with User-ID) and device addresses. Keep alerts in your security tools; don't paste them into tickets or chat that more people can see.
