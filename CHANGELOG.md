# Changelog

## Unreleased

### Added

- Read-only modern SMB/RPC diagnostics for effective SMB signing/encryption posture, additional print-RPC policies, explicit configured RPC-port reachability, and normalized SMB security-event evidence without automatic security downgrades.
- Deterministic release ZIP construction, reproducibility regression coverage, pinned GitHub Actions, provenance attestation, and draft-before-publish release sequencing.
- Exact Windows servicing-build reporting using the base build plus UBR revision across diagnosis, structured JSON, and lab evidence.
- Headless read-only diagnosis export (`-DiagnoseOnly -Json`) plus a packaged JSON Schema Draft 2020-12 contract for schema version 1.
- Stable target-path `SmbSecuritySignals` JSON serialization as an array even when exactly one normalized signal is present.
- Conservative Windows Protected Print readiness evidence from installed bindings, with aggregate privacy-safe JSON counts and no physical-device compatibility claim.

## 4.1.0 - 2026-09-16

Evidence-first diagnostics, privacy-safe structured reporting, and explicit functional verification.

### Added

- Structured real-world compatibility results ledger for A1-A6 validation evidence.
- Expanded Compatibility report issue form aligned with the integration matrix.
- Read-only `tools/Collect-LabEvidence.ps1` for sanitized local Markdown/JSON evidence.
- Runtime smoke coverage proving evidence collection stays read-only and omits common environment identifiers.
- Optional sanitized structured diagnosis JSON export with schema versioning, same-run timing metadata, and optional sanitized target-path results.
- JSON export smoke coverage proving cached diagnosis reuse, privacy omissions, and an unchanged managed-state fingerprint.
- `docs/DIAGNOSTIC-JSON.md` documenting schema v1, privacy boundaries, storage, and evolution policy.
- Synthetic sanitized diagnosis examples for healthy, DNS, SMB 445, WPP/legacy-driver, and legacy-security scenarios, with CI privacy/JSON guards.
- Conservative PrintService event classification by troubleshooting layer, including normalized Event 372 Win32 code classes without exporting raw event messages.
- Read-only printer-policy source evidence using RSoP plus conservative MDM-aware signals, with normalized privacy-safe provenance labels in structured JSON.
- Conservative `Next layer to investigate` correlation that prioritizes the earliest failed dependency without claiming root cause or recommending security downgrades.
- Evidence-based installed-printer driver classification using Windows driver metadata, with privacy-safe aggregate JSON counts.
- Explicit guided Windows test-page verification with physical-output confirmation and sanitized structured-result export.

### Fixed

- `tools/Build-Release.ps1` can again auto-detect the stable version when `-Version` is omitted; regression coverage now exercises this path.

### Unchanged

- Stable repair behavior and security boundaries remain unchanged; diagnosis/export additions do not broaden the managed Windows mutation set.
- Real A1-A6 host/client compatibility validation remains pending and is not claimed by this release.
- The experimental OpenTUI frontend remains separate and is not included in this stable release.

## 4.0.3

Stable TUI latency and regression-test polish.

### Added

- Performance smoke coverage for bounded DNS/TCP probes and firewall-query reuse.
- Per-stage diagnosis timing in the normal runtime log for future latency troubleshooting.
- CI guard preventing the stable TCP probe from regressing to an OS-controlled `Test-NetConnection` timeout.

### Changed

- Shared-printer path diagnosis now bounds DNS resolution and TCP 445/135 connection attempts with explicit timeouts.
- File and Printer Sharing firewall discovery queries the Windows sharing-rule group directly before using the compatibility fallback scan.
- Safe Repair reuses the firewall inventory captured for its restore snapshot instead of enumerating the same rules a second time.

### Unchanged

- Diagnosis-first workflow, repair tiers, restore scope, and all existing security boundaries.
- Stable UI remains the dependency-free Windows PowerShell 5.1 TUI; the experimental OpenTUI frontend remains separate.

## 4.0.2

Repository, distribution, and runtime-data polish.

### Added

- User-focused release ZIP builder with SHA256 checksum and package smoke test.
- Automatic stable-release asset upload workflow.
- English/Indonesian onboarding split, Quick Start, Roadmap, contributor Code of Conduct, Issue Forms, PR template, and GitHub Actions Dependabot config.
- Programmatic README/social-preview artwork and contributor-facing roadmap.

### Changed

- Runtime logs, language preference, and managed restore snapshots now default to `%LOCALAPPDATA%\WindowsPrinterSharingFix` instead of the repository folder.
- Existing repository-local v4 language preference and backup state are migrated on first run when possible.
- README is front-loaded around quick start, diagnosis-first behavior, safety boundaries, and contribution entry points.
- CI also validates the user release package.

### Unchanged

- Windows-mutating repair primitives and Safe/Advanced/Legacy security boundaries.
- Stable UI remains the dependency-free Windows PowerShell 5.1 TUI.

## 4.0.1

Stable terminal UX and localization polish.

### Added

- Built-in Guide page for non-technical users with the recommended Diagnose -> Safe Repair -> Compatibility -> Legacy -> Verify/Restore flow.
- Indonesian localization smoke test in CI.
- Explicit Windows Server product classification guard for modern shared build numbers such as 26100.

### Changed

- Bahasa Indonesia now covers the stable TUI menus, diagnosis report, UNC path test, repair warnings/prompts, restore flow, tools, status values, and guide content.
- Main terminal menu has clearer visual grouping while remaining dependency-free Windows PowerShell 5.1.
- Windows Server product names are preserved instead of being relabeled as Windows 11 based only on build number.
- Automated validation now covers runtime diagnosis state integrity and Indonesian UI rendering in addition to static safety rules.

### Unchanged

- Safe Repair security boundaries and diagnosis-first repair architecture.
- High-risk typed confirmations and restore behavior.
- `FixPrinter.bat` remains a launcher only.

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
