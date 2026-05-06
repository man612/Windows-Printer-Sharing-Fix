# Windows Printer Sharing Fix

![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version: 3.1.0](https://img.shields.io/badge/Version-3.1.0-blue?style=for-the-badge)

A utility to resolve network printing and sharing errors (e.g., **0x0000011b**, **0x00000709**, **0x00000012**) on Windows 7, 8, 8.1, 10, and 11. This tool focuses on technical verification, state-aware registry management, and cross-language compatibility.

## 🛠️ Technical Implementation

### 1. Verification Framework (v3.1+)
- **Encapsulated Logic**: The script execution flow is rebuilt using logic blocks `( )`. This ensures command parsing integrity and prevents premature execution of `GOTO` or `SET` statements.
- **Service State Codes**: Status detection utilizes numeric state codes from `sc query` instead of localized strings (e.g., "RUNNING"). This ensures reliable monitoring on non-English system locales.
- **Post-Fix Validation**: Includes a verification routine that queries target registry keys and service states after fixes are applied. Results are compared against expected values and logged.

### 2. Permissions & Internationalization
- **Security Identifier (SID) Support**: Permissions for `%SystemRoot%\System32\spool\PRINTERS` and `drivers` are applied using Well-Known SIDs (`*S-1-1-0`, `*S-1-5-18`, `*S-1-5-32-544`). This bypasses the need for localized group names like "Everyone" or "Administrators".
- **Access Control**: Implements restricted access for spooler directories, focusing on SYSTEM and Administrators to maintain security integrity.
- **Firewall Resource IDs**: Firewall rules are enabled via Resource IDs (`@FirewallAPI.dll,-28502`) for reliability across different Windows language builds.

### 3. Registry & Protocol Fixes
- **RPC Hardening**: Configures `RpcAuthnLevelPrivacyEnabled`, `RpcUseNamedPipeProtocol`, and `RpcProtocols` to handle modern Windows RPC connection updates.
- **CSR Provider Management**: Automates the removal of corrupted Client Side Rendering (CSR) print provider keys.
- **Service Configuration**: Sets startup types and resets the Print Spooler, LanmanServer (Server), and LanmanWorkstation (Workstation) services.
- **Network Discovery**: Configures and starts `fdPHost` (Function Discovery Provider Host) and `FDResPub` (Function Discovery Resource Publication) for network visibility.

### 4. Backup & State Restoration
- **Timestamped Archiving**: Generates unique, non-overwriting backup directories (`YYYYMMDD_HHMMSS`) in the `backups/` folder for every execution.
- **State Serialization**: Records the initial state of registry values to `reg_state.cmd`.
- **Clean Restoration**: The restore function uses serialized state data to accurately revert keys. If a key was originally absent, it is deleted during restore rather than just reset to zero.

---

## 📖 Usage Instructions

1. **Download**: Obtain the latest version of `FixPrinter.bat`.
2. **Administrator Rights**: Right-click the file and select **Run as Administrator**.
3. **Menu Selection**:
   - **[1] Quick Fix**: Standard fix for RPC, permissions, and spooler errors.
   - **[2] Legacy/Full Fix**: Includes SMBv1 feature enablement (DISM) and insecure guest authentication for legacy print server compatibility.
4. **Restart**: A system restart is required for all registry and service changes to take effect.

## 🔬 Technical Reference

| Feature | Registry Path / Action | Technical Purpose |
|---------|------------------------|-------------------|
| RPC Privacy | `HKLM\System\...\Print` | Disables RPC authentication privacy to resolve 0x0000011b. |
| Named Pipes | `HKLM\...\Printers\RPC` | Forces RPC communication over named pipes. |
| Guest Auth | `HKLM\...\LanmanWorkstation` | (Legacy) Allows access to shares without credentials. |
| Blank Passwords | `HKLM\...\Control\Lsa` | (Legacy) Allows network access for accounts without passwords. |

## 🛡️ Safety & Risks

- **Quick Fix**: Standardized for most environments; focuses on RPC and spooler fixes.
- **Legacy/Full Fix**: Enables **SMBv1** and **Insecure Guest Auth**. These protocols are deprecated and should only be used in trusted networks where legacy hardware support is required.

---

## 📄 License

Distributed under the MIT License.
