# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 3.1.0](https://img.shields.io/badge/Version-3.1.0-blue?style=for-the-badge)

A Windows batch utility for troubleshooting common printer sharing issues on local networks.

🚀 This project is designed to help reset and repair several Windows printer sharing components that are commonly involved in shared printer connection errors, spooler problems, RPC-related failures, and legacy network printing issues.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Supported Windows Versions](#-supported-windows-versions)
- [Common Issues](#️-common-issues)
- [Features](#-features)
- [How It Works](#️-how-it-works)
- [Fix Modes](#-fix-modes)
- [Download](#-download)
- [Usage](#-usage)
- [Recommended Workflow](#-recommended-workflow)
- [Backup and Restore](#-backup-and-restore)
- [Logs](#-logs)
- [Security Notes](#-security-notes)
- [What This Tool Changes](#-what-this-tool-changes)
- [What This Tool Does Not Do](#-what-this-tool-does-not-do)
- [Troubleshooting](#-troubleshooting)
- [Known Limitations](#-known-limitations)
- [FAQ](#-faq)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🔍 Overview

Windows printer sharing can fail for many different reasons. Some issues are caused by Windows updates, printer driver compatibility, RPC changes, Print Spooler failures, firewall rules, network discovery settings, SMB compatibility, or incorrect host/client configuration.

This script provides a menu-based troubleshooting utility that applies several known repair steps in a controlled way.

---

## 💻 Supported Windows Versions

This project is intended to support the following Windows versions:
- Windows 7
- Windows 8 / 8.1
- Windows 10
- Windows 11

### 📄 Notes About Windows 7
Windows 7 support is best-effort. Some commands and services differ between Windows 7 and newer versions. The script avoids using certain modern commands on older systems when possible.

---

## 🛠️ Common Issues

This tool may help with problems such as:
- Shared printer cannot be accessed or connected.
- Printer sharing stopped working after a Windows update.
- Print Spooler service fails or becomes stuck.
- Shared printer does not appear on the network.
- RPC-related errors (`0x0000011b`, `0x00000709`, etc.).

---

## ✨ Features

- **Auto-Elevation (UAC)**: Automatically requests Administrator privileges via PowerShell if not already elevated.
- **Point and Print Fix**: Automates bypasses for `RestrictDriverInstallationToAdministrators` to allow driver installation from print servers.
- **Menu-Based Interface**: Simple command-line menu for easy navigation.
- **Print Spooler Reset**: Stops/Starts service and clears queue files.
- **RPC Compatibility**: Applies registry values for modern Windows RPC sharing.
- **Network Discovery**: Configures `fdPHost` and `FDResPub` services.
- **Timestamped Backups**: Each run creates a unique backup folder.
- **State-Aware Restore**: Reverts registry changes based on original state.
- **Logging**: Detailed logs saved to `printer_fix_log.txt`.

---

## ⚙️ How It Works

The script combines several troubleshooting steps into a single workflow:
1. **UAC Elevation**: Requests admin access if needed.
2. **OS Detection**: Identifies Windows version and build.
3. **Mandatory Backup**: Saves registry state before any modification.
4. **Service Reset**: Clears spooler cache and resets services.
5. **Fix Application**: Applies Point and Print, RPC, and permission fixes.
6. **Firewall Rules**: Activates sharing rules across localized OS builds.
7. **Verification**: Confirms results and writes to log.

---

## 🚀 Fix Modes

### 🟢 Quick Fix
**Recommended first option.** Applies safer repair steps including:
- Print Spooler & Queue Reset
- **Point and Print Compatibility**
- RPC Privacy & Named Pipe fixes
- Firewall & Network Discovery configuration

### 🔴 Classic / Full Fix
Intended for persistent problems or older systems. Includes everything in Quick Fix plus:
- SMBv1 feature enablement (DISM)
- Insecure guest authentication
- LAN Manager & Blank password compatibility

---

## 📥 Download

Download the latest version: **[FixPrinter.bat](FixPrinter.bat)**

```bash
git clone https://github.com/man612/Windows-Printer-Sharing-Fix.git
```

---

## 📖 Usage

1. Run `FixPrinter.bat` (It will automatically request Admin access).
2. Choose **Quick Fix** (Option 1) from the menu.
3. Restart Windows after the repair finishes and test the printer.

---

## 📋 Recommended Workflow

For best results, identify the **Printer Host** (the PC sharing the printer). Run the script on the host first, then on the client if connection issues persist.

---

## 💾 Backup and Restore

Registry changes are backed up to the `backups\` folder. The **Restore** function can revert managed keys or delete keys that were not present before the fix was applied.

---

## 📝 Logs

All actions are logged to `printer_fix_log.txt`, including warnings and failures. This file is essential for troubleshooting if the script does not fully resolve the problem.

---

## 🛡️ Security Notes

The script separates safe fixes from classic fixes. **Classic / Full Fix** may reduce security by enabling older protocols like SMBv1. Only use classic mode on trusted networks.

---

## 🔬 What This Tool Changes

<details>
<summary><b>🛠️ System Modifications (Click to expand)</b></summary>

- **Services**: Print Spooler, Server, Workstation, fdPHost, FDResPub.
- **Point and Print**: `RestrictDriverInstallationToAdministrators`, `BypassUpdateRoleIndicator`.
- **Folders**: Spooler queue (`PRINTERS`), server cache (`SERVERS`), and drivers.
- **Firewall**: File and Printer Sharing rules.
- **Registry**: Print service, providers, RPC, LSA, and SMB compatibility.
</details>

---

## 🛡️ Technical Reference

| Feature | Registry Path / Action | Technical Purpose |
|---------|------------------------|-------------------|
| RPC Privacy | `HKLM\System\...\Print` | Resolves 0x0000011b authentication errors. |
| Point and Print | `HKLM\...\PointAndPrint` | Allows non-admins to install server-provided drivers. |
| Named Pipes | `HKLM\...\Printers\RPC` | Forces RPC communication over named pipes. |
| Guest Auth | `HKLM\...\LanmanWorkstation` | (Classic) Allows access without credentials. |

---

## ❓ FAQ

<details>
<summary><b>🤔 Common Questions (Click to expand)</b></summary>

- **Is it safe?** Quick Fix is designed for standard safety; Classic Fix is for older setups.
- **Does it work on Windows 7?** Yes, on a best-effort basis for command compatibility.
- **Can I undo the changes?** Yes, via the **Restore** option in the menu.
</details>

---

## 📄 License

Distributed under the MIT License. See the `LICENSE` file for details.
