# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 4.0.0](https://img.shields.io/badge/Version-4.0.0-blue?style=for-the-badge)

> **Experimental branch notice:** the OpenTUI frontend in 	ui/ is an alpha development preview and is **not recommended for normal use yet**. The stable interface remains FixPrinter.bat + FixPrinter.ps1.

A diagnosis-first Windows TUI for troubleshooting shared printers without applying broad security downgrades by default.

Version 4 is a major redesign. `FixPrinter.bat` is now only a small double-click launcher. The actual diagnostics, repair logic, restore system, and terminal UI live in `FixPrinter.ps1`.

## Why v4 exists

Printer sharing failures do not all have the same cause. A stuck queue, Public network profile, blocked SMB/RPC traffic, Windows Protected Print Mode, incompatible legacy driver, Point and Print restriction, and a truly old SMB1-only device require different fixes.

Older versions used broad Quick/Full repair paths that could modify several compatibility and security settings at once. That was effective in some environments, but it could also change more of Windows than the actual problem required.

v4 changes the model to:

```text
Diagnose
   |
Identify the failing layer
   |
Apply the smallest relevant repair
   |
Verify connectivity / printer state
   |
Restore the original managed state if needed
```

## Start here

1. Download or clone the repository.
2. Keep `FixPrinter.bat` and `FixPrinter.ps1` in the same folder.
3. Double-click `FixPrinter.bat`.
4. Accept the UAC Administrator prompt.
5. Choose **Diagnose this PC** first.
6. Only move to Safe Repair, Compatibility Repair, or Legacy Compatibility when the diagnostic result points there.

English is the default language. Indonesian can be selected from the Language menu.

### Ringkas untuk pengguna Indonesia

Jalankan `FixPrinter.bat`, lalu pilih **Diagnose this PC** dulu. Versi 4 tidak lagi langsung menembakkan banyak tweak sekaligus. Tool akan mengecek kondisi Windows, Spooler, printer host/client, network profile, Windows Protected Print Mode, SMB1, Point and Print, RPC, dan log PrintService. Perbaikan yang menurunkan keamanan dipisahkan ke menu Advanced/Legacy dan membutuhkan konfirmasi tambahan.

## Main TUI

```text
==============================================================================
  WINDOWS PRINTER SHARING FIX  v4.0.0
  Diagnosis-first repair utility
  > MAIN MENU
==============================================================================
  OS: Windows 11 build 26100    Language: EN    Spooler: Running
------------------------------------------------------------------------------
[1] Diagnose this PC  <RECOMMENDED>
[2] Safe Repair
[3] Compatibility Repair (Advanced)
[4] Legacy Compatibility (High Risk)
[5] Restore latest managed changes
[6] Tools and Logs
[7] Language
[8] Exit
------------------------------------------------------------------------------
```

The UI intentionally uses a simple terminal layout instead of external GUI libraries so the project remains portable and inspectable on normal Windows installations.

## What Diagnose checks

The diagnostic path currently inspects:

- Windows version and build.
- PowerShell version.
- Print Spooler state.
- Installed printers and shared printers.
- Whether the PC looks like a printer **Host**, **Client**, or both.
- Active network profiles and whether one is Public.
- Windows Protected Print Mode (WPP) policy/state indicators.
- `RpcAuthnLevelPrivacyEnabled`.
- `RpcUseNamedPipeProtocol` and `RpcProtocols`.
- `RestrictDriverInstallationToAdministrators`.
- SMB1 client feature state.
- Insecure SMB guest authentication.
- LAN Manager compatibility level.
- Blank-password remote-logon policy.
- Recent PrintService Admin errors/warnings.

It can also test a specific shared printer path such as:

```text
\\PRINT-PC\OfficePrinter
```

That target test separates several layers:

```text
name resolution
    -> TCP 445 / SMB
    -> TCP 135 / RPC Endpoint Mapper
    -> host share namespace
    -> local printer connection state
```

This is important because a DNS, firewall, credential, WPP, driver, or Point and Print problem should not automatically be treated as an RPC or SMB1 problem.

## Safe Repair

Safe Repair is deliberately restricted. It does **not** disable RPC packet privacy, Point and Print protection, SMB authentication protections, or blank-password restrictions.

