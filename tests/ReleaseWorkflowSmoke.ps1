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

foreach($permission in @('contents: write','id-token: write','attestations: write','artifact-metadata: write')){
    if($release -notmatch [regex]::Escape($permission)){throw "Release workflow missing permission: $permission"}
}

if($release -notmatch "tags:\s*\r?\n\s+- 'v\*'"){throw 'Stable release workflow must be triggered by v* tag pushes.'}
if($release -match 'types:\s*\[published\]'){throw 'Release workflow must not wait until after publication to build assets.'}
$labels=@(
    'Verify tag matches stable source version',
    'Validate reproducible packaging',
    'Build deterministic user package and checksum',
    'Generate build provenance attestation',
    'Create or reuse draft release',
    'Upload release assets to draft',
    'Publish release after assets and attestation are ready'
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

if($release -match 'gh release view'){throw 'Release workflow must not use a missing-release lookup that exits nonzero under PowerShell Stop semantics.'}
if($release -notmatch 'gh release list.+--json tagName,isDraft'){throw 'Release workflow must use a zero-exit release-list lookup before draft creation.'}
if($release -notmatch 'gh release create.+--verify-tag.+--draft'){throw 'Draft release creation must verify the tag and stay draft initially.'}
if($release -notmatch 'gh release upload'){throw 'Release asset upload step is missing.'}
if($release -notmatch 'gh release edit.+--draft=false'){throw 'Release must be published only after the draft is populated.'}
if($release -notmatch 'dist/\*\.zip' -or $release -notmatch 'dist/SHA256SUMS\.txt'){throw 'Attestation subjects must include ZIP and checksum manifest.'}

Write-Host 'Release-workflow smoke passed: pinned actions, provenance permissions, tag trigger, and draft-before-publish ordering are stable.' -ForegroundColor Green
