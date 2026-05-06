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

This script provides a menu-based troubleshooting utility that applies several known repair steps in a controlled way. The script attempts to:
- Check for administrator privileges
- Detect the Windows version
- Create a backup before applying changes
- Apply selected printer sharing fixes
- Restart required services
- Log command results

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

- **Menu-Based Interface**: Simple command-line menu for easy navigation.
- **Administrator Check**: Ensures script runs with necessary privileges.
- **Print Spooler Reset**: Stops/Starts service and clears queue files.
- **RPC Compatibility**: Applies registry values for modern Windows RPC sharing.
- **Network Discovery**: Configures `fdPHost` and `FDResPub` services.
- **Timestamped Backups**: Each run creates a unique backup folder.
- **State-Aware Restore**: Reverts registry changes based on original state.
- **Logging**: Detailed logs saved to `printer_fix_log.txt`.

---

## ⚙️ How It Works

The script combines several troubleshooting steps into a single workflow:
1. Admin & OS detection.
2. Mandatory backup creation.
3. Service reset & queue cleanup.
4. Registry & permission application.
5. Firewall rule activation.
6. Service restart & result verification.

---

## 🚀 Fix Modes

### 🟢 Quick Fix
Recommended first option. Applies safer repair steps without enabling legacy compatibility settings. Includes spooler reset, RPC fixes, and firewall activation.

### 🔴 Legacy / Full Fix
Intended for older systems or persistent problems. May enable SMBv1 and insecure guest authentication. Use only on trusted local networks.

---

## 📥 Download

Download the latest version: **[FixPrinter.bat](FixPrinter.bat)**

```bash
git clone https://github.com/man612/Windows-Printer-Sharing-Fix.git
```

---

## 📖 Usage

1. Right-click `FixPrinter.bat` and select **Run as administrator**.
2. Choose **Quick Fix** from the menu.
3. Restart Windows after the repair finishes and test the printer.

---

## 📋 Recommended Workflow

For best results, identify the **Printer Host** (the PC sharing the printer). Run the script on the host first, then on the client if connection issues persist. Check the log file if failures occur.

---

## 💾 Backup and Restore

Registry changes are backed up to the `backups\` folder. The **Restore** function can revert managed keys or delete keys that were not present before the fix was applied.

---

## 📝 Logs

All actions are logged to `printer_fix_log.txt`, including warnings and failures. This file is essential for troubleshooting if the script does not fully resolve the problem.

---

## 🛡️ Security Notes

The script separates safe fixes from legacy fixes. **Legacy / Full Fix** may reduce security by enabling older protocols like SMBv1. Only use legacy mode on trusted networks.

---

## 🔬 What This Tool Changes

<details>
<summary><b>🛠️ System Modifications (Click to expand)</b></summary>

- **Services**: Print Spooler, Server, Workstation, fdPHost, FDResPub.
- **Folders**: Spooler queue (`PRINTERS`), server cache (`SERVERS`), and drivers.
- **Firewall**: File and Printer Sharing rules.
- **Registry**: Print service, providers, RPC, LSA, and SMB compatibility.
</details>

---

## 🚫 What This Tool Does Not Do

- Install or download printer drivers.
- Repair corrupted Windows system files.
- Fix hardware or router issues.
- Fix domain/Group Policy restrictions.

---

## 🐞 Troubleshooting

<details>
<summary><b>🔧 Detailed Error Guide (Click to expand)</b></summary>

- **0x0000011b**: Often fixed by RPC compatibility settings in Quick Fix.
- **Access is Denied**: Check credentials, network profile, and guest access.
- **Spooler Fails to Start**: Check for corrupted drivers in Print Management.
</details>

---

## 📋 Known Limitations

- **Driver Compatibility**: The script cannot fix incompatible 32/64-bit drivers.
- **Modified Windows**: "Lite" or custom ISOs may be missing required services.
- **Group Policy**: Domain settings may override local registry changes.

---

## ❓ FAQ

<details>
<summary><b>🤔 Common Questions (Click to expand)</b></summary>

- **Is this a guaranteed fix?** No, results depend on many external factors.
- **Host or Client?** Start with the computer sharing the printer (Host).
- **Is it safe?** Quick Fix is designed for standard safety; Legacy Fix is for older setups.
</details>

---

## 📄 License

Distributed under the MIT License. See the `LICENSE` file for details.

---

## 🤝 Contributing

Contributions are welcome! Please report bugs or submit pull requests while maintaining the simple batch script style.
