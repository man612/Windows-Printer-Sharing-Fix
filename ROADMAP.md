# Roadmap

This roadmap describes direction, not a promise of release dates. Stable behavior stays conservative: diagnosis first, smallest relevant repair, explicit risk, scoped restore.

## Stable v4 priorities

### Reliability

- Expand disposable host/client testing across Windows 10, Windows 11, and Windows Server.

### Verification

- Add optional guided test-page verification.
- Harden the versioned structured-diagnosis schema only when real consumers need additional fields.
- Grow the integration matrix with anonymized real-world hardware/driver results and track accepted evidence in `docs/REAL-WORLD-RESULTS.md`.

### Distribution and docs

- Keep release ZIPs reproducible and checksummed.
- Keep English and Indonesian onboarding current.
- Add sanitized screenshots or short recordings when they improve troubleshooting rather than decorate the repo.

## Experimental UI

The OpenTUI frontend in draft PR #2 is an experiment. It will not replace the stable PowerShell TUI until it is clearly better in reliability, accessibility, keyboard behavior, terminal cleanup, packaging, and real-world usability.

## Good contribution areas

- Reproduce a printer-sharing failure in a disposable lab and document the failing layer.
- Test a specific Windows/printer-driver combination and add an anonymized matrix result.
- Improve documentation, translations, or event-ID explanations.
- Add tests that prove a repair stays narrow and reversible.

See [CONTRIBUTING.md](CONTRIBUTING.md) before changing repair behavior.
