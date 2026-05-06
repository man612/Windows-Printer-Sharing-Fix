# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 3.1.0](https://img.shields.io/badge/Version-3.1.0-blue?style=for-the-badge)

A professional, verified utility to fix common Windows printer sharing errors across versions 7, 8, 10, and 11. This script is the result of rigorous technical auditing, featuring state-aware restoration and final verification checks.

## 🚀 Key Features

- **Final Verification (v3.1+)**: The script doesn't just run commands; it verifies registry values and service states *after* the fix to ensure success.
- **Safe Execution Logic**: Rebuilt using "Locked" batch blocks to prevent logic leaks and ensure 100% reliable menu navigation.
- **Audited System**: A completely transparent architecture focusing on honest error reporting (Fail/Warn) and system integrity.
- **Interactive Menu**: Choose between a safe **Quick Fix** or a **Legacy/Full Fix** (for persistent issues).
- **State-Aware Restore**: Tracks the exact previous state of the registry for a mathematically clean "Undo".
- **Timestamped Backups**: Every execution creates a unique backup folder, protecting your system state.
- **SID-Based Permissions**: Uses Security Identifiers (SIDs) for folder permissions, ensuring compatibility across all Windows display languages.
- **Detailed Logging**: Every action is logged with precise timestamps and error codes for professional troubleshooting.
- **Comprehensive Fixes**:
  - RPC Authentication Privacy bypass.
  - Client-Side Rendering (CSR) cleanup.
  - Spooler cache purging.
  - SMBv1 & Guest Authentication enablement (Full Mode).
  - Firewall & Network Discovery automation.

## 🛠️ Errors Resolved

This utility is designed to fix the following error codes:
- `0x0000011b` (Common after KB5005565 update)
- `0x00000012`
- `0x00000709`
- `0x0000007a`
- `Access Denied` / `Operation could not be completed`

## 📖 How to Use

1. **Download**: Clone the repository or download `FixPrinter.bat`.
2. **Run as Administrator**: Right-click `FixPrinter.bat` and select **Run as administrator**.
3. **Choose Option**:
   - **[1] Quick Fix**: Fixes 90% of issues without enabling insecure protocols.
   - **[2] Full Fix**: Includes SMBv1 enablement for legacy printer servers.
4. **Restart**: A system restart is **highly recommended** after the script finishes.

## ⚠️ Safety & Restore

Your safety is our priority. The script automatically exports registry backups to the `backups/` folder.
- If you encounter issues after running the fix, simply run the script again and select **[3] Restore Settings**.

## 🔬 Technical Deep Dive

| Feature | Registry Key / Action | Why? |
|---------|-----------------------|------|
| RPC Privacy | `RpcAuthnLevelPrivacyEnabled` = 0 | Bypasses the strict RPC authentication that causes 0x0000011b. |
| Named Pipes | `RpcUseNamedPipeProtocol` = 1 | Forces RPC over named pipes for better compatibility with older sharing. |
| CSR Provider | `reg delete ...\Providers\Client Side ...` | Clears corrupted client-side printer rendering providers. |
| Blank Passwords| `limitblankpassworduse` = 0 | Allows sharing when accounts don't have passwords. |

## 🛡️ Security Note

The **Full Fix** option enables **SMBv1** and **Insecure Guest Auth**. These are older protocols with known security vulnerabilities. Only use this mode if you are on a trusted local network and the Quick Fix fails.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.
