# Security Policy

## Supported versions

| Version | Status |
| --- | --- |
| 4.x | Supported |
| 3.x | Security fixes only while v4 is being stabilized |
| 2.x and older | Unsupported |

## v4 security model

Windows Printer Sharing Fix v4 follows a diagnosis-first and least-change model.

### Safe Repair must not reduce Windows printer/network security

The Safe Repair path is not allowed to:

- Set `RpcAuthnLevelPrivacyEnabled=0`.
- Set `RestrictDriverInstallationToAdministrators=0`.
- Enable SMB1.
- Enable insecure SMB guest authentication.
- Lower `LmCompatibilityLevel`.
- Disable `LimitBlankPasswordUse`.
- Delete the entire Client Side Rendering Print Provider registry tree.

The repository CI checks these invariants.

### Compatibility changes must be explicit

Security-reducing compatibility options are separated into Advanced or Legacy menus and require an explicit typed confirmation where appropriate.

Point and Print driver-installation relaxation is temporary: the previous value is captured, the printer connection is attempted, and the original value is restored in a `finally` block.

### Blank-password remote logon is not automated

The utility intentionally refuses to set `LimitBlankPasswordUse=0`. Use password-protected credentials instead.

### Windows Protected Print Mode

The utility may detect Windows Protected Print Mode and direct the user to supported Windows settings. It must not silently bypass a Group Policy-enforced WPP configuration.

### Restore

Managed repair actions create a state snapshot before modification. Restore is designed to revert the specific managed states rather than importing an old copy of the entire Windows Print registry tree.

Irreversible operations, such as deleting pending print jobs, must display a warning before execution.

## Reporting a vulnerability

Please do not publish an exploitable security issue before the maintainer has had a reasonable chance to investigate it.

Use a private GitHub security advisory when available, or contact the maintainer through the GitHub profile.

Useful reports should include:

- Windows version and build.
- Whether the machine is a printer host, client, or both.
- Exact v4 version/commit.
- Relevant log output with credentials or sensitive host information removed.
- The smallest reproduction steps.
- Whether the issue affects Safe, Advanced, Legacy, or Restore behavior.
