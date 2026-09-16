# Guided test-page verification

The stable PowerShell TUI can optionally request one real Windows test page for an already-installed printer.

This is an explicit functional-verification action, not part of Diagnose. Diagnose remains read-only and never prints automatically.

## Flow

1. Open **Tools and Logs** and choose **Guided Windows test-page verification**.
2. Select an already-installed printer.
3. Read the warning that a real print job can consume paper, labels, ink, or toner.
4. Explicitly confirm before Windows receives any test-page request.
5. The tool invokes the documented PrintUI test-page entry point.
6. Check the physical printer and report `Printed`, `DidNotPrint`, or `NotConfirmed`.

A successful PrintUI request means only that Windows accepted the command. It is never treated as proof that the physical printer produced output.

## Windows mechanism

The request uses `rundll32 printui.dll,PrintUIEntry /k /n <printer>`. Microsoft documents `/k` as printing a test page on the named printer.

Reference: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/rundll32-printui
## Privacy and state boundaries

The local selection screen can show the installed printer name and driver so the user can choose the correct device. The persistent functional-verification record intentionally stores only normalized data:

- verification timestamp;
- diagnostic timestamp it belongs to;
- request status: `Submitted` or `Failed`;
- user-confirmed outcome: `Printed`, `DidNotPrint`, or `NotConfirmed`;
- whether the selected queue was a network connection;
- normalized driver model/provider/known-technology classification.

Printer names, driver names, ports, share names, hostnames, provider strings, INF paths, and raw command arguments are not written into the verification record or sanitized JSON.

Running a new diagnosis clears the previous functional-verification record so stale physical confirmation is not attached to newer diagnostic evidence.

## Safety and testing

The verification path does not install, remove, or connect printers and does not change firewall, SMB, RPC, driver, queue, or policy settings.

Automated tests never invoke a real print job. They replace the PrintUI request with a stub and verify that explicit confirmation is required before the stub can be called, that command construction is correct, and that exported/logged verification data remains sanitized.
