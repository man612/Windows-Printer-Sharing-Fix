$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $repo 'tools\Build-Release.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'Release builder is missing.' }

$temp = Join-Path $env:TEMP ('wpsf-package-smoke-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    & $builder -Version '0.0.0-test' -OutputDirectory $temp | Out-Null
    $zip = Join-Path $temp 'Windows-Printer-Sharing-Fix-v0.0.0-test.zip'
    $sums = Join-Path $temp 'SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $zip)) { throw 'Release ZIP was not created.' }
    if (-not (Test-Path -LiteralPath $sums)) { throw 'SHA256SUMS.txt was not created.' }

    $expectedHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumText = (Get-Content -LiteralPath $sums -Raw).Trim()
    if ($sumText -notmatch [regex]::Escape($expectedHash)) { throw 'Release checksum does not match the generated ZIP.' }

    $expanded = Join-Path $temp 'expanded'
    Expand-Archive -LiteralPath $zip -DestinationPath $expanded
    $root = Join-Path $expanded 'Windows-Printer-Sharing-Fix-v0.0.0-test'
    foreach ($file in @('FixPrinter.bat','FixPrinter.ps1','QUICKSTART.md','README.md','LICENSE','VERSION.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { throw "Packaged file missing: $file" }
    }

    if (Test-Path -LiteralPath (Join-Path $root '.git')) { throw 'Release package must not contain .git metadata.' }
    if (Test-Path -LiteralPath (Join-Path $root 'tests')) { throw 'Release package should not include the repository test suite.' }

    Write-Host 'Package smoke passed: user ZIP and SHA256 checksum are complete.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
