# Printer driver classification

Windows Printer Sharing Fix classifies installed printer bindings from Windows metadata. It deliberately keeps **driver model**, **provider class**, and **known technology** separate so one field is not treated as proof of another.

## Normalized fields

| Field | Values | Evidence |
| --- | --- | --- |
| Driver model | `V3`, `V4`, `Unknown` | `Get-PrinterDriver.MajorVersion` when one unambiguous matching driver exists. |
| Provider class | `MicrosoftProvided`, `ThirdParty`, `Unknown` | `Provider`, falling back to `Manufacturer`; conflicting or absent evidence stays unknown. |
| Technology | `MicrosoftIppClassDriver`, `UniversalPrintClassDriver`, `OtherOrUnknown` | Exact known Microsoft driver identity plus Microsoft provider evidence. |

A v4 driver is **not** automatically treated as IPP or modern Windows Ready Print. Third-party v4 drivers remain `V4` + `ThirdParty`.

A driver is not labeled third-party merely because its name looks like a vendor. If Windows does not expose usable provider/manufacturer metadata, provider class stays `Unknown`.

## Why this matters

Microsoft describes v4 as a refinement of the v3 print-driver model, while the current preferred Windows print platform uses the Microsoft IPP inbox class driver and Print Support Apps. Windows Ready Print avoids third-party printer-driver installation.

Windows Protected Print uses Windows Ready Print and restricts third-party printer drivers. Driver classification is therefore useful compatibility context, but it does not prove that a driver is causing a failure.
## Privacy boundary

The local diagnostic object may contain printer and driver names because the interactive report already displays local printer state. The sanitized JSON export does **not** export those names, provider strings, INF paths, hardware IDs, or printer ports.

Structured JSON contains only aggregate normalized counts in `DriverSummary`, for example counts of V3/V4/unknown and Microsoft/third-party/unknown printer bindings.

Correlation may include normalized inventory-wide signals such as `DriverInventory:ThirdPartyV3`. These are supporting context only and are never a root-cause claim or proof that the target shared printer uses that driver.

## Limits

- `MajorVersion` distinguishes the Windows v3/v4 print-driver model; it does not measure driver quality.
- `MicrosoftProvided` is provider evidence, not a blanket claim that every Microsoft-provided driver is Windows Ready Print.
- `MicrosoftIppClassDriver` is only emitted for the exact Microsoft IPP Class Driver with Microsoft provider evidence.
- DriverStore location alone is not used to claim inbox/vendor origin.
- Mopria certification cannot be inferred from local driver metadata alone.

## References

- Microsoft v4 printer driver: https://learn.microsoft.com/en-us/windows-hardware/drivers/print/v4-printer-driver
- Windows Ready Print: https://learn.microsoft.com/en-us/windows/modern-print/windows-ready-print
- Third-party printer-driver servicing plan: https://learn.microsoft.com/en-us/windows-hardware/drivers/print/end-of-servicing-plan-for-third-party-printer-drivers-on-windows
- Windows Protected Print: https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/windows-protected-print-mode
