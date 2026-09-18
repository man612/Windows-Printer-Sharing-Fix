# Structured Diagnostic JSON

The machine-readable contract is published as [`diagnosis.schema.json`](diagnosis.schema.json) using JSON Schema Draft 2020-12.

Windows Printer Sharing Fix can export the **latest in-memory diagnosis** as machine-readable JSON from **Tools and Logs > Export latest diagnosis as sanitized JSON**.

The export does not run a second diagnosis when a cached diagnosis already exists. If no diagnosis has been run in the current session, the export command runs one read-only diagnosis and serializes that result.

## Headless export

From an already-elevated Windows PowerShell session:

```powershell
.\FixPrinter.ps1 -DiagnoseOnly -Json C:\Temp\printer-diagnosis.json
```

`-JsonOutput` is the canonical parameter name and `-Json` is its alias. With no output path, headless mode writes `%LOCALAPPDATA%\WindowsPrinterSharingFix\exports\diagnostic-headless.json`. It does not enter the menu or self-elevate; non-elevated use exits with code `5`.

The headless path reuses `Invoke-Diagnosis -Quiet` plus `Export-DiagnosticJson`; it is not a second diagnosis implementation.

## Storage

Exports are written locally under:

```text
%LOCALAPPDATA%\WindowsPrinterSharingFix\exports\
```

There is no telemetry and no automatic upload.

## Privacy boundary

The structured export is sanitized by design. It does **not** include:

- computer/host names;
- usernames or domain names;
- credentials;
- IP addresses or SSIDs;
- printer names, share names, UNC paths, port names, or interface aliases;
- raw PrintService event messages.

It does include Windows/build information (base build, UBR revision when available, and normalized full build), inferred host/client role, printer counts, network-profile categories/connectivity, WPP and relevant policy states, SMB1 client state, finding text, timing metadata, and sanitized PrintService event metadata.

Always review a file before posting it publicly. Policy values can describe the security posture of a machine even when identity fields are omitted. `PolicySources` contains only normalized labels such as `LocalGroupPolicy`, `GroupPolicy`, `PossibleMdmOrOtherPolicy`, or `RegistryOnlyOrUnknownSource`; raw GPO/tenant/management identifiers are intentionally omitted.

## Schema

Current identity:

```json
{
  "Schema": "windows-printer-sharing-fix/diagnosis",
  "SchemaVersion": 1
}
```

Schema v1 is now machine-validated against `diagnosis.schema.json`. Existing v1 fields keep their documented types and meaning; a future breaking shape change requires an explicit `SchemaVersion` change rather than silently changing the contract.

Top-level fields:

| Field | Meaning |
| --- | --- |
| `Schema`, `SchemaVersion` | Export format identity/version. |
| `ToolVersion` | Windows Printer Sharing Fix version that produced the data. |
| `CollectedAtUtc` | When the diagnosis itself was collected. |
| `ExportedAtUtc` | When the JSON file was written. |
| `Language` | TUI language active when findings were generated. |
| `Sanitized`, `Privacy` | Privacy metadata for the export. |
| `Windows` | Product/build, installation type, server flag, PowerShell version. |
| `Role` | Inferred `Host`, `Client`, `Host + Client`, or local/unknown role. |
| `Spooler` | Presence and current service status. |
| `PrinterSummary` | Total/shared/network-connection counts only. |
| `DriverSummary` | Aggregate normalized driver-model/provider/known-technology counts; no printer/driver/provider names or INF paths. |
| `NetworkProfiles` | Category and IPv4/IPv6 connectivity without profile names. |
| `WPP` | Windows Protected Print state and relevant registry state. |
| `SmbSecurity` | Effective SMB client/server signing and encryption posture from the Windows SMB provider; no server/share identifiers. |
| `Policies` | Relevant RPC (including explicit TCP port, Kerberos/listener state), Point and Print, guest, LM, and blank-password policy state. |
| `PolicySources` | Normalized source evidence for mapped printer policies; no GPO/domain/tenant identifiers are exported. |
| `NextInvestigation` | Conservative normalized next-layer priority derived from existing evidence; never a root-cause claim. |
| `FunctionalVerification` | Optional sanitized last guided test-page result: timestamps, request/outcome status, network-connection boolean, and normalized driver classification only. |
| `SMB1Client` | Current Windows optional-feature state. |
| `PrintServiceEvents` | Timestamp, event ID, level, normalized troubleshooting category, and optional Event 372 Win32 code/class; raw message text is omitted. |
| `Findings` | Severity and human-readable diagnosis finding. |
| `TimingMs` | Per-stage and total diagnosis timing from the same diagnosis run. |
| `TargetPath` | Optional sanitized result from the latest shared-printer path test in the same diagnosis session, including normalized configured print-RPC port reachability and SMB-security signals when applicable. |

## Target-path result

When a shared-printer path test has been run after the latest diagnosis, `TargetPath` can contain only booleans and a normalized likely-layer label:

```json
{
  "DnsResolved": true,
  "Smb445Reachable": true,
  "Rpc135Reachable": false,
  "ShareNamespaceAccessible": false,
  "PrinterInstalled": false,
  "LikelyLayer": "RpcReachability"
}
```

The hostname and printer/share path are deliberately omitted. Starting a new diagnosis clears the previous target-path result so exports do not mix two diagnostic sessions.

## Read-only guarantee

CI fingerprints the registry values, network profiles, File and Printer Sharing firewall state, SMB1 client state, and Spooler state before and after diagnosis/export. The JSON export itself only serializes the existing diagnosis object and writes a local file.
