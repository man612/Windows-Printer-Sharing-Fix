# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 3.1.0](https://img.shields.io/badge/Version-3.1.0-blue?style=for-the-badge)

A professional, audited utility designed to resolve common network printing and sharing errors (e.g., **0x0000011b**, **0x00000709**) across Windows 7, 8, 8.1, 10, and 11. This tool focuses on technical transparency, state-aware restoration, and cross-language compatibility.

## 🚀 Key Features

### 1. Audited & Verified Framework (v3.0+)
- **Safe Execution Logic**: The script utilizes encapsulated logic blocks `( )` to ensure reliable command parsing and prevent execution leaks, a common issue in complex batch files.
- **Post-Fix Verification**: Automatically validates registry modifications and service states after application to ensure settings are correctly applied.
- **Honest Error Reporting**: Distinguishes between critical `FAIL` and non-critical `WARN` statuses, logged with specific exit codes for professional troubleshooting.

### 2. International & Security Compliance
- **SID-Based Permissions**: Uses Security Identifiers (SIDs) like `*S-1-1-0` (Everyone) and `*S-1-5-18` (SYSTEM) for folder permissions. This ensures 100% compatibility across all Windows display languages (Indonesian, English, etc.).
- **Conservative Access Control**: Restricts sensitive spooler folders to SYSTEM and Administrators by default, avoiding the security risks of granting blanket "Full Control" to all users.
- **Firewall Resource IDs**: Leverages Resource IDs (`@FirewallAPI.dll,-28502`) for firewall rule automation to ensure reliability across localized OS builds.

### 3. State-Aware Backup & Restore
- **Non-Overwriting Backups**: Every run generates a unique, timestamped backup folder. Original system states are preserved across multiple executions.
- **State Serialization**: Saves the initial presence or absence of registry keys to `reg_state.cmd`. During restoration, the script can accurately delete keys that were originally absent, rather than just resetting them to zero.
- **Persistent Localization**: Saves language preferences (ID/EN) to a persistent `language.cfg` file.

### 4. Technical Fix Scope
- **RPC Hardening**: Configures `RpcAuthnLevelPrivacyEnabled`, `RpcUseNamedPipeProtocol`, and `RpcProtocols` to resolve modern authentication errors.
- **Provider Cleanup**: Removes corrupted Client-Side Rendering (CSR) providers.
- **Service Optimization**: Automates the configuration and reset of the Print Spooler, LanmanServer (Server), and LanmanWorkstation (Workstation) services.
- **Network Discovery**: Automates the `fdPHost` and `FDResPub` services to ensure printers are visible on the network.

---

## 📖 How to Use

1. **Download**: Obtain the latest `FixPrinter.bat`.
2. **Run as Administrator**: Right-click the file and select **Run as administrator**.
3. **Execution**:
   - **[1] Quick Fix**: Recommended for most scenarios. Fixes RPC and permission issues without lowering security.
   - **[2] Legacy/Full Fix**: Includes SMBv1 and Guest Authentication for environments with very old print servers (use with caution).
4. **Restart**: A system restart is required to fully apply the registry and service changes.

## 🔬 Technical Deep Dive

| Feature | Registry Key / Action | Technical Purpose |
|---------|-----------------------|-------------------|
| RPC Privacy | `RpcAuthnLevelPrivacyEnabled` = 0 | Bypasses strict RPC privacy requirements that trigger 0x0000011b. |
| Named Pipes | `RpcUseNamedPipeProtocol` = 1 | Forces RPC communication over named pipes for legacy compatibility. |
| Guest Auth | `AllowInsecureGuestAuth` = 1 | (Legacy Mode) Allows access to shares that do not require credentials. |
| Blank Passwords | `limitblankpassworduse` = 0 | (Legacy Mode) Allows network access for accounts without passwords. |

## 🛡️ Security & Risks

The **Quick Fix** mode is designed to be safe for most environments. However, the **Legacy/Full Fix** enables **SMBv1** and **Insecure Guest Auth**, which are deprecated protocols. These should only be used on trusted local networks where connectivity with legacy hardware is mission-critical.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 🤝 Contributing

Contributions are welcome! If you find a bug or have a suggestion for improving the audited logic, please open an issue or submit a pull request.
