# Real-World Compatibility Results

This ledger tracks **accepted real host/client evidence** for the v4 test matrix. It is intentionally separate from the planned scenarios in `TEST-MATRIX.md` so planned coverage is not confused with completed validation.

A row becomes `Validated` only after a real or disposable-lab setup exercises the expected behavior and links to a sanitized compatibility report. Static CI, code inspection, or a local diagnosis-only run does not count as hardware/network validation.

## Core matrix status

| ID | Client | Host | Driver / path | WPP | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | Windows 11 current | Windows 11 current | IPP / inbox | Off | Pending | — |
| A2 | Windows 11 current | Windows 11 current | Third-party legacy driver | Off | Pending | — |
| A3 | Windows 11 current | Windows 10 22H2 / ESU lab | Third-party legacy driver | Off | Pending | — |
| A4 | Windows 11 current | Windows 10 lab | Third-party legacy driver | On (client) | Pending | — |
| A5 | Windows 10 lab | Windows 11 current | Supported driver | N/A | Pending | — |
| A6 | Windows 11 current | Windows 11 current | Network printer connection | Off | Pending | — |

## Status meanings

- `Pending` — no accepted real-world evidence yet.
- `Reported` — a useful report exists, but one or more required checks are incomplete.
- `Validated` — expected behavior was exercised and the evidence is sufficient for this matrix row.
- `Regression` — an accepted report shows behavior that conflicts with the expected result or a previously validated case.

A single report may support more than one secondary scenario, but each A1–A6 row should have its own clearly identifiable evidence before being marked `Validated`.

## Minimum evidence for an accepted report

Record all of the following:

1. Exact host and client Windows product/build.
2. Stable tool version or commit SHA.
3. Printer/driver path: IPP/inbox, vendor/third-party, existing network connection, or simulated queue.
4. WPP state and relevant network profile.
5. Earliest failing or relevant diagnosis layer.
6. Highest repair tier required, including `None` for a healthy baseline.
7. Functional result: whether the share/connection/print path actually worked as expected.
8. Restore result whenever a managed change was tested.

For failure-path tests, include the failure that was deliberately introduced and confirm that the tool identified the earliest broken layer before compatibility or legacy workarounds were considered.

## What does not count as validation

- CI passing by itself.
- Reading the source and concluding that a path should work.
- A diagnosis-only run on one PC with no host/client printer-sharing path exercised.
- A screenshot with no exact Windows build or driver context.
- A report that only says a workaround worked but does not identify which state changed.
- Enabling SMB1, insecure guest auth, LAN Manager downgrade, or RPC privacy downgrade on an exposed production network merely to fill a matrix row.

## How to submit a result

Open the repository's **Compatibility report** issue form. Choose the A1–A6 case, fill the structured fields, and attach only sanitized evidence. For repeatable lab collection, `tools/Collect-LabEvidence.ps1` can generate local Markdown and JSON without common machine/network identifiers. Installed driver names and security-posture values are also omitted by default; add the target driver manually in the issue form. Use `-IncludeDriverNames` or `-IncludeSecurityPosture` only when that extra detail is necessary and safe to publish.

Accepted reports should be linked from the table above. If a report exposes a bug or regression, keep the matrix status honest and link the follow-up issue/PR rather than marking the case as validated.

## Privacy boundary

Do not publish hostnames, usernames, domain names, credentials, IP addresses, SSIDs, UNC server/share names, or other identifiers that are unnecessary to reproduce the compatibility result. Printer model and driver family are useful when they are not themselves sensitive.
