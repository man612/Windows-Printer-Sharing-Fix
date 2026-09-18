# Quick Start

## Recommended path

1. Open the latest GitHub Release.
2. Download `Windows-Printer-Sharing-Fix-vX.Y.Z.zip`.
3. Extract the ZIP to a normal writable folder.
4. Double-click `FixPrinter.bat`.
5. Accept the Administrator prompt.
6. Run **Diagnose this PC** before any repair.

## Optional release verification

Stable releases include `SHA256SUMS.txt`; releases produced by the current hardened workflow also carry GitHub build-provenance attestations. See [RELEASE-INTEGRITY.md](RELEASE-INTEGRITY.md) for copy-paste verification commands before running the ZIP.

## Headless / automation

From an already-elevated PowerShell session, the stable script can run the same read-only diagnosis without opening the TUI:

```powershell
.\FixPrinter.ps1 -DiagnoseOnly -Json C:\Temp\printer-diagnosis.json
```

`-JsonOutput` is the canonical parameter name and `-Json` is its alias. If no path is provided, the tool overwrites the deterministic headless file at `%LOCALAPPDATA%\WindowsPrinterSharingFix\exports\diagnostic-headless.json`. Headless mode never launches its own UAC prompt; a non-elevated invocation exits with code `5`. Other failures exit nonzero instead of waiting for menu input.

The output follows [`diagnosis.schema.json`](diagnosis.schema.json).

## Reading the menu

- **Safe Repair**: first-line repair; must not lower printer/network security protections.
- **Compatibility Repair**: targeted workaround after diagnosis provides evidence.
- **Legacy Compatibility**: last resort for proven old-device requirements.
- **Restore**: returns the latest managed settings to their captured previous state when technically possible.

## Before sharing a diagnostic report

Use **Tools and Logs > Export latest diagnosis as sanitized JSON** when machine-readable evidence is useful. The JSON reuses the latest diagnosis object and omits common machine/network identifiers, printer/share names, IP addresses, and raw event messages. Review every file before posting it publicly. For short examples of what useful sanitized evidence looks like, see [examples/README.md](examples/README.md).

## Runtime files

Logs, structured diagnosis exports, language preference, and managed restore snapshots are stored under `%LOCALAPPDATA%\WindowsPrinterSharingFix` by default.

For Bahasa Indonesia, switch language from the TUI or read [README.id.md](README.id.md).
