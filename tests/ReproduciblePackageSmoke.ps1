$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$temp = Join-Path $env:TEMP ('wpsf-repro-package-' + [Guid]::NewGuid().ToString('N'))
$copyA = Join-Path $temp 'copy-a'
$copyB = Join-Path $temp 'copy-b'
$outA = Join-Path $temp 'out-a'
$outB = Join-Path $temp 'out-b'
New-Item -ItemType Directory -Path $copyA,$copyB -Force | Out-Null

function Copy-RepoForPackageTest([string]$Destination) {
    foreach($item in @(Get-ChildItem -LiteralPath $repo -Force | Where-Object {$_.Name -notin @('.git','dist')})) {
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

try {
    Copy-RepoForPackageTest $copyA
    Copy-RepoForPackageTest $copyB

    $timeA=[datetime]'2001-01-01T00:00:00Z'
    $timeB=[datetime]'2025-06-01T12:34:56Z'
    Get-ChildItem -LiteralPath $copyA -Recurse -File | ForEach-Object {$_.LastWriteTimeUtc=$timeA}
    Get-ChildItem -LiteralPath $copyB -Recurse -File | ForEach-Object {$_.LastWriteTimeUtc=$timeB}
    $builderA=Join-Path $copyA 'tools\Build-Release.ps1'
    $builderB=Join-Path $copyB 'tools\Build-Release.ps1'
    & $builderA -Version '0.0.0-repro' -OutputDirectory $outA | Out-Null
    & $builderB -Version '0.0.0-repro' -OutputDirectory $outB | Out-Null

    $zipA=Join-Path $outA 'Windows-Printer-Sharing-Fix-v0.0.0-repro.zip'
    $zipB=Join-Path $outB 'Windows-Printer-Sharing-Fix-v0.0.0-repro.zip'
    $hashA=(Get-FileHash -LiteralPath $zipA -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashB=(Get-FileHash -LiteralPath $zipB -Algorithm SHA256).Hash.ToLowerInvariant()
    if($hashA -ne $hashB){throw "Release ZIP is not reproducible across source mtimes: $hashA != $hashB"}

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($zipA)
    try {
        $names=@($archive.Entries | ForEach-Object {$_.FullName})
        $sorted=[string[]]@($names)
        [Array]::Sort($sorted,[StringComparer]::Ordinal)
        if(($names -join "`n") -ne ($sorted -join "`n")){throw 'Release ZIP entries are not in canonical ordinal order.'}

        foreach($entry in @($archive.Entries)){
            $stamp=$entry.LastWriteTime
            if($stamp.Year -ne 2000 -or $stamp.Month -ne 1 -or $stamp.Day -ne 1 -or $stamp.Hour -ne 0 -or $stamp.Minute -ne 0 -or $stamp.Second -ne 0){throw "ZIP timestamp is not normalized: $($entry.FullName)"}
        }
    } finally {
        $archive.Dispose()
    }

    $sumA=(Get-Content -LiteralPath (Join-Path $outA 'SHA256SUMS.txt') -Raw).Trim()
    $sumB=(Get-Content -LiteralPath (Join-Path $outB 'SHA256SUMS.txt') -Raw).Trim()
    if($sumA -ne $sumB){throw 'Checksum manifest is not reproducible.'}
    if($sumA -notmatch [regex]::Escape($hashA)){throw 'Checksum manifest does not contain the reproducible ZIP hash.'}

    Write-Host ("Reproducible package smoke passed: SHA256={0}" -f $hashA) -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
