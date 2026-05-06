# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 3.1.0](https://img.shields.io/badge/Version-3.1.0-blue?style=for-the-badge)

A utility to resolve network printing and sharing errors (e.g., **0x0000011b**, **0x00000709**) on Windows 7, 8, 8.1, 10, and 11. This tool automates registry changes with state-aware restoration and cross-language compatibility.

## 🚀 Features

### 1. Verification Framework (v3.0+)
- **Logic Blocks**: Command flow uses encapsulated logic blocks `( )` for reliable parsing and to prevent execution leaks.
- **Post-Fix Validation**: Re-queries registry modifications and service states after execution to confirm changes were applied.
- **Error Reporting**: Distinguishes between `FAIL` and `WARN` statuses, logged with specific exit codes.

### 2. Compatibility & Security
- **SID-Based Permissions**: Uses Security Identifiers (SIDs) like `*S-1-1-0` (Everyone) and `*S-1-5-18` (SYSTEM) for folder permissions, supporting all Windows display languages.
- **Access Control**: Restricts spooler folders to SYSTEM and Administrators by default.
- **Firewall Resource IDs**: Uses Resource IDs (`@FirewallAPI.dll,-28502`) for firewall rule automation across localized OS builds.

### 3. Backup & Restore
- **Timestamped Backups**: Generates a unique backup folder for every run.
- **State Serialization**: Records the initial state of registry keys to `reg_state.cmd`. Restoration can delete keys that were originally absent.
- **Settings Persistence**: Saves language preferences (ID/EN) to `language.cfg`.

### 4. Technical Scope
- **RPC Configuration**: Handles `RpcAuthnLevelPrivacyEnabled`, `RpcUseNamedPipeProtocol`, and `RpcProtocols`.
- **Provider Cleanup**: Removes Client-Side Rendering (CSR) providers.
- **Service Management**: Configures Print Spooler, LanmanServer, and LanmanWorkstation services.
- **Network Discovery**: Automates `fdPHost` and `FDResPub` services.

---

## 📖 How to Use

1. **Download**: Get the latest `FixPrinter.bat`.
2. **Run as Administrator**: Right-click and select **Run as administrator**.
3. **Execution**:
   - **[1] Quick Fix**: Standard fix for RPC and permission issues.
   - **[2] Legacy/Full Fix**: Includes SMBv1 and Guest Authentication (use for old print servers).
4. **Restart**: A system restart is required to apply registry and service changes.

## 🔬 Technical Details

| Feature | Registry Key / Action | Purpose |
|---------|-----------------------|---------|
| RPC Privacy | `RpcAuthnLevelPrivacyEnabled` = 0 | Bypasses RPC privacy requirements for 0x0000011b. |
| Named Pipes | `RpcUseNamedPipeProtocol` = 1 | Forces RPC communication over named pipes. |
| Guest Auth | `AllowInsecureGuestAuth` = 1 | (Legacy) Allows access to shares without credentials. |
| Blank Passwords | `limitblankpassworduse` = 0 | (Legacy) Allows access for accounts without passwords. |

## 🛡️ Security Note

**Quick Fix** is standard for most environments. **Legacy/Full Fix** enables **SMBv1** and **Insecure Guest Auth**, which are deprecated. Only use on trusted local networks requiring legacy hardware connectivity.

---

## 📄 License

Distributed under the MIT License.
