#requires -version 5.1
[CmdletBinding()]
param(
    [string]$Version,
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $repo 'FixPrinter.ps1') -Raw
if (-not $Version) {
    $pattern = '\$script:Version\s*=\s*''([^'']+)'''
    $match = [regex]::Match($source, $pattern, 'IgnoreCase')
    if (-not $match.Success) { throw 'Could not read version from FixPrinter.ps1.' }
    $Version = $match.Groups[1].Value
}

$cleanVersion = $Version.TrimStart('v')
$packageName = "Windows-Printer-Sharing-Fix-v$cleanVersion"
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path (Get-Location).Path $OutputDirectory }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$zip = Join-Path $OutputDirectory ($packageName + '.zip')
$sumPath = Join-Path $OutputDirectory 'SHA256SUMS.txt'
foreach ($old in @($zip,$sumPath)) {
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
}

$releaseSources = @{}
function Add-ReleaseSource([string]$RelativePath,[string]$SourcePath) {
    $relative = $RelativePath.Replace('\','/')
    if ($releaseSources.ContainsKey($relative)) { throw "Duplicate release path: $relative" }
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw "Release source missing: $SourcePath" }
    $script:releaseSources[$relative] = $SourcePath
}

$rootFiles = @('FixPrinter.bat','FixPrinter.ps1','README.md','QUICKSTART.md','LICENSE','SECURITY.md','CHANGELOG.md','ROADMAP.md')
foreach ($name in $rootFiles) {
    $sourcePath = if ($name -eq 'QUICKSTART.md') { Join-Path $repo 'docs\QUICKSTART.md' } else { Join-Path $repo $name }
    Add-ReleaseSource $name $sourcePath
}

$docs = @(
    'ARCHITECTURE.md','DIAGNOSTIC-JSON.md','diagnosis.schema.json','PRINTSERVICE-EVENTS.md','POLICY-SOURCES.md',
    'DRIVER-CLASSIFICATION.md','WPP-READINESS.md','CORRELATION.md','MODERN-SMB-RPC.md','RELEASE-INTEGRITY.md','TEST-PAGE-VERIFICATION.md',
    'TEST-MATRIX.md','REAL-WORLD-RESULTS.md','README.id.md'
)
foreach ($name in $docs) {
    Add-ReleaseSource ('docs/' + $name) (Join-Path $repo ('docs\' + $name))
}

$examplesSource = Join-Path $repo 'docs\examples'
foreach ($file in @(Get-ChildItem -LiteralPath $examplesSource -File -Recurse)) {
    $suffix = $file.FullName.Substring($examplesSource.Length).TrimStart([char]'\',[char]'/')
    Add-ReleaseSource ('docs/examples/' + $suffix.Replace('\','/')) $file.FullName
}

$virtualEntries = @{
    'VERSION.txt' = [Text.Encoding]::ASCII.GetBytes(("Windows Printer Sharing Fix v{0}`r`n" -f $cleanVersion))
}

[string[]]$relativePaths = @($releaseSources.Keys + $virtualEntries.Keys | ForEach-Object { [string]$_ })
[Array]::Sort($relativePaths,[StringComparer]::Ordinal)

$fixedTimestamp = [DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
$fileStream = $null
$archive = $null
try {
    $fileStream = [IO.File]::Open($zip,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $archive = [IO.Compression.ZipArchive]::new($fileStream,[IO.Compression.ZipArchiveMode]::Create,$false)
    foreach ($relative in $relativePaths) {
        $entryName = $packageName + '/' + $relative
        $entry = $archive.CreateEntry($entryName,[IO.Compression.CompressionLevel]::NoCompression)
        $entry.LastWriteTime = $fixedTimestamp
        $entry.ExternalAttributes = 0
        $entryStream = $entry.Open()
        try {
            $bytes = if ($virtualEntries.ContainsKey($relative)) {
                [byte[]]$virtualEntries[$relative]
            } else {
                [IO.File]::ReadAllBytes([string]$releaseSources[$relative])
            }
            $entryStream.Write($bytes,0,$bytes.Length)
        } finally {
            $entryStream.Dispose()
        }
    }
} finally {
    if ($archive) { $archive.Dispose() }
    if ($fileStream) { $fileStream.Dispose() }
}

$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$sumLine = '{0}  {1}' -f $hash,(Split-Path -Leaf $zip)
[IO.File]::WriteAllText($sumPath,$sumLine + "`r`n",[Text.Encoding]::ASCII)

Write-Host "Package: $zip"
Write-Host "SHA256:  $hash"
Write-Host "Sums:    $sumPath"
