$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$releasePath = Join-Path $repo '.github\workflows\release.yml'
$validatePath = Join-Path $repo '.github\workflows\validate.yml'
$release = Get-Content -LiteralPath $releasePath -Raw
$validate = Get-Content -LiteralPath $validatePath -Raw

foreach($pair in @(@('release',$release),@('validate',$validate))){
    $name=[string]$pair[0];$text=[string]$pair[1]
    if($text -match 'uses:\s+actions/checkout@v'){throw "$name workflow uses a mutable checkout version tag."}
    if($text -notmatch 'uses:\s+actions/checkout@[0-9a-f]{40}\s+#\s+v7'){throw "$name workflow does not pin actions/checkout to a full SHA."}
}

if($release -match 'uses:\s+actions/attest@v'){throw 'Release workflow uses a mutable attest version tag.'}
if($release -notmatch 'uses:\s+actions/attest@[0-9a-f]{40}\s+#\s+v4'){throw 'Release workflow does not pin actions/attest to a full SHA.'}

foreach($permission in @('actions: read','contents: write','id-token: write','attestations: write','artifact-metadata: write')){
    if($release -notmatch [regex]::Escape($permission)){throw "Release workflow missing permission: $permission"}
}

if($release -notmatch "tags:\s*\r?\n\s+- 'v\*'"){throw 'Stable release workflow must be triggered by v* tag pushes.'}
if($release -match 'types:\s*\[published\]'){throw 'Release workflow must not wait until after publication to build assets.'}
if($release -notmatch 'group:\s+stable-release-\$\{\{\s*github\.ref\s*\}\}'){throw 'Release workflow must serialize runs for the same tag ref.'}
if($release -notmatch 'cancel-in-progress:\s+false'){throw 'Release workflow must not cancel an in-progress publication for the same tag.'}
if($release -notmatch 'ref:\s+\$\{\{\s*github\.sha\s*\}\}'){throw 'Release workflow must checkout the immutable event commit SHA.'}

$labels=@(
    'Checkout release commit',
    'Verify tag matches stable source version',
    'Verify tag source and main validation gate',
    'Preflight release state',
    'Validate reproducible packaging',
    'Build deterministic user package and checksum',
    'Create or reuse draft release',
    'Generate build provenance attestation',
    'Upload release assets to draft',
    'Verify uploaded release assets',
    'Publish release after verified assets and attestation are ready'
)
$positions=@()
foreach($label in $labels){
    $index=$release.IndexOf($label,[StringComparison]::Ordinal)
    if($index -lt 0){throw "Release workflow is missing step: $label"}
    $positions += $index
}
for($i=1;$i -lt $positions.Count;$i++){
    if($positions[$i] -le $positions[$i-1]){throw 'Release workflow step ordering is unsafe.'}
}

if($release -notmatch 'git ls-remote origin'){throw 'Release workflow must verify the remote tag still resolves to the checked-out commit.'}
if($release -notmatch 'compare/\$sha\.\.\.main'){throw 'Release workflow must verify the tagged commit is on main.'}
if($release -notmatch 'merge_base_commit\.sha'){throw 'Release workflow must require the release commit to be the merge base with main.'}
if($release -notmatch 'gh run list.+--workflow validate\.yml.+--commit \$sha.+--event push'){throw 'Release workflow must wait for the exact main push validation run.'}
if($release -notmatch "conclusion -ne 'success'"){throw 'Release workflow must refuse publication when the main validation run did not succeed.'}

if($release -match 'gh release view'){throw 'Release workflow must not use a missing-release lookup that can exit nonzero under PowerShell Stop semantics.'}
if($release -notmatch 'gh release list.+--json tagName,isDraft'){throw 'Release workflow must use the known-supported release-list fields for preflight and draft reuse.'}
if($release -notmatch 'gh release create.+--verify-tag.+--draft'){throw 'Draft release creation must verify the remote tag and stay draft initially.'}
if($release -notmatch 'gh release upload'){throw 'Release asset upload step is missing.'}
if($release -notmatch 'gh release download.+--pattern ''\*\.zip''.+--pattern ''SHA256SUMS\.txt'''){throw 'Release workflow must download the uploaded draft assets for byte verification.'}
if($release -notmatch 'Get-FileHash'){throw 'Release workflow must hash uploaded assets before publication.'}
if($release -notmatch 'Uploaded release ZIP hash does not match the built ZIP'){throw 'Release workflow is missing uploaded ZIP equality enforcement.'}
if($release -notmatch 'Uploaded checksum manifest does not match the uploaded ZIP'){throw 'Release workflow is missing uploaded checksum-to-ZIP verification.'}
if($release -notmatch 'gh release edit.+--draft=false'){throw 'Release must be published only after the draft is fully verified.'}
if($release -notmatch 'dist/\*\.zip' -or $release -notmatch 'dist/SHA256SUMS\.txt'){throw 'Attestation subjects must include ZIP and checksum manifest.'}

Write-Host 'Release-workflow smoke passed: pinned actions, exact-commit/main CI gate, serialized tag runs, preflight-before-attestation, uploaded-byte verification, and publish-last ordering are stable.' -ForegroundColor Green
