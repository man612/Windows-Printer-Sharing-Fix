# Printer policy source evidence

Windows Printer Sharing Fix reports **source evidence**, not an absolute policy origin. The same effective registry value can be written by Local Group Policy, domain Group Policy, MDM/Policy CSP, a script, an installer, or a manual registry change.

The diagnosis therefore uses conservative normalized labels:

| Label | Meaning |
| --- | --- |
| `LocalGroupPolicy` | RSoP matched the exact registry key/value and identified `LocalGPO` / local scope. |
| `GroupPolicy` | RSoP matched the exact registry key/value to applied Group Policy evidence that is not explicitly local. |
| `PossibleMdmOrOtherPolicy` | No RSoP match exists, the setting is documented as MDM-capable for this Windows build, and Windows management-plane evidence is present. This is **not** proof of a specific MDM product or tenant. |
| `RegistryOnlyOrUnknownSource` | The effective registry value exists, but the tool has no stronger source evidence. |
| `NotConfigured` | The effective registry value was not present. |

## Group Policy evidence

For computer policy, the tool queries `root\RSOP\Computer` and `RSOP_RegistryPolicySetting` read-only. It matches the exact normalized registry key and value name, ignores deleted RSoP entries, and uses the highest-precedence matching result.

RSoP evidence is stronger than inferring source from `HKLM\Software\Policies` alone. A policy-registry path by itself does not prove that a domain GPO wrote the value.

## MDM-aware evidence

Several printer policies are documented by Microsoft as ADMX-backed Policy CSP settings. When no RSoP match exists, the tool can report `PossibleMdmOrOtherPolicy` only when the Windows build supports that policy path and management-plane evidence is present.

The label deliberately says **possible**. The tool does not identify an MDM vendor, tenant, organization, server URL, or enrollment ID, and it does not treat stale `HKLM\SOFTWARE\Microsoft\Enrollments` GUIDs alone as proof of active management.

## Current printer-policy coverage

Source evidence is currently normalized for:

- RPC packet privacy;
- RPC named-pipe transport policy;
- RPC protocol policy;
- `RestrictDriverInstallationToAdministrators` / Point and Print protection;
- Windows Protected Print group-policy state.

Other security-related registry states can still appear in diagnosis, but they are not assigned a policy-source label unless the tool has an explicit source-evidence mapping.

## Privacy boundary

The local runtime may inspect RSoP metadata to determine the normalized source label, but sanitized JSON exports only `Configured`, `Source`, and `Evidence`. It does not export GPO IDs, SOM/domain identifiers, tenant identifiers, management-provider identifiers, MDM server URLs, or organization names.

## References

- Microsoft `RSOP_RegistryPolicySetting`: https://learn.microsoft.com/en-us/previous-versions/windows/desktop/policy/rsop-registrypolicysetting
- `gpresult`: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/gpresult
- Policy CSP - Printers: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-printers
- Windows MDM enrollment troubleshooting: https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/troubleshoot-windows-auto-enrollment

The classification is intentionally conservative. If Windows exposes only an effective registry value and no reliable provenance evidence, the correct result is `RegistryOnlyOrUnknownSource`, not a guessed administrator, domain, or management platform.