Available actions include:

- Restart Print Spooler.
- Clear the stuck print queue, with an explicit warning because pending jobs are permanently deleted.
- Enable File and Printer Sharing firewall rules only for Domain/Private profiles.
- Change one explicitly selected active network profile to Private.
- Start Network Discovery services.
- Run the non-destructive safe actions together.

Unlike v3, changing a network profile is targeted by interface. The tool no longer sends every detected profile through `Set-NetConnectionProfile` at once.

## Compatibility Repair (Advanced)

Compatibility options are separated from Safe Repair.

### RPC Named Pipes fallback

Windows normally prefers printer RPC over TCP. v4 can apply the documented Named Pipes compatibility path without automatically disabling RPC packet privacy.

The action is role-aware:

- Client side: `RpcUseNamedPipeProtocol=1`
- Host side: `RpcProtocols=7`

This is a compatibility fallback, not the preferred default state.

Microsoft reference:
https://learn.microsoft.com/en-us/troubleshoot/windows-client/printing/windows-11-rpc-connection-updates-for-print

### Temporary Point and Print relaxation

If a shared printer cannot install because Windows requires Administrator approval for its driver, v4 can temporarily set:

```text
RestrictDriverInstallationToAdministrators=0
```

The important difference is that v4 does this only around a specific printer connection attempt and restores the original registry state in a `finally` block immediately afterwards.

It is no longer a permanent Quick Fix setting.

Microsoft reference:
https://support.microsoft.com/help/5005652

### Windows Protected Print Mode

Windows 11 can operate in Windows Protected Print Mode. WPP intentionally prevents legacy third-party print drivers from being used while the mode is active.

v4 detects WPP indicators before suggesting unrelated RPC/SMB changes. If WPP appears enforced by Group Policy, this utility does not attempt to bypass the organizational policy.

Microsoft reference:
https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/windows-protected-print-mode

### RPC privacy downgrade

`RpcAuthnLevelPrivacyEnabled=0` still exists as an explicitly high-risk compatibility option because some old environments may depend on it.

It is **not** part of Safe Repair and requires the user to type `RISK` before the setting is changed.

Users should restore the previous state after compatibility testing.

## Legacy Compatibility (High Risk)

There is intentionally no one-click **Full Fix** anymore.

Legacy technologies solve different problems, so v4 exposes them separately:

- Enable **SMB1 client only** for a device proven to be SMB1-only.
- Allow insecure SMB guest authentication.
- Set legacy LAN Manager compatibility level 1.
- Blank-password remote logon is displayed as unsupported and is **not automated**.

### SMB1 is no longer enabled with `-All`

Older versions could enable the full `SMB1Protocol` feature tree. v4 only offers `SMB1Protocol-Client`, reducing the scope of the compatibility change.

Microsoft reference:
https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/smbv1-not-installed-by-default-in-windows

### Blank-password bypass is intentionally blocked

v4 will never automate:

```text
LimitBlankPasswordUse=0
```

Use password-protected credentials instead.

## Windows printing in 2026

Windows printing is moving away from older third-party v3/v4 driver workflows toward the modern IPP / Windows Ready Print path. Windows 11 also increasingly uses Windows Protected Print Mode security boundaries.

The v4 architecture therefore treats driver/platform compatibility as a first-class diagnostic signal rather than assuming every shared-printer failure is an old RPC or SMB problem.

Microsoft third-party printer driver servicing roadmap:
https://learn.microsoft.com/en-us/windows-hardware/drivers/print/end-of-servicing-plan-for-third-party-printer-drivers-on-windows

## Restore model

Every repair action first creates a timestamped snapshot under:

```text
backups\
```

The managed snapshot records the original state of items the v4 utility may change, including:

- Managed printer/RPC/SMB registry values.
- Relevant Windows services and their startup/running state.
- Network profile category per interface.
- File and Printer Sharing firewall-rule state/profile.
- SMB1 client optional-feature state.

Restore applies those recorded states back instead of importing the entire historical `Control\Print` registry tree.

That avoids rolling unrelated printer configuration backwards just because one troubleshooting setting needs to be undone.

