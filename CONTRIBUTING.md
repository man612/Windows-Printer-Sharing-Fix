# Contributing to Windows Printer Sharing Fix

Version 4 uses a small Batch launcher plus a PowerShell 5.1 diagnosis/repair TUI.

## Design rules

1. **Diagnose before changing.** New repair actions should have a clear failure mode they are intended to solve.
2. **Prefer the smallest change.** Do not add broad registry/firewall/service resets when a targeted action can solve the same problem.
3. **Safe Repair must stay safe.** It must never contain printer/network security downgrades.
4. **Compatibility downgrades belong in Advanced/Legacy.** Explain the security consequence and require explicit confirmation for high-risk changes.
5. **Snapshot before modification.** If v4 manages a new reversible setting, add it to the restore snapshot model.
6. **Do not automate blank-password remote logon.** `LimitBlankPasswordUse=0` is prohibited.
7. **Do not reintroduce undocumented tweaks as critical fixes.** A registry change should have a clear source, scope, affected Windows versions, and verification method.
8. **Keep Windows PowerShell 5.1 compatibility.** Avoid PowerShell 7-only syntax/features in `FixPrinter.ps1`.
9. **Keep the Batch file a launcher.** Repair logic belongs in PowerShell.
10. **Log meaningful changes and failures.** Never hide a security-relevant failure.

## Before submitting a pull request

Run:

```powershell
powershell.exe -NoProfile -File .\tests\Validate.ps1
```

The GitHub Actions workflow runs the same validation on Windows.

For changes that affect real repair behavior, also test the relevant host/client scenario on disposable Windows machines or VMs. Do not test security downgrades on an exposed production network merely to confirm that the code path runs.

## Useful bug reports

Include:

- Windows version/build.
- Host, client, or host+client role.
- Printer model and whether it uses a modern IPP/Windows inbox path or a third-party legacy driver, if known.
- WPP enabled/disabled, if relevant.
- Printer UNC path with sensitive names anonymized if necessary.
- Exact error code/message.
- Exported v4 diagnostic report and relevant log section.
- What changed immediately before the problem appeared.

## Pull requests

Keep changes focused and explain:

- The real-world failure scenario.
- Why the proposed change fixes that scenario.
- Security and compatibility trade-offs.
- What gets modified.
- How the change is verified.
- How the change is rolled back.
