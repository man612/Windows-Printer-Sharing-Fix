# Healthy Windows 11 baseline

> **Synthetic sanitized example.** This is not real hardware-validation evidence.

Context: a Windows 11 client has an existing network-printer connection. The host path is reachable and the local connection is installed.

```json
{
  "Schema": "windows-printer-sharing-fix/diagnosis",
  "SchemaVersion": 1,
  "ToolVersion": "4.0.3",
  "Windows": {"Name": "Windows 11", "DisplayVersion": "24H2", "Build": 26100},
  "Role": "Client",
  "Spooler": {"Present": true, "Status": "Running"},
  "PrinterSummary": {"Total": 2, "Shared": 0, "NetworkConnections": 1},
  "WPP": {"Enabled": false},
  "SMB1Client": "Disabled",
  "Findings": [],
  "TargetPath": {
    "DnsResolved": true,
    "Smb445Reachable": true,
    "Rpc135Reachable": true,
    "ShareNamespaceAccessible": true,
    "PrinterInstalled": true,
    "LikelyLayer": "HealthyPrerequisites"
  }
}
```

## Earliest useful signal

There is no failing diagnostic layer in this excerpt. DNS, SMB, RPC, the share namespace, and the installed connection all look healthy.

## What this does not prove

It does **not** prove that a page actually printed. A real print/test-page result is still the final functional verification.
