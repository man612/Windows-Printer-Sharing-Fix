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
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\REAL-WORLD-RESULTS.md'))) { throw 'Packaged real-world results ledger is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\DIAGNOSTIC-JSON.md'))) { throw 'Packaged diagnostic JSON schema documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\PRINTSERVICE-EVENTS.md'))) { throw 'Packaged PrintService event classification documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\POLICY-SOURCES.md'))) { throw 'Packaged printer policy source documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\CORRELATION.md'))) { throw 'Packaged next-layer correlation documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\DRIVER-CLASSIFICATION.md'))) { throw 'Packaged printer driver classification documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\TEST-PAGE-VERIFICATION.md'))) { throw 'Packaged guided test-page verification documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\examples\README.md'))) { throw 'Packaged sanitized diagnosis examples are missing.' }

    $auto = Join-Path $temp 'auto-version'
    & $builder -OutputDirectory $auto | Out-Null
    $autoZip = Join-Path $auto 'Windows-Printer-Sharing-Fix-v4.1.0.zip'
    if (-not (Test-Path -LiteralPath $autoZip)) { throw 'Release builder failed to auto-detect stable version 4.1.0.' }

    Write-Host 'Package smoke passed: user ZIP/checksum are complete and auto-version detection works.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
