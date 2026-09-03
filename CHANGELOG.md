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
- Restore snapshots scoped to the type of state an action actually changes (Registry, Services, Network, Firewall, or SMB1).
- Targeted network-profile selection by InterfaceIndex.
- World-ready File and Printer Sharing firewall group detection.
- Separate Legacy compatibility actions.
- Windows PowerShell 5.1 CI syntax/safety validation.
- Non-destructive Windows runtime smoke test that executes the real diagnosis functions and verifies the managed-state fingerprint is unchanged.
- Architecture and integration test documentation.

### Changed

- `FixPrinter.bat` is now a launcher only.
- Firewall repair is limited to Domain/Private profiles.
- SMB1 compatibility enables the client component only instead of the complete feature tree.
- Restore reverts only state captured for the relevant action instead of importing an old broad Print registry tree or rolling back unrelated managed settings.
- High-risk compatibility changes require explicit typed confirmation.
- Printer-connection removal explicitly warns that the generic Restore action cannot recreate the removed connection.
- PowerShell collection handling is hardened for zero/one/many printer, network, and PrintService results under StrictMode.
- GitHub Actions uses the Node 24 generation of `actions/checkout`.

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
