# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 3.1.0](https://img.shields.io/badge/Version-3.1.0-blue?style=for-the-badge)

A Windows batch utility for troubleshooting common printer sharing issues on local networks.

🚀 This project is designed to help reset and repair several Windows printer sharing components that are commonly involved in shared printer connection errors, spooler problems, RPC-related failures, and legacy network printing issues.

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

<a name="overview"></a>
## 🔍 Overview

Windows printer sharing can fail for many different reasons. Some issues are caused by Windows updates, printer driver compatibility, RPC changes, Print Spooler failures, firewall rules, network discovery settings, SMB compatibility, or incorrect host/client configuration.

This script provides a menu-based troubleshooting utility that applies several known repair steps in a controlled way.

---

<a name="supported-windows-versions"></a>
## 💻 Supported Windows Versions

This project is intended to support the following Windows versions:

- Windows 7
- Windows 8 / 8.1
- Windows 10
- Windows 11

### 📄 Notes About Windows 7

Windows 7 support is best-effort. Some commands and services differ between Windows 7 and newer versions. The script avoids using certain modern commands on older systems when possible.

---

<a name="common-issues"></a>
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

<a name="how-it-works"></a>
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

<a name="fix-modes"></a>
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

<a name="download"></a>
## 📥 Download

Download the latest version: **[FixPrinter.bat](FixPrinter.bat)**

```bash
git clone https://github.com/man612/Windows-Printer-Sharing-Fix.git
```

---

<a name="usage"></a>
## 📖 Usage

1. Run `FixPrinter.bat` (It will automatically request Admin access).
2. Choose **Quick Fix** (Option 1) from the menu.
3. Restart Windows after the repair finishes and test the printer.

---

<a name="recommended-workflow"></a>
## 📋 Recommended Workflow

For best results, identify the **Printer Host** (the PC sharing the printer). Run the script on the host first, then on the client if connection issues persist.

---

<a name="backup-and-restore"></a>
## 💾 Backup and Restore

Registry changes are backed up to the `backups\` folder. The **Restore** function can revert managed keys or delete keys that were not present before the fix was applied.

---

<a name="logs"></a>
## 📝 Logs

All actions are logged to `printer_fix_log.txt`, including warnings and failures. This file is essential for troubleshooting if the script does not fully resolve the problem.

---

<a name="security-notes"></a>
## 🛡️ Security Notes

The script separates safe fixes from classic fixes. **Classic / Full Fix** may reduce security by enabling older protocols like SMBv1. Only use classic mode on trusted networks.

---

<a name="what-this-tool-changes"></a>
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

<a name="what-this-tool-does-not-do"></a>
## 🚫 What This Tool Does Not Do

- Install or download printer drivers.
- Repair corrupted Windows system files.
- Fix hardware or router issues.
- Fix domain/Group Policy restrictions.

---

<a name="troubleshooting"></a>
## 🐞 Troubleshooting

<details>
<summary><b>🔧 Detailed Error Guide (Click to expand)</b></summary>

- **0x0000011b**: Often fixed by RPC compatibility settings in Quick Fix.
- **Access is Denied**: Check credentials, network profile, and guest access.
- **Spooler Fails to Start**: Check for corrupted drivers in Print Management.

### Browser Shows "Failed - Virus scan failed"

This issue is usually not caused by this script. If the browser fails to download any file, the problem is likely related to the Windows Attachment Manager or Microsoft Defender integration.

Before changing registry values, try:

1. Update Microsoft Defender security intelligence.
2. Restart Windows.
3. Check Windows Security protection history.
4. Try another browser.

If downloads still fail, the following commands may help reset the attachment scanning policy:

```bat
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v ScanWithAntiVirus /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v ScanWithAntiVirus /t REG_DWORD /d 1 /f
gpupdate /force
```

*Restart Windows after running the commands. Note: This does not mean the downloaded file is automatically safe. Keep real-time protection enabled and only download files from trusted sources.*
</details>

---

<a name="known-limitations"></a>
## 📋 Known Limitations

- **Driver Compatibility**: The script cannot fix incompatible 32/64-bit drivers.
- **Modified Windows**: "Lite" or custom ISOs may be missing required services.
- **Group Policy**: Domain settings may override local registry changes.

---

<a name="faq"></a>
## ❓ FAQ

<details>
<summary><b>🤔 Common Questions (Click to expand)</b></summary>

- **Is this a guaranteed fix?** No, results depend on many external factors.
- **Host or Client?** Start with the computer sharing the printer (Host).
- **Is it safe?** Quick Fix is designed for standard safety; Classic Fix is for older setups.
- **Can I undo the changes?** Yes, via the **Restore** option in the menu.
</details>

---

<a name="contributing"></a>
## 🤝 Contributing

Contributions are welcome! Please report bugs or submit pull requests while maintaining the simple batch script style.

---

<a name="license"></a>
## 📄 License

Distributed under the MIT License. See the `LICENSE` file for details.
