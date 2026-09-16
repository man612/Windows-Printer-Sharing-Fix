# PrintService Event Classification

Windows Printer Sharing Fix reads a small, bounded set of recent warning/error events from `Microsoft-Windows-PrintService/Admin` during diagnosis. The stable runtime now adds a conservative **troubleshooting category** to known event IDs instead of reporting only a raw count.

This is evidence triage, not root-cause proof. A historical event can describe a problem that has already cleared, multiple events can come from the same failure, and Windows can add or change event definitions over time. Unknown IDs stay `OtherPrintService` rather than being guessed.

## Categories

| Category | Representative high-confidence event IDs | What the layer means |
| --- | --- | --- |
| `PrintJob` | 107, 111, 123, 125, 314, 350, 353, 372, 828 | A document/job failed during the print path. |
| `DriverOrPackage` | 115, 213, 215, 217, 219, 225-242, 348, 351, 359, 368-370, 600-601, 808, 852, 869-870 | Driver/package/plugin installation, loading, compatibility, or integrity. |
| `SharingOrConnection` | 101, 119, 201, 205, 207, 211, 221, 224, 315, 371, 513-520, 827 | Printer sharing, connection, or deployment path. |
| `SpoolerOrRpc` | 99, 354, 362, 373, 502-512, 815-818 | Print Spooler infrastructure or its RPC server path. |
| `PortOrProcessor` | 319, 320, 361, 364-365, 367, 701-704, 814, 820, 822, 824-825, 867 | Port, print processor, filter pipeline, or related component. |
| `Policy` | 851, 871 | Windows policy explicitly rejected or blocked a print operation. |
| `DirectoryOrGpo` | 322, 323, 325-329, 331, 333, 335, 337, 347 | Active Directory publication / directory-related deployment. |
| `OtherPrintService` | anything else | The tool has no high-confidence classification for that ID. |

The mapping is intentionally smaller than the full PrintService provider manifest.
## Event 372 and Win32 codes

Event 372 is special because the provider template includes the Win32 error returned by the print processor. The tool reads only that numeric field and maps a small set of documented Windows error codes into normalized classes.

| Code class | Example codes | Interpretation boundary |
| --- | --- | --- |
| `AmbiguousSuccessCode` | 0 | Event 372 still says the job failed; code 0 alone must **not** make the result healthy. |
| `FileOrSpoolPath` | 2, 3, 3002 | File/path/spool-file clue. |
| `AccessOrPermission` | 5, 65 | Access/permission clue. |
| `NetworkPathOrName` | 53, 64, 67 | Network path/name clue. |
| `QueueOrSpool` | 61, 62, 63, 72, 3009, 3020 | Queue/spool state clue. |
| `Rpc` | 1722, 1726, 1727 | RPC reachability/call clue. |
| `PrinterOrDriverState` | selected printer/port/driver codes such as 1801 and 3012 | Printer, port, driver, or printer-state clue. |
| `OtherWin32` | any other numeric code | Preserve the number without inventing a meaning. |

The normalized class narrows the next investigation layer; it does not prove which device, policy, firewall, driver, or application caused the failure.

## Privacy

The local TUI can still show a shortened raw event message because it is being viewed on the same machine. The structured JSON export intentionally does **not** export that message. It exports only the timestamp, event ID, level, normalized category, and optional Event 372 Win32 code/class.

Printer names, document names, usernames, client computer names, DLL paths, and other message parameters therefore remain outside the machine-readable report.
## Why these mappings

The mappings come from the Windows PrintService provider metadata exposed by Windows plus Microsoft documentation for known PrintService/Point and Print events and Win32 system error codes. Examples include Event 215 for printer-driver installation failure, Event 315 for sharing failure, Event 372 for a failed document, Event 808 for plug-in loading failure, and Event 851 for Point and Print policy rejection.

Microsoft references:

- [Event IDs associated with Point and Print restrictions](https://learn.microsoft.com/troubleshoot/windows-server/printing/event-ids-associated-point-print-restrictions)
- [System Error Codes 0-499](https://learn.microsoft.com/windows/win32/debug/system-error-codes--0-499-)
- [System Error Codes 1700-3999](https://learn.microsoft.com/windows/win32/debug/system-error-codes--1700-3999-)

## Testing policy

`tests/PrintEventClassificationSmoke.ps1` uses synthetic events to lock the category/code semantics without requiring a second PC or deliberately breaking a real printer. Runtime smoke still verifies that any real PrintService events collected on the test machine carry a normalized category, while the managed Windows-state fingerprint remains unchanged.