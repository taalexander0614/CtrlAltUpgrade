# Windows Activations

A detection-only script for an Intune Remediation, used as a report.

`Detection.ps1` outputs the Windows edition and activation status. It exits 0 when Windows is activated (and notes Home editions), and exits 1 with the meaning of the activation status when it isn't, so unactivated devices show up as "with issues" in the Remediations report. There's no remediation script; fix activation per device.
