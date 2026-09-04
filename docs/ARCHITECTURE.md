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
- WPP indicators.
- RPC policy state.
- Point and Print policy state.
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

Managed state currently includes:

- Registry values that v4 can modify.
- Relevant service running/startup state.
- Network category by InterfaceIndex.
- File and Printer Sharing firewall-rule enabled/profile state.
- SMB1 client optional-feature state.

Restore changes only those managed states. It does not import an old copy of the complete Windows Print registry tree.

This reduces the chance of rolling unrelated printers or newer Windows configuration backwards.

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

## Future work

The public roadmap is maintained in [ROADMAP.md](../ROADMAP.md). Useful technical directions include:

- More precise driver classification (IPP/inbox/v3/v4/vendor).
- Optional guided test-page verification.
- Structured diagnostic JSON export in addition to text.
- More detailed PrintService event interpretation by event ID.
- A disposable-VM integration harness for host/client combinations.
- Detecting whether policy values are local, domain, or MDM-controlled before offering any conflicting change.
