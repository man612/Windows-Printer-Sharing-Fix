# Windows Protected Print readiness evidence

Windows Printer Sharing Fix reports **local readiness evidence** for Windows Protected Print (WPP) and Windows Ready Print. It does not certify whether a physical printer model is compatible with WPP.

## Why this is separate from compatibility

Microsoft documents that WPP exclusively uses Windows Ready Print. Windows Ready Print includes IPP-based printing and Universal Print and does not require third-party printer drivers.

When WPP is enabled, Windows removes printers that use third-party drivers. A Mopria-capable printer that was previously installed with a third-party driver may still be reinstallable through Windows Ready Print. Therefore, seeing a third-party driver binding proves a **current dependency on that driver**, not that the physical device itself is incompatible.

The tool deliberately keeps these statements separate:

- **binding evidence** — what the currently installed Windows printer binding uses;
- **device compatibility** — whether the actual printer can operate through Windows Ready Print/WPP.

`DeviceCompatibilityProven` is always `false` because the local driver inventory cannot prove Mopria certification or hardware capability.
## Normalized binding evidence

The readiness summary uses only the existing normalized driver classification:

- `Microsoft IPP Class Driver` with Microsoft provider metadata -> known Windows Ready Print binding;
- `Universal Print Class Driver` with Microsoft provider metadata -> known Windows Ready Print binding;
- any binding classified as `ThirdParty` -> current third-party driver dependency;
- Microsoft/unknown bindings without one of the exact known technologies -> unknown/other local evidence.

The summary contains:

- `OsSupportsWpp` — client Windows build evidence for WPP availability; Windows Server is not marked supported from build number alone;
- `WppEnabled` — current WPP state already collected by diagnosis;
- `EvidenceScope=InstalledPrinterBindingsOnly`;
- `LocalBindingState`;
- total/Ready Print/third-party/unknown binding counts;
- separate Microsoft IPP and Universal Print class-driver counts;
- `DeviceCompatibilityProven=false`.

`LocalBindingState` can be:

- `NoInstalledPrinters`;
- `WindowsReadyPrintBindingsOnly`;
- `ThirdPartyDriverDependenciesPresent`;
- `MixedOrUnknown`.
## Interpretation

If WPP is disabled and third-party bindings exist, the diagnosis explains that enabling WPP would remove those **current bindings**. It also explicitly states that this does not prove the physical devices are incompatible.

If WPP appears enabled while the local inventory still reports third-party bindings, the tool treats that as pending/stale local evidence worth verifying. It does not disable WPP or remove/reinstall printers.

Unknown evidence remains unknown. A Microsoft-provided driver that is not one of the exact known Windows Ready Print class-driver technologies is not automatically called WPP-ready.

## Windows print-platform transition

Microsoft's current servicing plan for legacy third-party v3/v4 print drivers says:

- January 15, 2026: no new Windows 11+/Windows Server 2025+ printer drivers are published to Windows Update, with limited case-by-case exceptions;
- July 1, 2026: Windows driver ranking was changed to always prefer the Windows IPP inbox class driver;
- July 1, 2027: non-security updates for third-party printer drivers are no longer allowed.

Microsoft also states that WPP will be enabled by default at a future date.
## Safety and privacy

This feature is read-only. It does not:

- enable or disable WPP;
- remove or reinstall a printer;
- install or delete a driver;
- query the Mopria product database;
- export printer names, model names, driver names, INF paths, or provider names in structured JSON;
- convert readiness evidence into an automatic repair decision.

Structured JSON contains only normalized aggregate counts/state.

## References

- Windows Protected Print Mode FAQ: https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/windows-protected-mode-faq
- Windows Protected Print Mode overview: https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/windows-protected-print-mode
- Windows Ready Print: https://learn.microsoft.com/en-us/windows/modern-print/windows-ready-print
- Printers Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-printers
- End of servicing plan for third-party printer drivers: https://learn.microsoft.com/en-us/windows-hardware/drivers/print/end-of-servicing-plan-for-third-party-printer-drivers-on-windows

The implementation intentionally prefers incomplete-but-accurate local evidence over a compatibility claim.
