#requires -version 5.1
[CmdletBinding()]
param(
    [string]$Version,
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist')
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $repo 'FixPrinter.ps1') -Raw
if (-not $Version) {
    $match = [regex]::Match($source, "\$script:Version\s*=\s*'([^']+)'", 'IgnoreCase')
    if (-not $match.Success) { throw 'Could not read version from FixPrinter.ps1.' }
    $Version = $match.Groups[1].Value
}
$cleanVersion = $Version.TrimStart('v')
$packageName = "Windows-Printer-Sharing-Fix-v$cleanVersion"
$stage = Join-Path $OutputDirectory $packageName
$zip = Join-Path $OutputDirectory ($packageName + '.zip')

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$rootFiles = @('FixPrinter.bat','FixPrinter.ps1','README.md','QUICKSTART.md','LICENSE','SECURITY.md','CHANGELOG.md','ROADMAP.md')
foreach ($name in $rootFiles) {
    $sourcePath = if ($name -eq 'QUICKSTART.md') { Join-Path $repo 'docs\QUICKSTART.md' } else { Join-Path $repo $name }
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Release source missing: $sourcePath" }
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $stage $name) -Force
}

$docsTarget = Join-Path $stage 'docs'
New-Item -ItemType Directory -Path $docsTarget -Force | Out-Null
foreach ($name in @('ARCHITECTURE.md','TEST-MATRIX.md','README.id.md')) {
    Copy-Item -LiteralPath (Join-Path $repo ('docs\' + $name)) -Destination (Join-Path $docsTarget $name) -Force
}

("Windows Printer Sharing Fix v{0}`r`n" -f $cleanVersion) | Set-Content -LiteralPath (Join-Path $stage 'VERSION.txt') -Encoding ASCII
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$sumLine = '{0}  {1}' -f $hash,(Split-Path -Leaf $zip)
$sumPath = Join-Path $OutputDirectory 'SHA256SUMS.txt'
$sumLine | Set-Content -LiteralPath $sumPath -Encoding ASCII

Write-Host "Package: $zip"
Write-Host "SHA256:  $hash"
Write-Host "Sums:    $sumPath"
