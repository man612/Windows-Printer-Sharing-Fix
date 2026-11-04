# A1 — Windows 11 host/client lab runbook

This is a read-only readiness check. It is NOT a simulated or verified print. A1 is currently **⏸ Deferred** (2026-11-04) because a second Windows PC is not available. The entry in REAL-WORLD-RESULTS.md must not be set to Validated until an actual two-system test proves that a print job reaches its intended output, with sanitized evidence.

## Prerequisites

- Two separate Windows 11 computers or VMs on an isolated, trusted private network. Do not reconfigure a production printer host just to test.
- A deliberately configured lab printer/share, ideally using Microsoft IPP Class Driver or another supported inbox printing path. Record the actual driver family manually.
- A copy of this repository's tested PR branch on both computers.
- Windows 11 VMs require Generation 2, Secure Boot, vTPM, two virtual CPUs and at least 4 GB RAM per VM, plus host resources. Installing Hyper-V does not create available RAM.

## Read-only evidence from each side

On the PRINT HOST, in a Windows PowerShell console opened at the repository root:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-A1Readiness.ps1 -Role Host -ShareName "LabPrinter"

On the CLIENT, using the actual lab host and share:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-A1Readiness.ps1 -Role Client -PrinterPath "\\LAB-HOST\LabPrinter"

Both commands are read-only with respect to Windows printer and security settings. They do not install a printer, submit any print job, open firewall ports, restart Spooler, enable SMB1, change Point and Print policy or change the network profile. They create sanitized JSON under %TEMP%\WindowsPrinterSharingFix-Evidence. Review the files before public sharing.

Host fields include share presence in the local printer inventory, a limited driver indicator, Spooler state and the OS build. Client fields include name resolution, bounded TCP 445/135 probes and whether the exact UNC connection appears in its local printer inventory. All reports omit hostnames, IP addresses, share names, printer names, driver names, credentials and usernames.

Important limitations: WPP is only indicated by registry-based evidence here (not an authoritative effective-mode determination); RPC 135 can be unreachable even when RPC Named Pipes are configured; and a successful transport check or printer installation is NOT functional print verification.

## Actual functional A1 test

1. Confirm host and client Windows 11 full builds (including UBR), private network, driver family and WPP state from Windows Settings or effective management policy.
2. Confirm the host deliberately shares a test queue and the client is connected to its exact share. Do not reduce Windows security to establish this baseline.
3. Submit a Windows test page FROM THE CLIENT in the lab. Confirm that a physical printer or an intentionally observable lab receiver actually receives the page/job. An Add-Printer success message or a PrintUI command exit code alone does not count.
4. Record the actual result, first failing diagnosis layer (if any), highest repair tier and Restore outcome if tested. Preserve the separate host/client JSON reports.
5. Open a Compatibility report issue with only sanitized evidence. Update REAL-WORLD-RESULTS.md from Pending to Validated only after review of the actual print result and both sides' evidence.

Never enable SMB1, insecure guest authentication, LAN Manager downgrades or Point and Print driver-installation relaxation to force A1 to pass. These belong only in explicitly isolated, separately reviewed legacy experiments.

## Official sources

- Microsoft Windows 11 VM requirements: https://learn.microsoft.com/en-us/windows/whats-new/windows-11-requirements
- Windows 11 printer RPC transport: https://learn.microsoft.com/en-us/troubleshoot/windows-client/printing/windows-11-rpc-connection-updates-for-print
- Printer connection: https://learn.microsoft.com/en-us/powershell/module/printmanagement/add-printer
