# Name-resolution / basic-network failure

> **Synthetic sanitized example.** This is not real hardware-validation evidence.

Context: the user entered a valid shared-printer path, but the host name could not be resolved.

```json
{
  "Schema": "windows-printer-sharing-fix/diagnosis",
  "SchemaVersion": 1,
  "ToolVersion": "4.1.0",
  "Windows": {"Name": "Windows 11", "DisplayVersion": "24H2", "Build": 26100, "Revision": 4061, "FullBuild": "26100.4061"},
  "Role": "Client",
  "Spooler": {"Present": true, "Status": "Running"},
  "TargetPath": {
    "DnsResolved": false,
    "Smb445Reachable": false,
    "Rpc135Reachable": false,
    "ShareNamespaceAccessible": false,
    "PrinterInstalled": false,
    "LikelyLayer": "NameResolutionOrBasicNetwork"
  }
}
```

## Earliest useful signal

`DnsResolved = false` is the first meaningful failure. Fix hostname/basic-network resolution before interpreting later printer layers.

## What this does not prove

The `false` values for TCP 445 and 135 do **not** prove those ports are blocked. In this path test, the TCP probes cannot proceed normally when the host did not resolve. Do not change printer security policy or driver settings yet.
