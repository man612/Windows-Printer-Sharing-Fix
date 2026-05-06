# Windows Printer Sharing Fix

A Windows batch utility for troubleshooting common printer sharing issues on local networks.

This project is designed to help reset and repair several Windows printer sharing components that are commonly involved in shared printer connection errors, spooler problems, RPC-related failures, and legacy network printing issues.

It is intended for home users, technicians, small offices, and local network environments where printers are shared from one Windows computer to another.

The script focuses on repeatable troubleshooting steps, safer execution flow, logging, and registry backup before changes are applied.

---

## Table of Contents

- [Overview](#overview)
- [Supported Windows Versions](#supported-windows-versions)
- [Common Issues](#common-issues)
- [Features](#features)
- [How It Works](#how-it-works)
- [Fix Modes](#fix-modes)
- [Download](#download)
- [Usage](#usage)
- [Recommended Workflow](#recommended-workflow)
- [Backup and Restore](#backup-and-restore)
- [Logs](#logs)
- [Security Notes](#security-notes)
- [What This Tool Changes](#what-this-tool-changes)
- [What This Tool Does Not Do](#what-this-tool-does-not-do)
- [Troubleshooting](#troubleshooting)
- [Known Limitations](#known-limitations)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Windows printer sharing can fail for many different reasons.

Some issues are caused by Windows updates, printer driver compatibility, RPC changes, Print Spooler failures, firewall rules, network discovery settings, SMB compatibility, or incorrect host/client configuration.

This script provides a menu-based troubleshooting utility that applies several known repair steps in a controlled way.

The goal of this project is not to hide failures or force every possible change at once. Instead, the script attempts to:

- Check for administrator privileges
- Detect the Windows version
- Create a backup before applying changes
- Apply selected printer sharing fixes
- Restart required services
- Log command results
- Report warnings or failures
- Provide a restore option for script-managed registry changes

This makes it easier to troubleshoot printer sharing problems without manually typing the same commands repeatedly.

---

## Supported Windows Versions

This project is intended to support the following Windows versions:

- Windows 7
- Windows 8
- Windows 8.1
- Windows 10
- Windows 11

### Notes About Windows 7

Windows 7 support is best-effort.

Some commands, services, and network behavior differ between Windows 7 and newer Windows versions. The script avoids using certain modern commands on older systems when possible.

However, Windows 7 installations can vary widely depending on:

- Installed updates
- System architecture
- Printer driver availability
- Network configuration
- SMB settings
- System file condition
- Modified or customized Windows images

Because of that, the script may not solve every Windows 7 printer sharing problem automatically.

---

## Common Issues

This tool may help with problems such as:

- Shared printer cannot be accessed
- Shared printer is visible but cannot be connected
- Printer sharing stopped working after a Windows update
- Print Spooler service fails or becomes stuck
- Printer queue is stuck
- Shared printer does not appear on the network
- Cannot connect to a printer shared from another Windows PC
- RPC-related printer sharing errors
- Legacy Windows printer sharing issues

Common error codes that may be related include:

- `0x0000011b`
- `0x00000709`
- `0x00000040`
- `0x0000007c`
- `0x000006e4`
- `0x00000bcb`
- `0x00000005`
- `Access is denied`
- `Windows cannot connect to the printer`
- `The printer name is invalid`
- `Operation could not be completed`

This does not mean every error above is guaranteed to be fixed by the script. These errors can have multiple causes.

---

## Features

### Menu-Based Interface

The script provides a simple command-line menu so users can choose the repair mode they want to run.

Main options include:

- Quick Fix
- Legacy / Full Fix
- Restore from backup
- Quick access tools
- User guide
- Language selection
- Log viewer

---

### Administrator Check

Printer sharing repairs often require elevated privileges.

The script checks whether it is running as Administrator before applying system changes.

If it is not elevated, it stops and asks the user to run it again using:

```text
Right-click > Run as administrator
```

---

### Windows Version Detection

The script attempts to detect the current Windows version and build number.

This helps avoid running newer Windows commands on older systems where they may not be available.

For example, some network profile commands are skipped on older Windows versions.

---

### Print Spooler Reset

The Print Spooler is one of the most common causes of printer-related problems.

The script can:

* Stop the Print Spooler service
* Clear stuck printer queue files
* Recreate required spool folders if missing
* Start the Print Spooler service again
* Verify service status after repair

---

### Printer Queue Cleanup

Stuck files inside the spooler queue can prevent printing from working normally.

The script clears files from common spool locations such as:

```text
%SystemRoot%\System32\spool\PRINTERS
%SystemRoot%\System32\spool\SERVERS
```

This can help when print jobs are stuck and cannot be deleted manually.

---

### RPC Compatibility Settings

Some Windows printer sharing problems are related to RPC behavior.

The script can apply selected registry values related to printer RPC compatibility, including settings used in common printer sharing workarounds.

These settings are applied carefully and logged.

---

### Printer Provider Cleanup

The script can remove selected printer provider registry keys that are commonly involved in printer sharing problems.

A backup is created before this step.

---

### Network Discovery Services

The script attempts to configure relevant network discovery services, including:

* Function Discovery Provider Host
* Function Discovery Resource Publication

These services can affect whether shared printers and network devices are visible.

---

### Firewall Rule Handling

The script attempts to enable File and Printer Sharing firewall rules.

Depending on the Windows version and language, firewall rule names may differ. The script attempts to use compatible approaches where possible.

---

### Timestamped Backups

Before applying registry changes, the script creates a timestamped backup folder.

Example:

```text
backups\20260506_143012
```

Each repair run gets its own backup folder instead of overwriting the previous one.

This helps prevent accidental loss of earlier backup states.

---

### State-Aware Restore

The restore function attempts to restore script-managed registry values based on their previous state.

If a value existed before the fix, it can be restored.

If a value did not exist before the fix, it can be removed during restore.

This is more accurate than simply setting all values to a default state.

---

### Logging

All repair actions are logged to:

```text
printer_fix_log.txt
```

The log file includes command results, warnings, and failures.

This is useful when troubleshooting systems where the script does not fully solve the problem.

---

### Language Selection

The script includes basic language selection support.

Depending on the version, available languages may include:

* English
* Indonesian

Language settings may be saved locally using a configuration file.

---

## How It Works

The script works by combining several common troubleshooting steps into a single menu-driven batch file.

The general process is:

1. Check administrator privileges
2. Detect Windows version
3. Show diagnostics
4. Ask the user to select a fix mode
5. Create a backup
6. Stop relevant services
7. Clear spooler cache
8. Apply selected registry settings
9. Configure permissions and services
10. Enable sharing-related firewall rules
11. Restart services
12. Verify important results
13. Write logs
14. Ask the user to restart Windows

The script does not silently assume that every command succeeded.

Where possible, it checks command results and reports warnings or failures.

---

## Fix Modes

## Quick Fix

Quick Fix is the recommended first option.

It applies common printer sharing repair steps without enabling the most risky legacy compatibility settings.

Quick Fix may include:

* Print Spooler reset
* Printer queue cleanup
* Printer RPC compatibility settings
* Selected printer provider cleanup
* Spool folder permission repair
* Network discovery service configuration
* File and Printer Sharing firewall rule activation
* Final service verification

Use this mode first for most printer sharing problems.

---

## Legacy / Full Fix

Legacy / Full Fix is intended for older systems or persistent printer sharing problems that are not solved by Quick Fix.

This mode may apply additional compatibility settings, such as:

* SMBv1-related compatibility
* Insecure guest authentication compatibility
* LAN Manager compatibility settings
* Blank password compatibility settings

Use this mode carefully.

It is mainly intended for trusted local networks, older Windows hosts, and legacy printer sharing setups.

Do not use this mode as the first option unless you understand the security trade-offs.

---

## Download

Download the latest version from the repository:

```text
FixPrinter.bat
```

You can also clone the repository:

```bash
git clone https://github.com/man612/Windows-Printer-Sharing-Fix.git
```

Then run the batch file as Administrator.

---

## Usage

1. Download or clone this repository.
2. Locate the file:

```text
FixPrinter.bat
```

3. Right-click the file.
4. Select:

```text
Run as administrator
```

5. Choose a menu option.
6. Start with Quick Fix.
7. Restart Windows after the repair finishes.
8. Test the shared printer again.

---

## Recommended Workflow

For best results, use this order:

### Step 1: Confirm the Printer Host

Identify which computer is sharing the printer.

The printer host is the PC where the printer is installed locally or shared from.

Example:

```text
Printer Host: OFFICE-PC
Client PC: LAPTOP-01
```

If the problem is on the host, run the script on the host.

If the problem is on the client, run the script on the client.

In some cases, you may need to run the script on both.

---

### Step 2: Run Quick Fix First

Start with Quick Fix.

This mode applies the safer repair steps first.

After it finishes, restart Windows and test the printer again.

---

### Step 3: Check the Log

If the issue is not fixed, open:

```text
printer_fix_log.txt
```

Look for lines marked as:

```text
[WARN]
[FAIL]
[FATAL]
```

These lines can help identify which command failed.

---

### Step 4: Try Legacy / Full Fix Only If Needed

If Quick Fix does not solve the problem and the network is trusted, try Legacy / Full Fix.

This mode is more aggressive and may reduce security.

Use it only when compatibility with older systems is required.

---

### Step 5: Check Driver and Network Settings

If the issue still remains, verify:

* Printer driver compatibility
* Host and client architecture
* Shared printer name
* Network profile
* Firewall rules
* Workgroup or domain settings
* Password-protected sharing
* Hostname or IP address access
* Windows updates

---

## Backup and Restore

Before making registry changes, the script creates a backup folder.

Backups are stored under:

```text
backups\
```

Example:

```text
backups\20260506_143012
```

The backup may include:

* Printer registry key backup
* Printer provider registry backup
* Previous state of selected registry values
* Restore metadata

The restore function attempts to restore the latest backup.

---

## Restore Behavior

The restore option is designed to reverse changes managed by this script.

It can:

* Restore exported registry keys
* Restore selected DWORD values
* Delete selected DWORD values if they did not exist before
* Restart the Print Spooler after restore

However, restore is not a full Windows system restore.

It cannot undo unrelated changes made by:

* Windows Update
* Printer driver installation
* Third-party tools
* Manual registry edits
* Antivirus software
* Group Policy
* Corrupted system files

---

## Logs

The script writes logs to:

```text
printer_fix_log.txt
```

The log file is useful for troubleshooting.

Example log entries may include:

```text
[OK] Started Spooler
[WARN] Firewall rule failed
[FAIL] Required registry setting could not be applied
[FATAL] Backup creation failed
```

If you open an issue, include relevant log lines.

Do not include private information such as usernames, computer names, or network names if you do not want them to be public.

---

## Security Notes

Printer sharing fixes can involve security-sensitive settings.

Some older printer sharing setups require compatibility settings that are no longer recommended for modern networks.

The script separates safer fixes from legacy fixes to avoid applying risky settings unnecessarily.

---

### Quick Fix Security Profile

Quick Fix avoids the most risky legacy compatibility settings.

It is recommended for most users.

---

### Legacy / Full Fix Security Profile

Legacy / Full Fix may enable compatibility options that can reduce security.

This may include insecure guest access or legacy SMB behavior.

Only use this mode on trusted local networks.

Avoid using Legacy / Full Fix on:

* Public Wi-Fi
* Office networks you do not manage
* School networks
* Shared building networks
* Internet-facing systems
* Unknown or untrusted networks

---

## What This Tool Changes

Depending on the selected mode, the script may modify or interact with:

### Services

* Print Spooler
* Server service
* Workstation service
* Function Discovery Provider Host
* Function Discovery Resource Publication

---

### Folders

* Print spooler queue folder
* Print spooler server cache folder
* Print spooler driver folder

---

### Firewall

* File and Printer Sharing rules
* Legacy firewall compatibility commands where needed

---

### Registry

The script may modify selected registry areas related to:

* Print service
* Printer providers
* Printer RPC compatibility
* Workstation compatibility
* LSA compatibility
* Legacy authentication behavior

Exact changes depend on the selected fix mode.

---

## What This Tool Does Not Do

This script does not:

* Install printer drivers
* Download printer drivers
* Replace damaged printer drivers
* Repair corrupted Windows system files
* Guarantee compatibility between 32-bit and 64-bit drivers
* Configure every possible firewall or antivirus product
* Fix broken network hardware
* Fix incorrect router settings
* Fix domain or Group Policy restrictions
* Permanently solve problems caused by future Windows updates
* Guarantee that every printer sharing issue will be fixed

Printer sharing problems can have multiple causes. This script handles common Windows-side repair steps, but it cannot fix every possible environment issue.

---

## Troubleshooting

## The Script Says It Finished, But The Printer Still Does Not Work

Check the log file first:

```text
printer_fix_log.txt
```

Look for warnings or failures.

Then check:

* Is the printer host turned on?
* Is the printer shared?
* Can the client access the host by name?
* Can the client access the host by IP address?
* Is the printer driver compatible?
* Is password-protected sharing enabled?
* Is the network profile set correctly?
* Is the firewall blocking printer sharing?
* Are both computers on the same network?
* Are both computers in the same Workgroup or domain?

---

## The Shared Printer Is Not Visible

Try opening the host directly from File Explorer:

```text
\\HOSTNAME
```

Or by IP address:

```text
\\192.168.1.10
```

If the host cannot be opened, the issue may be network discovery, firewall, name resolution, or credential-related.

---

## Access Is Denied

This can be caused by:

* Credential mismatch
* Guest access restrictions
* Password-protected sharing
* Local account restrictions
* Group Policy
* Missing permissions
* Legacy authentication settings

Try Quick Fix first.

If the printer is shared from an older Windows system, Legacy / Full Fix may be required.

---

## Error `0x0000011b`

This error is often related to printer RPC authentication changes.

Quick Fix may help by applying common printer RPC compatibility settings.

If the error remains, check whether the fix should be applied on the printer host, the client, or both.

---

## Error `0x00000709`

This error may be related to default printer settings, registry restrictions, shared printer name resolution, or driver issues.

Quick Fix may help in some cases, but driver and host configuration should also be checked.

---

## Print Spooler Fails To Start

If the Print Spooler fails to start after running the script, check:

* Corrupted printer drivers
* Stuck spool files
* Damaged Windows services
* Event Viewer logs
* Third-party print software
* Antivirus restrictions

You may need to remove problematic printer drivers manually from Print Management.

---

## Legacy Printer Sharing Still Fails

If the printer is shared from an old Windows version, NAS device, old print server, or unsupported SMB implementation, compatibility settings may be required.

Try Legacy / Full Fix only on trusted networks.

If it still fails, the device may require manual SMB, guest access, or driver configuration.

---

## Known Limitations

### Driver Compatibility

The script cannot fix incompatible drivers.

For example, a printer shared from a 32-bit Windows host may require additional drivers for a 64-bit Windows client.

---

### Modified Windows Installations

Lite, modified, or heavily customized Windows installations may be missing services or components required for printer sharing.

The script may not be able to repair missing Windows components.

---

### Domain or Group Policy

In domain environments, Group Policy may override local registry or firewall settings.

The script may appear to apply changes, but those changes can be reverted by policy.

---

### Third-Party Security Software

Antivirus, endpoint protection, or firewall software may block printer sharing even when Windows settings are correct.

The script does not configure third-party security products.

---

### Network Name Resolution

Printer sharing often depends on the ability to resolve the host computer name.

If name resolution is broken, try connecting by IP address.

Example:

```text
\\192.168.1.10\PrinterName
```

---

## FAQ

## Is this a guaranteed fix?

No.

This tool automates common troubleshooting steps, but printer sharing problems can be caused by drivers, updates, network configuration, firewall rules, authentication settings, or system corruption.

---

## Should I run Quick Fix or Legacy / Full Fix?

Run Quick Fix first.

Use Legacy / Full Fix only if Quick Fix does not solve the issue and you are working on a trusted local network.

---

## Should I run this on the printer host or the client?

It depends on the problem.

If the printer is shared from another PC, start with the printer host.

If the host appears fine but the client cannot connect, run it on the client as well.

---

## Does this work on Windows 7?

It is intended to support Windows 7 on a best-effort basis.

Some repairs may behave differently depending on installed updates, services, drivers, and system condition.

---

## Does this enable SMBv1?

Quick Fix should avoid the most risky legacy options.

Legacy / Full Fix may enable or configure legacy compatibility settings depending on the system.

Use Legacy / Full Fix only when required.

---

## Is it safe to use on a public network?

Quick Fix is safer than Legacy / Full Fix, but printer sharing itself should generally be used only on trusted networks.

Do not use Legacy / Full Fix on public or untrusted networks.

---

## Can I undo the changes?

The script includes a restore option that attempts to restore script-managed registry changes from the latest backup.

It is not a full system restore.

---

## Why does the script ask for restart?

Some Windows printer sharing changes require services to reload or Windows to restart before they fully apply.

Restarting after running the fix is recommended.

---

## Can this damage my printer installation?

The script is designed to avoid destructive actions where possible, but any system repair tool can have side effects.

A backup is created before registry changes.

If you are working on an important production system, review the script before running it.

---

## Can this fix printer problems over the internet?

No.

This tool is intended for local Windows printer sharing environments, such as home networks, small offices, or LAN setups.

It is not designed for internet printing or cloud printing services.

---

## Reporting Issues

When reporting an issue, please include:

* Windows version
* Windows build number
* Printer host Windows version
* Client Windows version
* Printer model
* Error code or message
* Which fix mode was used
* Whether the issue happens on host, client, or both
* Relevant lines from `printer_fix_log.txt`

Example:

```text
Windows version: Windows 10 22H2
Printer host: Windows 7
Client: Windows 10
Printer model: Canon LBPxxxx
Error: 0x0000011b
Mode used: Quick Fix
Result: Spooler restarted, but printer still cannot connect
```

---

## Contributing

Contributions are welcome.

You can help by:

* Reporting bugs
* Testing on different Windows versions
* Improving compatibility
* Improving restore behavior
* Improving documentation
* Submitting pull requests
* Sharing logs from failed repair cases

Before submitting a pull request, please keep the project style simple:

* Use plain batch scripting
* Avoid unnecessary dependencies
* Keep output readable
* Log important command results
* Avoid hiding errors
* Avoid unsafe changes unless clearly marked as legacy or risky

---

## Development Notes

This project intentionally uses a batch script instead of a compiled executable.

Reasons:

* Easy to inspect
* Easy to modify
* No installation required
* No external runtime required
* Works in many technician workflows
* Can be reviewed before execution

The script should remain readable and transparent.

Avoid adding unnecessary obfuscation, binary payloads, or remote download behavior.

---

## Suggested Testing Checklist

Before publishing a new release, test the script on:

* Windows 7
* Windows 10
* Windows 11
* A system with Print Spooler running
* A system with Print Spooler stopped
* A system without existing backup
* A system with existing backup
* Quick Fix mode
* Legacy / Full Fix mode
* Restore mode
* Non-admin execution
* Folder path containing spaces
* English Windows
* Non-English Windows

Recommended checks:

* Script stops correctly when not run as Administrator
* Backup folder is created
* Log file is created
* Menu options work correctly
* Quick Fix completes without menu flow errors
* Legacy mode requires confirmation
* Restore does not run without backup
* Restore imports available backup files
* Spooler status is detected correctly
* Final result reports warnings or failures honestly

---

## Project Goals

The main goals of this project are:

* Provide a repeatable printer sharing repair workflow
* Avoid applying risky legacy settings by default
* Keep the script readable
* Keep changes transparent
* Create backups before modifying registry values
* Log command results for troubleshooting
* Support older and newer Windows versions where possible

---

## Non-Goals

This project is not intended to be:

* A printer driver manager
* A full Windows repair tool
* A replacement for proper network configuration
* A replacement for vendor printer software
* A guaranteed fix for every printer error
* A domain or enterprise printer deployment solution
* A cloud printing solution

---

## Changelog

## v3.1.0

* Improved repair flow
* Improved backup handling
* Improved restore behavior
* Added better command result logging
* Improved service status handling
* Improved compatibility handling for older Windows versions
* Added clearer separation between Quick Fix and Legacy / Full Fix
* Added additional safety checks before applying changes

---

## License

This project is licensed under the MIT License.

See the `LICENSE` file for details.

---

## Disclaimer

Use this script at your own risk.

The script modifies Windows settings related to printer sharing, services, firewall rules, and registry values. It is designed to create backups and report errors, but it cannot account for every possible Windows installation, driver condition, network setup, or security policy.

Review the script before running it on important systems.
