# Changelog

## 4.0.0

Major diagnosis-first redesign.

### Added

- PowerShell 5.1 terminal UI (`FixPrinter.ps1`).
- English-first main interface with optional Indonesian menu labels.
- Local printer-sharing diagnostic report.
- Host/client role inference.
- Windows Protected Print Mode detection.
- Recent PrintService event inspection.
- Targeted UNC printer-path test for DNS, SMB 445, RPC 135, host namespace, and local connection state.
- Safe Repair tier with no printer/network security downgrade.
- Role-aware RPC Named Pipes compatibility fallback.
- Temporary Point and Print relaxation around one printer connection attempt with `finally` rollback.
- Managed JSON restore snapshots.
- Targeted network-profile selection by InterfaceIndex.
- World-ready File and Printer Sharing firewall group detection.
- Separate Legacy compatibility actions.
- Windows PowerShell 5.1 CI syntax/safety validation.
- Architecture and integration test documentation.

### Changed

- `FixPrinter.bat` is now a launcher only.
- Firewall repair is limited to Domain/Private profiles.
- SMB1 compatibility enables the client component only instead of the complete feature tree.
- Restore reverts managed state rather than importing an old broad Print registry tree.
- High-risk compatibility changes require explicit typed confirmation.

### Removed from default repair

- Permanent `RpcAuthnLevelPrivacyEnabled=0` in Quick Fix.
- Permanent `RestrictDriverInstallationToAdministrators=0` in Quick Fix.
- `BypassUpdateRoleIndicator` tweak.
- Whole Client Side Rendering Print Provider registry deletion.
- Recursive automatic spool-driver ACL rewrite.
- One-click insecure Full Fix.
- Automatic `LimitBlankPasswordUse=0`.
- Changing every detected network profile to Private.

### Security note

v4 keeps compatibility workarounds available where technically useful, but no longer treats a security downgrade as a normal first-line printer repair.
