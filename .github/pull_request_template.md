## What problem does this solve?

Describe the real Windows printer-sharing failure, contributor friction, or documentation gap.

## What changed?

- Describe the implementation at a high level.

## Risk / scope

- [ ] Diagnosis/read-only only
- [ ] Safe Repair behavior
- [ ] Advanced compatibility behavior
- [ ] Legacy/high-risk behavior
- [ ] Restore/runtime state
- [ ] Documentation/tests only

If Windows state changes, list every registry value, service, firewall/network setting, optional feature, or printer connection affected.

## Verification

- [ ] `tests/Validate.ps1`
- [ ] `tests/RuntimeSmoke.ps1`
- [ ] `tests/LocalizationSmoke.ps1`
- [ ] `tests/PackageSmoke.ps1`
- [ ] `tests/WorkspaceSmoke.ps1`
- [ ] Relevant disposable host/client scenario tested when repair behavior changed

## Safety checklist

- [ ] Safe Repair still contains no security downgrade.
- [ ] High-risk changes are isolated and explicitly confirmed.
- [ ] Reversible state is captured before modification.
- [ ] Irreversible actions are clearly warned.
- [ ] English and Indonesian user-facing text remain aligned.
- [ ] Logs/docs contain no credentials or unrelated sensitive data.

## Restore / rollback

Explain how the change is reverted, or why it is inherently irreversible.
