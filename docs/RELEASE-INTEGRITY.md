# Release integrity and provenance

Stable release artifacts are built so users can verify the bytes they downloaded, the workflow that produced those bytes, and the immutable GitHub Release they came from.

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

A checksum detects changed bytes. It does not by itself prove which repository, workflow, commit, or GitHub Release produced them.

## GitHub build-provenance attestation

The stable tag workflow generates GitHub build-provenance attestations for the release ZIP and checksum manifest before publication.

For the strongest normal verification, pin the expected repository, signer workflow, source ref, and source commit:

```powershell
$repo = 'man612/Windows-Printer-Sharing-Fix'
$tag = 'vX.Y.Z'
$zip = ".\Windows-Printer-Sharing-Fix-$tag.zip"
$sourceDigest = gh api "repos/$repo/commits/$tag" --jq .sha

gh attestation verify $zip `
  --repo $repo `
  --signer-workflow "$repo/.github/workflows/release.yml" `
  --source-ref "refs/tags/$tag" `
  --source-digest $sourceDigest
```

The exact-source filters matter when the same artifact digest has more than one valid build attestation, for example after a failed release retry that rebuilt identical bytes. They select the attestation tied to the intended tag commit instead of accepting any valid repository-level build statement.

The attestation links the artifact digest to GitHub Actions identity data such as the repository, signer workflow, source commit, source ref, and triggering event. It is provenance evidence, not a claim that the program is vulnerability-free.

## Immutable GitHub Release verification

For immutable releases, GitHub also provides release-level attestations. With a current GitHub CLI:

```powershell
$repo = 'man612/Windows-Printer-Sharing-Fix'
$tag = 'vX.Y.Z'
$zip = ".\Windows-Printer-Sharing-Fix-$tag.zip"

gh release verify $tag -R $repo
gh release verify-asset $tag $zip -R $repo
```

`gh release verify` validates the release attestation and reports the covered assets. `gh release verify-asset` additionally verifies that the local file digest is associated with that specific release.

Use the SHA256 check, build-provenance verification, and release-asset verification together when you want the strongest practical verification of a downloaded stable ZIP.

## Release sequencing

The stable workflow is triggered by a `v*` Git tag and deliberately refuses publication unless several gates hold.

The order is intentionally:

1. check out the exact event commit rather than following a tag that may later move;
2. verify the tag/source version match;
3. verify the remote tag still resolves to that exact commit;
4. require that commit to be on `main`;
5. wait for the `Validate Windows Printer Fix` **push** run for that exact commit and require `success`;
6. preflight the existing GitHub Release state before expensive build/signing work;
7. re-run reproducible-package validation;
8. build the deterministic ZIP + checksum;
9. create or reuse a **draft** GitHub Release;
10. generate build-provenance attestations;
11. upload the release assets;
12. download the uploaded draft assets again and require their hashes/checksum relationship to match the locally built bytes;
13. publish the release last.

Runs for the same tag ref are serialized with GitHub Actions concurrency so two publication attempts for one tag cannot mutate the same draft at the same time.

This ordering is compatible with GitHub immutable releases: once repository release immutability is enabled, a published release locks the release assets and associated tag against later mutation.

Reusable GitHub Actions in the release/validation workflows are pinned to full commit SHAs rather than mutable version tags.

## Scope

These controls protect release reproducibility, integrity, provenance, and publication ordering. They do not replace code review, CI, antivirus/endpoint policy, repository branch/tag protections, or the real host/client compatibility validation tracked separately in issue #8.
