# Sanitized Diagnosis Examples

> **Synthetic sanitized examples.** These files are documentation fixtures, not real host/client validation evidence and not reports from a user's machine.

Use these examples to see how much evidence is usually enough for a useful bug or compatibility report. They intentionally keep the signal that matters while omitting machine, user, printer/share, IP, and other environment-specific identifiers.

The JSON blocks are intentionally **trimmed excerpts**: only fields relevant to each scenario are shown. Use `docs/DIAGNOSTIC-JSON.md` for the full schema.

| Scenario | Earliest useful signal | Example |
| --- | --- | --- |
| Healthy Windows 11 baseline | No transport/diagnosis layer fails; functional printing still needs verification | [Healthy baseline](healthy-windows11.md) |
| Hostname/DNS failure | `TargetPath.DnsResolved = false` | [Name-resolution failure](dns-name-resolution-failure.md) |
| SMB / TCP 445 failure | DNS works, then `TargetPath.Smb445Reachable = false` | [SMB 445 unreachable](smb-445-unreachable.md) |
| WPP + legacy-driver compatibility | Basic transport works, WPP is enabled, printer is not installed | [WPP compatibility warning](wpp-legacy-driver-warning.md) |
| Existing legacy security downgrade | Diagnosis reports SMB1/insecure guest state already enabled | [Legacy security warning](legacy-security-warning.md) |

## How to imitate these in an issue

1. Run **Diagnose this PC** first.
2. Prefer **Tools and Logs > Export latest diagnosis as sanitized JSON** for machine-readable evidence.
3. Include only the fields needed to show the earliest useful signal and the relevant context.
4. State what you actually verified. A healthy transport check is not the same as a successful printed page.
5. Review the file before posting it publicly; sanitized output still contains Windows/policy posture information.

The examples are deliberately ordered by troubleshooting layer: name resolution, SMB transport, RPC/share namespace, then driver/WPP compatibility. Do not jump to a security downgrade while a more basic layer is already failing.

## Why these examples use these boundaries

Microsoft documents TCP 445 as the direct-hosted SMB path used for modern file and printer sharing. Microsoft also documents that Windows protected print mode uses the Windows Ready Print path and prevents third-party driver loading; printers installed with third-party drivers can be removed when WPP is enabled. SMB1 and insecure guest access are treated as legacy/security-reducing compatibility paths, not first-line fixes.

References:

- https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/direct-hosting-of-smb-over-tcpip
- https://learn.microsoft.com/en-us/windows-server/storage/file-server/best-practices-analyzer/smb-open-file-sharing-ports
- https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/windows-protected-print-mode
- https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/more-information-on-windows-protected-print-mode-for-enterprises-and-developers
- https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3
- https://learn.microsoft.com/en-us/windows-server/storage/file-server/enable-insecure-guest-logons-smb2-and-smb3
