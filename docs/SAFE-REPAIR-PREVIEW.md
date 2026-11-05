# Safe Repair change preview

The interactive Safe Repair menu now shows a **read-only change plan** for these actions:

- Restart Print Spooler
- Enable selected File and Printer Sharing firewall rules for Domain/Private
- Change one selected network profile to Private
- Start stopped Network Discovery services
- Combined non-destructive Safe Repair

The preview lists observed current values, planned actions, side effects and Restore limitations. **Enter alone is No**: only an explicit Yes continues. The preview happens before creating the action-specific Restore snapshot or mutating Windows. An option with nothing to change continues to avoid unnecessary snapshots.

Queue cleanup has its own separate preview and confirmation: the folder and SPL/SHD file count appear, the whole-machine irreversible impact is explained, and an empty answer cancels. Never treat queue cleanup as a no-op or automatically clear jobs from multiple machines. Cancel the individual stuck job in Windows Settings first when possible.

This is an **interactive preview**, not a PowerShell command-line -WhatIf API. Do not run FixPrinter.ps1 -WhatIf expecting it to do anything: the entry script does not declare support for that switch. Implementing native WhatIf would require SupportsShouldProcess and correctly enforced ShouldProcess checks in each mutating operation.

After the user approves, Safe Repair **re-reads** the selected service states, the eligible firewall rule set (names, enabled values, profiles, directions and actions), and/or the selected network interface (identity, profile and connectivity). If any previewed property differs, the action fails closed **before creating a new Restore snapshot** and asks the user to preview again. This also applies to combined Safe Repair. A manually edited or policy-managed firewall rule should be handled by the correct administrator rather than forcibly overwritten.

A preview is not a transaction or an atomic snapshot. Windows policies, services and firewall state can change between preview and execution. Restore covers only the states captured by a specific managed action; it cannot undo interruptions or recreate deleted print jobs. A pending Point and Print security emergency blocks repairs even if the user wants to approve a preview.

Host/client printing validation A1-A6 remains deferred until a second Windows PC or isolated two-VM lab exists.

Microsoft PowerShell design reference: https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess
