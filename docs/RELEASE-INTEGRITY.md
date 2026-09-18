# Release integrity and provenance

Stable release artifacts are built so users can verify both the bytes they downloaded and where those bytes came from.

## Deterministic ZIP construction

`tools/Build-Release.ps1` does not use timestamp-sensitive `Compress-Archive` packaging.

The builder:

- enumerates the explicit release file set;
- normalizes ZIP paths to `/` separators;
- sorts every entry with ordinal string ordering;
- uses a fixed ZIP entry timestamp (`2000-01-01 00:00:00`);
- clears entry external attributes;
- uses the PowerShell 5.1/.NET `NoCompression` setting to minimize compression variability;
- generates `VERSION.txt` from deterministic ASCII bytes;
- writes `SHA256SUMS.txt` with deterministic CRLF/ASCII formatting.

`tests/ReproduciblePackageSmoke.ps1` copies the same source tree twice, gives each copy deliberately different file mtimes, builds both packages, and requires the ZIP and checksum hashes to match bit-for-bit.
## SHA256 verification

Download both the ZIP and `SHA256SUMS.txt` from the same GitHub Release.

On Windows PowerShell:

```powershell
$zip = '.\Windows-Printer-Sharing-Fix-vX.Y.Z.zip'
$actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$expected = ((Get-Content .\SHA256SUMS.txt -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
if ($actual -ne $expected) { throw 'Release ZIP checksum mismatch.' }
'SHA256 verified.'
```

A checksum detects changed bytes. It does not by itself prove which repository/workflow produced them.

## GitHub build-provenance attestation

The stable tag workflow generates GitHub artifact attestations for the release ZIP and checksum manifest before publication.

With GitHub CLI installed, verify the ZIP with:

```powershell
gh attestation verify .\Windows-Printer-Sharing-Fix-vX.Y.Z.zip --repo man612/Windows-Printer-Sharing-Fix
```
The attestation links the artifact digest to the GitHub repository, workflow, commit SHA, and triggering event. It is provenance evidence, not a claim that the program is vulnerability-free.

## Release sequencing

The stable workflow is triggered by a `v*` Git tag and refuses a tag that does not match the version declared in `FixPrinter.ps1`.

The order is intentionally:

1. check out the exact tag;
2. verify the tag/source version match;
3. re-run reproducible-package validation;
4. build ZIP + checksum;
5. generate provenance attestation;
6. create or reuse a **draft** GitHub Release;
7. upload all release assets;
8. publish the release last.

This ordering is compatible with GitHub immutable releases: once repository release immutability is enabled, future published releases lock the tag and assets after publication.

Reusable GitHub Actions in the release/validation workflows are pinned to full commit SHAs rather than mutable version tags.

## Scope

These controls protect release reproducibility, integrity, and provenance. They do not replace code review, CI, antivirus/endpoint policy, or the real host/client compatibility validation tracked separately in issue #8.
