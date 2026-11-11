# Linux Server Baseline (Ansible)

A re-runnable baseline for Ubuntu servers, built from small playbooks that can each run on their own. Written up in [One Ansible playbook to baseline every Linux server](https://www.ctrlaltupgrade.com/blog/linux-server-baseline-ansible/).

This is a sanitized copy of what I run at work: organization names, addresses and internal paths are replaced with variables and `example.internal` placeholders.

| Playbook | What it does |
|---|---|
| `server-baseline.yml` | Imports everything below, in order. Safe to re-run; doubles as a drift check. |
| `configure-certificates.yml` | Installs your internal root CA(s), validates each file with `openssl` first, then verifies against the trust store. |
| `configure-ssh.yml` | Key-only SSH via a drop-in file; validates the full config with `sshd -t` before reloading. `serial: 1`. |
| `configure-time.yml` | Time zone + chrony pointed at your NTP servers; waits until the clock actually syncs. |
| `configure-updates.yml` | Unattended security upgrades, never reboots on its own. |
| `provision-wazuh-agent.yml` | Installs the Wazuh agent at a pinned version, enrolls it, and holds the package. Refuses to touch a manager host. |
| `provision-zabbix-agent.yml` | Installs Zabbix Agent 2 (PSK encryption, active checks) with the `community.zabbix` role and registers the host through the API, after testing API access first. |
| `baseline-monitoring.yml` | Maintenance: asserts agent configs exist and aren't empty, validates the Zabbix config, keeps both agents pinned and running. |

## Requirements
- Ansible 2.15+ with `community.general` and `community.zabbix`
- Ubuntu 24.04 or 26.04 targets in an inventory group named `linux_servers`
- Copy `group_vars/all.example.yml` to `group_vars/all.yml` and fill it in
- Secrets (`zabbix_api_token`, `wazuh_enroll_key`) passed at run time (Semaphore secret variables or Ansible Vault), never committed

## Running
```bash
ansible-playbook -i inventory.yml server-baseline.yml --check --diff   # dry run first
ansible-playbook -i inventory.yml server-baseline.yml -e @secrets.yml
```
In Semaphore: one template pointing at `server-baseline.yml`, your inventory, and a variable group holding the two secrets.

## License
GPL-3.0, like the rest of this repository. Use at your own risk; test against a non-production server first.
