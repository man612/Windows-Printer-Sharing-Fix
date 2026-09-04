# Contributing to Windows Printer Sharing Fix

Thanks for helping improve a small Windows troubleshooting project. Useful contributions are not limited to code: reproducible bug reports, hardware/driver compatibility results, documentation, translations, and tests are all valuable.

## Start here

- For a bug in existing behavior, use the **Bug report** issue form.
- For an old printer/driver/network compatibility case, use **Compatibility report**.
- For a proposed capability, use **Feature request**.
- For questions or working-setup notes, prefer GitHub Discussions.
- New contributors can look for `good first issue` and `help wanted` labels.

Before posting logs or diagnostics, remove credentials, usernames, internal hostnames/domains, private addresses, and any unrelated sensitive environment details.

## Development baseline

Stable v4 uses a small Batch launcher plus a Windows PowerShell 5.1 diagnosis/repair TUI.

```text
FixPrinter.bat  -> launcher only
FixPrinter.ps1  -> diagnosis, TUI, repair and restore logic
tests/          -> static/runtime/localization/package guards
docs/           -> architecture and integration guidance
```

Keep `FixPrinter.ps1` compatible with Windows PowerShell 5.1. Do not introduce PowerShell 7-only syntax into the stable path.

## Design rules

1. **Diagnose before changing.** A repair needs a real failure mode and a way to verify it.
2. **Prefer the smallest change.** Do not add broad registry/firewall/service resets when a targeted action is enough.
3. **Safe Repair must stay safe.** It must never contain printer/network security downgrades.
4. **Compatibility downgrades belong in Advanced/Legacy.** Explain the consequence and require explicit confirmation where appropriate.
5. **Snapshot reversible state before modification.** Extend the managed restore model when a new reversible setting is added.
6. **Never automate blank-password remote logon.** `LimitBlankPasswordUse=0` is prohibited.
7. **Do not promote undocumented registry tweaks to critical fixes.** Document source, scope, affected Windows versions, and verification.
8. **Keep the Batch file a launcher.** Repair logic belongs in PowerShell.
9. **Log meaningful changes and failures.** Do not hide security-relevant failures.
10. **Keep user-facing English and Indonesian paths in sync.** Add or update localization smoke coverage for new primary UI text.

## Local validation

Run the full stable test set before opening a PR:

```powershell
powershell.exe -NoProfile -File .\tests\Validate.ps1
powershell.exe -NoProfile -File .\tests\RuntimeSmoke.ps1
powershell.exe -NoProfile -File .\tests\LocalizationSmoke.ps1
powershell.exe -NoProfile -File .\tests\PackageSmoke.ps1
```

Diagnosis-only tests must leave the managed Windows-state fingerprint unchanged.

For changes that affect repair behavior, also test the relevant host/client scenario on disposable Windows machines or VMs. Do not enable legacy/security-reducing settings on an exposed production network just to prove the code path runs.

## A useful pull request explains

- The real-world failure scenario.
- What evidence identifies the failing layer.
- Why the proposed change is narrower than alternative fixes.
- Every Windows state it modifies.
- Security and compatibility trade-offs.
- How the behavior was verified.
- How the change is restored or why it is irreversible.
- Whether English/Indonesian UI or documentation changed.

Keep PRs focused. Large unrelated cleanup mixed into a repair change makes security review harder.

## A useful compatibility report includes

- Windows product/version/build on both host and client when applicable.
- Printer model and driver path (IPP/inbox/v3/v4/vendor), if known.
- WPP state when relevant.
- Network profile and workgroup/domain context.
- Exact error code/message.
- Sanitized diagnostic report and the smallest relevant log excerpt.
- What changed immediately before the failure.
- What repair was attempted and whether restore was used afterward.

See [ROADMAP.md](ROADMAP.md) for areas where testing and documentation contributions are especially useful.
