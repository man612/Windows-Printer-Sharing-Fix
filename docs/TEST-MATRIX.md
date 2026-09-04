# v4 Integration Test Matrix

Static CI protects syntax and architecture rules, but printer sharing must also be validated on real/disposable Windows machines because behavior depends on OS build, driver type, policy, network profile, host/client roles, and printer hardware.

## Minimum lab topology

Use at least two Windows VMs on an isolated virtual network:

```text
CLIENT  <---- LAN ---->  PRINT-HOST  ----> printer / simulated queue
```

Do not test SMB1, insecure guest authentication, legacy LM authentication, or RPC privacy downgrade on an exposed production network just to exercise the code path.

## Core matrix

| ID | Client | Host | Driver / path | WPP | Expected focus |
| --- | --- | --- | --- | --- | --- |
| A1 | Windows 11 current | Windows 11 current | IPP / inbox | Off | Modern healthy baseline |
| A2 | Windows 11 current | Windows 11 current | Third-party legacy driver | Off | Point and Print / driver behavior |
| A3 | Windows 11 current | Windows 10 22H2 / ESU lab | Third-party legacy driver | Off | Mixed-generation shared printer |
| A4 | Windows 11 current | Windows 10 lab | Third-party legacy driver | On (client) | WPP detection and explanation |
| A5 | Windows 10 lab | Windows 11 current | Supported driver | N/A | Reverse mixed-generation path |
| A6 | Windows 11 current | Windows 11 current | Network printer connection | Off | Targeted reconnect path |

## Network scenarios

For at least one modern host/client pair, validate:

1. Private network profile, normal firewall rules.
2. Client profile set to Public.
3. Printer host firewall sharing rules disabled.
4. DNS/hostname deliberately broken while IP connectivity still exists.
5. TCP 445 blocked.
6. TCP 135 blocked.
7. Host reachable but share/credentials unavailable.

Expected behavior: the target-path diagnostic should identify the earliest failing layer and should not recommend SMB1/security downgrades when basic network transport is broken.

## Spooler / queue scenarios

1. Spooler running normally.
2. Spooler stopped.
3. Pending queue with disposable test jobs.
4. Clear queue and confirm explicit irreversible-action warning.
5. Restart Spooler and confirm service returns to Running.
6. Restore after non-destructive Safe Repair and compare service state to snapshot.

## Point and Print scenario

1. Use a test printer share that triggers driver installation/admin approval.
2. Record original `RestrictDriverInstallationToAdministrators` state.
3. Run the temporary connection action.
4. Confirm the value is relaxed only during the connection attempt.
5. Force the connection attempt to fail and confirm the `finally` block still restores the original state.
6. Repeat with a successful connection.

This failure-path test is important: rollback must happen even when printer installation throws an error.

## RPC scenarios

### Normal

- No compatibility override.
- Confirm normal RPC/TCP printing remains functional.

### Named Pipes fallback

- Client-only machine: verify only client-side Named Pipes policy is changed.
- Host-only machine: verify host RPC protocol listener policy is changed.
- Host+client machine: verify both role-relevant values are handled.
- Restore and confirm the exact original state, including a value that was originally absent.

### RPC privacy downgrade

- Confirm the option is not present in Safe Repair.
- Confirm typed `RISK` is required.
- Confirm `RpcAuthnLevelPrivacyEnabled=0` is detected as a warning by Diagnose.
- Restore immediately after the compatibility test.

## WPP scenarios

1. WPP disabled.
2. WPP enabled through normal Windows Settings.
3. WPP enabled through policy in a managed-test scenario.
4. Legacy third-party-driver printer with WPP enabled.

Expected behavior:

- Diagnose reports WPP when detected.
- Advanced WPP help explains the compatibility implication.
- Policy-enforced WPP is not silently bypassed by the utility.

## Legacy scenarios

Only on an isolated test network.

### SMB1

- Use a target proven to require SMB1.
- Confirm v4 enables `SMB1Protocol-Client`, not the whole SMB1 feature tree/server.
- Confirm Restore returns the feature to its original state.

### Insecure guest

- Confirm explicit `LEGACY` confirmation is required.
- Confirm Diagnose reports `AllowInsecureGuestAuth=1` as a warning.
- Confirm Restore returns the previous registry state.

### LAN Manager compatibility

- Confirm explicit `LEGACY` confirmation is required.
- Confirm Diagnose warns when the level is legacy/weak.
- Confirm Restore returns the previous value/absence.

### Blank passwords

- Confirm there is no code path that sets `LimitBlankPasswordUse=0`.
- Confirm the menu explains that password-protected credentials should be used instead.

## Restore-state tests

For each managed setting, test three original states where applicable:

1. Value absent.
2. Value present with the same value v4 wants to apply.
3. Value present with a different value.

After Restore, compare with the pre-change snapshot. A value that was originally absent must be removed again, not replaced with an assumed default.

Also test:

- Network category by exact InterfaceIndex.
- Firewall Enabled/Profile values.
- SMB1 client feature state.
- Service running state and startup mode.

## Localization / UX

1. Fresh clone starts in English.
2. Switch to Indonesian.
3. Restart and confirm language preference persists.
4. Confirm destructive/high-risk prompts remain understandable in both modes.
5. Run in a narrow terminal and verify important warnings remain readable.

## Full hardware-validation gate

The project CI can validate code safety and packaging without physical printer hardware. Before claiming broad real-world hardware validation, complete at least:

- GitHub validation workflow passing.
- No Safe Repair security downgrade.
- Successful restore tests for all managed states.
- At least one Windows 11 -> Windows 11 real shared-printer test.
- At least one Windows 11 -> Windows 10/legacy-host mixed-generation test.
- WPP-on test.
- Temporary Point and Print failure-path rollback test.
- No known case where Diagnose recommends a security downgrade before checking basic network failure layers.