### What cannot be restored

Some actions are inherently irreversible:

- Deleted pending print jobs.
- External changes made manually after a snapshot.
- Hardware/router changes outside Windows.

The TUI warns before deleting queued jobs.

## Removed or changed v3 behavior

v4 intentionally removes these broad defaults:

| v3 behavior | v4 behavior |
| --- | --- |
| Quick Fix set `RpcAuthnLevelPrivacyEnabled=0` | High-risk Advanced option only |
| Quick Fix set `RestrictDriverInstallationToAdministrators=0` permanently | Temporary around one connection attempt, then automatically restored |
| Quick Fix deleted the entire Client Side Rendering Print Provider key | Removed; targeted printer-connection reset is used instead |
| Quick Fix recursively changed spool driver ACLs | Removed from automatic repair; no ACL change without evidence |
| Network Private action changed all profiles returned by PowerShell | User selects one active interface |
| Firewall used only English/Indonesian display-group names | Uses Microsoft's world-ready firewall group identifier when available, with display-name fallbacks |
| Full Fix enabled the entire SMB1 feature tree | Legacy option enables SMB1 client only |
| Full Fix allowed blank-password remote logon | Not automated at all |
| Restore imported broad historical Print registry trees | Restore uses managed state snapshots |
| Verification mainly checked whether tweak values were written | Target test also checks DNS, SMB 445, RPC 135 and local connection state |

`BypassUpdateRoleIndicator` is no longer written by v4 because it did not have sufficiently clear modern Microsoft documentation/provenance for inclusion as a critical repair setting.

## Logs

Each run creates a separate timestamped log in:

```text
logs\
```

The Tools menu can open the active log and export a simplified diagnostic report suitable for attaching to a GitHub issue.

## Supported Windows versions

### Windows 11

Primary target for v4. Modern WPP, IPP, RPC, firewall, and print-driver behavior is considered in the diagnostic design.

### Windows 10

Compatibility target. Windows 10 standard support has ended; environments using eligible ESU scenarios should still keep the OS fully patched.

### Windows 7 / 8 / 8.1

Legacy best-effort only. The v4 TUI requires Windows PowerShell 5.1. Some modern networking and printing cmdlets are unavailable on old Windows versions, so diagnostics/actions degrade gracefully where possible.

These operating systems should not be interpreted as security-equivalent to a currently supported Windows 11 system.

## Automated validation

The repository includes `tests/Validate.ps1` and a Windows GitHub Actions workflow.

CI uses Windows PowerShell 5.1 to:

- Parse `FixPrinter.ps1` for syntax errors.
- Confirm the batch file remains only a launcher.
- Ensure Safe Repair cannot contain security-downgrade settings.
- Block the old `BypassUpdateRoleIndicator` tweak.
- Block whole-provider registry deletion.
- Block full SMB1 `-All` enablement.
- Block automation of `LimitBlankPasswordUse=0`.
- Confirm temporary Point and Print relaxation has a restore path.
- Confirm high-risk RPC compatibility requires typed confirmation.

These are guardrails, not a replacement for real host/client integration testing.

## Recommended real-world test matrix

Before tagging v4 as fully stable, test at minimum:

- Windows 11 current build -> Windows 11 current build.
- Windows 11 client -> Windows 10 printer host.
- Host role only, client role only, and host+client machines.
- WPP off and WPP on.
- Modern IPP/Windows Ready Print device.
- Legacy third-party driver printer.
- Private, Public, and DomainAuthenticated network profiles.
- Healthy queue and deliberately stuck queue.
- RPC over TCP normal path and Named Pipes fallback.
- Point and Print admin prompt scenario.
- SMB1-only lab device if one is available.
- Restore after every managed modification.

Never validate SMB1, insecure guest auth, LM compatibility, or RPC privacy downgrade on an exposed production network just to prove that the menu works. Use an isolated lab/VM network.

## Project philosophy

The utility follows four rules:

1. **Diagnose before changing.**
2. **Prefer the smallest fix.**
3. **Security downgrade is never a default repair.**
4. **Every managed change should have a recorded rollback path when technically possible.**

## License

MIT. See `LICENSE`.
