# Windows Printer Sharing Fix

A Windows batch utility for troubleshooting common printer sharing issues on local networks.

🚀 This project is designed to help reset and repair several Windows printer sharing components that are commonly involved in shared printer connection errors, spooler problems, RPC-related failures, and legacy network printing issues.

It is intended for home users, technicians, small offices, and local network environments where printers are shared from one Windows computer to another.

The script focuses on repeatable troubleshooting steps, safer execution flow, logging, and registry backup before changes are applied.

---

## 📋 Table of Contents

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

## 🔍 Overview

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

---

## 💻 Supported Windows Versions

This project is intended to support the following Windows versions:

- Windows 7
- Windows 8
- Windows 8.1
- Windows 10
- Windows 11

<details>
<summary><b>📄 Notes About Windows 7 (Click to expand)</b></summary>

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
</details>

---

## 🛠️ Common Issues

<details>
<summary><b>🐞 Types of errors this tool can handle (Click to expand)</b></summary>

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
</details>

---

## ✨ Features

### 🖥️ Menu-Based Interface
The script provides a simple command-line menu so users can choose the repair mode they want to run.
Main options include: Quick Fix, Legacy / Full Fix, Restore, Quick Access tools, and more.

### 🛡️ Administrator Check
Printer sharing repairs often require elevated privileges. The script checks whether it is running as Administrator before applying system changes.

### 🔍 Windows Version Detection
The script attempts to detect the current Windows version and build number to avoid running incompatible commands on older systems.

### 🔄 Print Spooler Reset
The Print Spooler is one of the most common causes of printer-related problems. The script can stop, start, and verify the service status.

### 🧹 Printer Queue Cleanup
Stuck files inside the spooler queue can prevent printing. The script clears common spool locations like `%SystemRoot%\System32\spool\PRINTERS`.

### ⚙️ RPC & Registry Fixes
Includes compatibility settings for RPC, Printer Providers, and sharing-related registry keys that are commonly involved in connection failures.

### 📁 Timestamped Backups & Restore
Before applying registry changes, the script creates a unique `backups\YYYYMMDD_HHMMSS` folder. The **State-Aware Restore** function can even remove keys that didn't exist before the fix.

---

## ⚙️ How It Works

<details>
<summary><b>📖 Step-by-step logic (Click to expand)</b></summary>

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

The script does not silently assume that every command succeeded. Where possible, it checks command results and reports warnings or failures.
</details>

---

## 🚀 Fix Modes

### 🟢 Quick Fix
**Recommended first option.** Applies common printer sharing repair steps without enabling risky legacy compatibility settings. Includes: Spooler reset, queue cleanup, RPC compatibility, permission repair, and firewall activation.

### 🔴 Legacy / Full Fix
**Intended for older systems or persistent problems.** Applies additional compatibility settings such as SMBv1 feature enablement, insecure guest authentication, and LAN Manager compatibility. **Use carefully only on trusted networks.**

---

## 📥 Download

Download the latest version from the repository: **[FixPrinter.bat](FixPrinter.bat)**

```bash
git clone https://github.com/man612/Windows-Printer-Sharing-Fix.git
```

---

## 📖 Usage

1. Right-click `FixPrinter.bat`.
2. Select **Run as administrator**.
3. Choose a menu option (Start with Quick Fix).
4. Restart Windows after the repair finishes.

---

## 📋 Recommended Workflow

<details>
<summary><b>✅ Best practices for troubleshooting (Click to expand)</b></summary>

**Step 1: Confirm the Printer Host**
Identify the computer sharing the printer (the Host). Run the script on the Host first, then the Client if needed.

**Step 2: Run Quick Fix First**
Start with Quick Fix. Restart Windows and test.

**Step 3: Check the Log**
If not fixed, check `printer_fix_log.txt` for `[WARN]`, `[FAIL]`, or `[FATAL]` entries.

**Step 4: Legacy Fix (Optional)**
If Quick Fix fails and the network is trusted, try Legacy / Full Fix.

**Step 5: External Checks**
Verify drivers, architecture (32/64-bit), shared names, network profiles, and firewall/antivirus settings.
</details>

---

## 💾 Backup and Restore

<details>
<summary><b>🔄 Safety and Undo details (Click to expand)</b></summary>

Before making registry changes, the script creates a unique folder under `backups\`.
The restore function attempts to restore the latest backup, including DWORD values and exported keys.

**Restore Behavior:**
It can restore existing values or delete values that were absent before the fix. It is **not** a full Windows System Restore and cannot undo changes made by Windows Update or third-party tools.
</details>

---

## 📝 Logs

All repair actions are logged to `printer_fix_log.txt`. 
Example log entries:
- `[OK] Started Spooler`
- `[WARN] Firewall rule failed`
- `[FAIL] Required registry setting could not be applied`

---

## 🛡️ Security Notes

<details>
<summary><b>⚠️ Risk Assessment (Click to expand)</b></summary>

**Quick Fix Security Profile:**
Avoids risky legacy settings. Recommended for most users.

**Legacy / Full Fix Security Profile:**
May enable insecure guest access or legacy SMB behavior. Avoid using this mode on public Wi-Fi, school networks, or untrusted environments.
</details>

---

## 🔬 What This Tool Changes

<details>
<summary><b>🛠️ System modifications list (Click to expand)</b></summary>

- **Services**: Print Spooler, Server, Workstation, fdPHost, FDResPub.
- **Folders**: Spooler queue, server cache, and driver folders.
- **Firewall**: File and Printer Sharing rules.
- **Registry**: Print service, providers, RPC compatibility, LSA compatibility, and authentication behavior.
</details>

---

## 🚫 What This Tool Does Not Do

<details>
<summary><b>❌ Out of scope items (Click to expand)</b></summary>

- Install or download printer drivers.
- Replace damaged printer drivers.
- Repair corrupted Windows system files.
- Fix broken network hardware or router settings.
- Fix domain or Group Policy restrictions.
- Guarantee that every printer sharing issue will be fixed.
</details>

---

## ❓ FAQ

<details>
<summary><b>🤔 Common Questions (Click to expand)</b></summary>

**Is this a guaranteed fix?**
No. It automates common steps, but results depend on drivers, updates, and network condition.

**Should I run this on the host or the client?**
Start with the host. If the client still cannot connect, run it on the client as well.

**Does this enable SMBv1?**
Only in Legacy / Full Fix mode. Quick Fix avoids it.

**Can I undo the changes?**
Yes, via the **Restore** option in the menu, which uses the latest backup.
</details>

---

## 🐞 Troubleshooting

<details>
<summary><b>🔧 Detailed error guide (Click to expand)</b></summary>

**The Printer Still Does Not Work**
Check `printer_fix_log.txt`. Verify if the host is shared and reachable via `\\HOSTNAME` or IP.

**Error 0x0000011b**
Often related to RPC authentication. Quick Fix applies common workarounds. Check both host and client.

**Print Spooler Fails To Start**
Could be corrupted drivers or stuck files. You may need to remove drivers manually via Print Management.
</details>

---

## 📄 License

Distributed under the MIT License. See the `LICENSE` file for details.

---

## 🤝 Contributing

Contributions are welcome! Please report bugs, test on different Windows versions, and submit pull requests while keeping the script readable and transparent.

---

## ⚠️ Disclaimer

Use this script at your own risk. It modifies system settings and registry values. Review the script before running it on production systems.
