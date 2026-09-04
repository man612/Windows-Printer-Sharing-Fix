# Roadmap

This roadmap describes direction, not a promise of release dates. Stable behavior stays conservative: diagnosis first, smallest relevant repair, explicit risk, scoped restore.

## Stable v4 priorities

### Reliability

- Expand disposable host/client testing across Windows 10, Windows 11, and Windows Server.
- Add more structured interpretation for useful PrintService event IDs.
- Improve printer-driver classification (IPP/inbox/v3/v4/vendor) without guessing.
- Detect whether policy values are local, domain, or MDM-controlled before proposing conflicting changes.

### Verification

- Add optional guided test-page verification.
- Add structured JSON diagnostic export alongside the human-readable report.
- Grow the integration matrix with anonymized real-world hardware/driver results.

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
