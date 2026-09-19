# v4 Architecture

## Goal

Windows Printer Sharing Fix v4 is designed as a troubleshooting tool, not a collection of registry tweaks.

The architecture separates four stages:

```text
Observe -> Classify -> Change -> Verify / Restore
```

## Entry point

`FixPrinter.bat` exists only for convenience. It verifies that Windows PowerShell and `FixPrinter.ps1` exist, then launches the PowerShell implementation.

No printer, registry, firewall, SMB, RPC, or service repair logic should be added to the Batch file.

## TUI layer

`FixPrinter.ps1` provides a dependency-free terminal UI using normal Windows PowerShell console primitives. It avoids third-party terminal frameworks so the utility remains easy to inspect and deploy.

English is the default (`EN`). Indonesian (`ID`) is optional through the Language menu. Runtime preference is stored under `%LOCALAPPDATA%\WindowsPrinterSharingFix` by default, not in the Git working tree.

## Diagnostic model

The local diagnostic gathers evidence before recommending compatibility changes:

- OS/build.
- PowerShell version.
- Spooler status.
- Printer inventory.
- Shared-printer host role.
- Network-printer client role.
- Network profile category.
- WPP indicators plus privacy-safe local Windows Ready Print / third-party binding readiness evidence.
- RPC policy state, including explicit print-RPC TCP port, Kerberos listener enforcement, and remote Spooler RPC endpoint state.
- Point and Print policy state.
- Modern SMB client/server signing and encryption posture.
- SMB1 state.
- SMB insecure guest state.
- LAN Manager compatibility state.
- Blank-password restriction state.
- Recent PrintService events.

The target-path diagnostic adds network-layer evidence for a UNC printer path:

```text
\\HOST\Printer
   |
   +-- name resolution
   +-- TCP 445 / SMB
   +-- TCP 135 / RPC endpoint mapper
   +-- host share namespace
   +-- installed local printer connection
```

The intent is to avoid changing printer security policy when the actual failure is DNS, routing, firewall, credentials, or WPP/driver compatibility.

## Repair tiers

### Safe Repair

Allowed categories:

- Restart Spooler.
- Clear pending queue only after irreversible-action confirmation.
- Enable/limit File and Printer Sharing firewall rules to Domain/Private.
- Change one explicitly selected active network interface to Private.
- Start Network Discovery services.

Forbidden categories:

- RPC privacy downgrade.
- Point and Print security downgrade.
- SMB1.
- Insecure guest authentication.
- LAN Manager downgrade.
- Blank-password remote logon.

`tests/Validate.ps1` enforces these boundaries statically.

### Compatibility Repair

Advanced compatibility actions are independent, not bundled.

- RPC Named Pipes fallback is role-aware.
- Point and Print relaxation is temporary around one specific connection attempt and restored in `finally`.
- WPP is detected and explained; Group Policy enforcement is not bypassed.
- Network-printer connection reset targets one selected connection.
- RPC privacy downgrade requires explicit `RISK` confirmation.

### Legacy Compatibility

There is no one-click Full Fix.

Each legacy behavior is isolated:

- SMB1 client only.
- Insecure SMB guest authentication.
- LAN Manager compatibility level 1.
- Blank-password remote logon is intentionally not automated.

## Managed restore state

Before repair changes, v4 writes a timestamped `managed-state.json` snapshot under the runtime data root (`%LOCALAPPDATA%\WindowsPrinterSharingFix` by default). Existing repository-local v4 backup state is migrated when possible so an upgrade does not silently discard the latest managed restore state.

Legacy v4 service snapshots that contain `StartMode` remain valid for compatibility, but Restore intentionally ignores that field because no managed repair changes service startup type.

Restore action identity is enforced by a centralized contract shared by snapshot creation and validation. Each action defines its allowed scope and managed registry/service targets. RPC Named Pipes is the only registry action whose contract permits a subset, because Client-only and Host-only machines change different values; the snapshot must match the exact role-specific mutation set. A managed target from a different action is rejected even if that target is otherwise known to the application.

Managed state currently includes only the subset relevant to the action being performed:

- only the registry values that action can modify;
- only the runtime state of services that action can stop/start; service startup type is not managed because repair actions never change it;
- only the selected network profile when changing a network category;
- only File and Printer Sharing firewall rules that the repair can actually rewrite;
- the SMB1 client optional-feature state only for the SMB1 client action.

Restore changes only those managed states. It does not import an old copy of the complete Windows Print registry tree.

Before any restore mutation, the latest pointer and snapshot are treated as untrusted input. Registry snapshot capture uses strict registry reads so an access/read failure cannot be mistaken for an absent value. Restore writes are followed by state read-back for registry values, firewall rules, network profiles, Windows features, and services; a command returning without error is not sufficient for success.

This reduces the chance of rolling unrelated printers or newer Windows configuration backwards, and prevents a damaged or edited snapshot from expanding Restore beyond state that the tool is designed to manage.

Temporary Point and Print compatibility uses a managed snapshot as an emergency rollback anchor while protection is lowered. The printer connection is also read back from inventory before the connection attempt may report success. After the original registry state is restored successfully, the temporary snapshot is removed and the previous `Restore latest` pointer is reinstated. If rollback cannot be confirmed, the emergency snapshot is deliberately retained as the latest recovery state.

## Irreversible actions

Some state cannot be recreated by a troubleshooting script. Queue deletion is the clearest example. The UI therefore requires a warning/confirmation before deleting pending print jobs.

## Windows 2026 assumptions

v4 treats these as first-class conditions:

- Windows Protected Print Mode.
- Modern Windows inbox/IPP printing direction.
- Ongoing retirement of third-party legacy print-driver servicing.
- Modern RPC security defaults.
- Point and Print post-PrintNightmare security behavior.

Legacy compatibility remains available for real old environments, but is no longer treated as a normal baseline.

## Engineering validation

The stable PowerShell implementation is guarded by layered tests rather than a single lint pass:

- runtime/state-fingerprint smoke tests prove diagnosis paths do not mutate managed Windows state;
- restore-safety smoke tests reject out-of-root, malformed, scope-mismatched, and unmanaged snapshot targets before confirmation or mutation;
- repair-outcome smoke tests inject Windows-command failures and require the TUI to suppress success reporting while exercising recovery paths;
- repair-postcondition smoke tests model successful/no-op Windows commands and require read-back confirmation before a repair may report success;
- managed-Restore outcome smoke tests inject failures across restore categories, require remaining categories to continue, and prohibit success unless every requested restore operation succeeds;
- service-restore-scope smoke tests prove new snapshots omit startup type and legacy snapshots restore runtime state without `Set-Service -StartupType`;
- restore-action-contract smoke tests require RPC role-specific snapshots to equal the actual mutation set and reject cross-action managed targets;
- PSScriptAnalyzer 1.25.0 runs Error/Warning analysis using the documented repository profile;
- intentional TUI/style conflicts are explicitly excluded, while actionable diagnostics are fixed rather than hidden;
- repository-hygiene tests require governance files, explicit workflow permissions, full-SHA GitHub Action pinning, and weekly GitHub Actions Dependabot configuration;
- documentation tests validate relative Markdown links and the core README documentation index;
- deterministic package and release-workflow tests protect ZIP reproducibility, checksums, provenance, and draft-before-publish ordering.

The remaining major validation gap is real disposable host/client coverage across Windows/printer combinations. That work is tracked separately in the public roadmap and real-world results documents.
