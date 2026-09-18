# SMB / TCP 445 unreachable

> **Synthetic sanitized example.** This is not real hardware-validation evidence.

Context: name resolution works, but the SMB path needed for the shared namespace is not reachable. RPC 135 is shown reachable to make the failing layer clearer.

```json
{
  "Schema": "windows-printer-sharing-fix/diagnosis",
  "SchemaVersion": 1,
  "ToolVersion": "4.1.0",
  "Windows": {"Name": "Windows 11", "DisplayVersion": "24H2", "Build": 26100, "Revision": 4061, "FullBuild": "26100.4061"},
  "Role": "Client",
  "TargetPath": {
    "DnsResolved": true,
    "Smb445Reachable": false,
    "Rpc135Reachable": true,
    "ShareNamespaceAccessible": false,
    "PrinterInstalled": false,
    "LikelyLayer": "SmbFirewallOrRouting"
  }
}
```

## Earliest useful signal

DNS succeeds, then `Smb445Reachable = false`. That makes SMB/firewall/routing the earliest useful layer to investigate.

Microsoft documents TCP 445 as the direct-hosted SMB path used for modern Windows file and printer sharing.

## What this does not prove

It does **not** mean SMB1 is required, and it does not yet establish a printer-driver problem. Check the normal File and Printer Sharing/firewall/routing path first.
