# Existing legacy security warning

> **Synthetic sanitized example.** This is not real hardware-validation evidence.

Context: diagnosis finds that legacy SMB compatibility settings are already enabled. This example is about security posture, not proof that those settings caused the printing failure.

```json
{
  "Schema": "windows-printer-sharing-fix/diagnosis",
  "SchemaVersion": 1,
  "ToolVersion": "4.1.0",
  "Windows": {"Name": "Windows 11", "DisplayVersion": "24H2", "Build": 26100},
  "SMB1Client": "Enabled",
  "Policies": {
    "GuestAuth": {"Present": true, "Value": 1, "Kind": "DWord"}
  },
  "Findings": [
    {"Severity": "WARN", "Text": "Insecure SMB guest authentication is enabled."},
    {"Severity": "WARN", "Text": "SMB1 client is enabled."}
  ],
  "TargetPath": null
}
```

## Earliest useful signal

This is not a transport failure signal. It is an early **security-posture warning**: the machine already has legacy/reduced-security compatibility state enabled.

## What this does not prove

Do not assume SMB1 or insecure guest access is required for the printer just because it is currently enabled. Microsoft strongly discourages SMB1, and insecure guest logons remove normal authentication protections and don't support standard SMB signing/encryption. Diagnose the actual failing layer before adding or retaining a legacy downgrade.
