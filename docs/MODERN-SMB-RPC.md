# Modern SMB/RPC diagnostics

Windows Printer Sharing Fix treats modern SMB and print RPC security as **diagnostic evidence**, not as a reason to weaken Windows security.

Windows 11 22H2 and later use RPC over TCP by default for print-related client/server communication. TCP 135 is only the RPC Endpoint Mapper. Successful reachability on 135 does not prove that the later dynamic RPC port is reachable.

The tool therefore keeps these layers separate.

## Print RPC policy evidence

Diagnosis reads these settings without changing them:

- `RpcUseNamedPipeProtocol` — outgoing print RPC transport compatibility.
- `RpcProtocols` — incoming print RPC listener protocols.
- `RpcTcpPort` — optional explicit TCP port for print RPC instead of only dynamic RPC ports.
- `ForceKerberosForRpc` — optional Kerberos-only listener authentication.
- `RegisterSpoolerRemoteRpcEndPoint` — whether the Print Spooler accepts remote client connections.
- `RpcAuthnLevelPrivacyEnabled` — existing packet-privacy compatibility state.

Source evidence remains conservative. RSoP is preferred when it matches the exact policy value; otherwise the result stays MDM-aware or unknown rather than guessing an administrator, domain, or management platform.
## Target-path behavior

For a requested `\\HOST\Printer` path the tool still checks, in order:

1. name resolution;
2. TCP 445 / SMB;
3. TCP 135 / RPC Endpoint Mapper;
4. the explicitly configured `RpcTcpPort`, only when local Windows print policy defines a valid nonzero port;
5. host share namespace access;
6. whether the printer is already installed locally.

The configured-port probe reuses the same bounded TCP helper used by the existing target test. It does not scan dynamic RPC port ranges.

If no explicit `RpcTcpPort` exists, the tool does **not** pretend it has tested dynamic RPC reachability.

## SMB security posture

The normal read-only diagnosis reads effective SMB client/server security posture through the Windows SMB CIM provider rather than invoking the much slower high-level SMB configuration cmdlets.

Normalized posture includes:

- client signing requirement;
- client encryption requirement;
- effective insecure-guest allowance;
- client signing/encryption audit flags;
- server signing requirement;
- server-wide encryption state;
- server rejection of unencrypted access;
- server signing/encryption audit flags.

These are configuration facts. A secure setting being enabled is not itself classified as a failure.
## SMB security events

SMB event logs can be expensive to query. They are therefore **not scanned broadly during every Diagnose run**.

When TCP 445 is reachable but the requested host namespace is not accessible, the target-path test can inspect only documented recent client-side event IDs and reduce them to normalized categories:

- SMBClient/Security **31017** -> `RejectedInsecureGuest`;
- SMBClient/Audit **31998/31999** -> `SigningOrEncryptionCompatibility`.

The classifier also understands SMBServer/Audit **3021/3022** for synthetic/regression coverage and future host-side use.

Raw SMB event messages, hostnames, server names, shares, and IP addresses are not added to structured JSON. The normalized categories are supporting evidence only and are not assumed to belong to the requested target unless Windows evidence can prove that association.

## Safety boundary

This feature does not:

- disable SMB signing;
- disable SMB encryption;
- enable insecure guest authentication;
- enable SMB1;
- weaken Kerberos or RPC authentication;
- open dynamic RPC port ranges;
- change firewall policy.

Existing compatibility and legacy actions keep their previous confirmation and restore boundaries.
## References

Microsoft documentation used for this behavior:

- Windows 11 RPC connection updates for print: https://learn.microsoft.com/en-us/troubleshoot/windows-client/printing/windows-11-rpc-connection-updates-for-print
- Printers Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-printers
- ADMX_Printing2 Policy CSP / remote Spooler RPC endpoint: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-printing2
- SMB signing overview: https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing-overview
- SMB client encryption requirement: https://learn.microsoft.com/en-us/windows-server/storage/file-server/configure-smb-client-require-encryption
- Insecure SMB guest logon auditing: https://learn.microsoft.com/en-us/windows-server/storage/file-server/enable-insecure-guest-logons-smb2-and-smb3

The implementation deliberately prefers incomplete-but-accurate evidence over a confident-looking root-cause guess.
