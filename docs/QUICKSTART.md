# Quick Start

## Recommended path

1. Open the latest GitHub Release.
2. Download `Windows-Printer-Sharing-Fix-vX.Y.Z.zip`.
3. Extract the ZIP to a normal writable folder.
4. Double-click `FixPrinter.bat`.
5. Accept the Administrator prompt.
6. Run **Diagnose this PC** before any repair.

## Reading the menu

- **Safe Repair**: first-line repair; must not lower printer/network security protections.
- **Compatibility Repair**: targeted workaround after diagnosis provides evidence.
- **Legacy Compatibility**: last resort for proven old-device requirements.
- **Restore**: returns the latest managed settings to their captured previous state when technically possible.

## Before sharing a diagnostic report

Redact usernames, hostnames, printer share names, IPs, internal domains, credentials, and other sensitive environment details that are not needed to reproduce the problem.

## Runtime files

Logs, language preference, and managed restore snapshots are stored under `%LOCALAPPDATA%\WindowsPrinterSharingFix` by default.

For Bahasa Indonesia, switch language from the TUI or read [README.id.md](README.id.md).
