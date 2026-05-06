# Windows Printer Sharing Fix (Pro)

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-blue?style=for-the-badge)

A professional, enterprise-grade utility to fix common Windows 10/11 printer sharing errors. This script automates the complex registry and protocol changes required to resolve the infamous **0x0000011b** error and other network printing issues.

## 🚀 Key Features

- **Interactive Menu**: Choose between a Quick Fix or a Full Fix.
- **Safety First**: Automatic registry backups before any modification.
- **Detailed Logging**: Every action is logged to `printer_fix_log.txt`.
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
