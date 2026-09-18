# Windows protected print compatibility warning

> **Synthetic sanitized example.** This is not real hardware-validation evidence.

Context: basic host transport is healthy, the printer connection is not installed, WPP is enabled, and the reporter knows this printer previously depended on a vendor/third-party driver.

```json
{
  "Schema": "windows-printer-sharing-fix/diagnosis",
  "SchemaVersion": 1,
  "ToolVersion": "4.2.0",
  "Windows": {"Name": "Windows 11", "DisplayVersion": "24H2", "Build": 26100, "Revision": 4061, "FullBuild": "26100.4061"},
  "Role": "Client",
  "WPP": {"Enabled": true},
  "Findings": [
    {"Severity": "INFO", "Text": "Windows Protected Print Mode appears enabled. Legacy third-party printer drivers can be removed or blocked."}
  ],
  "TargetPath": {
    "DnsResolved": true,
    "Smb445Reachable": true,
    "Rpc135Reachable": true,
    "ShareNamespaceAccessible": true,
    "PrinterInstalled": false,
    "LikelyLayer": "WppCompatibility"
  }
}
```

## Earliest useful signal

The transport checks are healthy, but WPP is enabled and the expected connection is absent. With independent evidence that the printer depends on a third-party driver, WPP compatibility becomes a strong candidate.

Microsoft documents that enabling WPP removes printers using third-party drivers and prevents those drivers from being used while WPP is active.

## What this does not prove

WPP being enabled does not prove every missing printer is incompatible. Confirm the printer/driver path and whether the device can use Windows Ready Print/Mopria-compatible printing before changing policy.
