# Experimental OpenTUI frontend

> **Status: experimental / alpha. Not recommended for normal use.**
>
> The stable and recommended interface is still the PowerShell TUI launched by `FixPrinter.bat` from the repository root.

This folder explores a modern mouse-aware frontend for Windows Printer Sharing Fix using OpenTUI + Solid. It reuses the existing PowerShell diagnosis/repair engine through `EngineApi.ps1`; it is not intended to replace the stable interface yet.

## Current alpha goals

- responsive terminal layout instead of assuming fullscreen;
- mouse hover/click while keeping full keyboard navigation;
- command palette, loading indicators, dialogs, and inline guidance;
- complete English / Indonesian UI localization;
- preserve the existing diagnosis-first and minimal-repair safety model.

## Known status

The frontend is usable as a development preview, but UI/UX is still being redesigned and real-world interaction testing is incomplete. Do not treat this branch as a stable release or support path.

## Development

Requires Bun for development/build only. End-user packaging is intended to produce a standalone Windows executable.

```powershell
cd tui
bun install
bun run typecheck
bun run build:win
```

Generated binaries and `node_modules` are intentionally not committed.