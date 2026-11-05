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

    foreach ($requiredPath in @('CONTRIBUTING.md','tools\Test-A1Readiness.ps1','tools\Collect-LabEvidence.ps1','docs\assets\hero-v2.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $requiredPath) -PathType Leaf)) {
            throw "Packaged README/runbook dependency missing: $requiredPath"
        }
    }

    # Every local Markdown/HTML link in the extracted user documentation must resolve offline.
    $packageRoot=([IO.Path]::GetFullPath($root)).TrimEnd([char]'\',[char]'/')
    $packagePrefix=$packageRoot+[IO.Path]::DirectorySeparatorChar
    $checkedLinks=0
    foreach($markdown in @(Get-ChildItem -LiteralPath $root -File -Filter '*.md' -Recurse)){
        $markdownText=Get-Content -LiteralPath $markdown.FullName -Raw
        foreach($pattern in @('\]\(([^)]+)\)','(?:href|src)="([^"]+)"')){
            foreach($match in [regex]::Matches($markdownText,$pattern)){
                $targetText=([string]$match.Groups[1].Value).Trim()
                if($targetText.StartsWith('<')){$targetText=$targetText.Trim('<','>')}
                $targetText=($targetText -split '\s+')[0]
                if($targetText -match '^(?:[a-z][a-z0-9+.-]*:|#|//|\\)' -or -not $targetText){continue}
                $relative=([Uri]::UnescapeDataString(($targetText -split '[#?]')[0])).Replace('/',[IO.Path]::DirectorySeparatorChar)
                if(-not $relative){continue}
                $target=([IO.Path]::GetFullPath((Join-Path $markdown.DirectoryName $relative)))
                if(-not $target.StartsWith($packagePrefix,[StringComparison]::OrdinalIgnoreCase) -and -not [string]::Equals($target,$packageRoot,[StringComparison]::OrdinalIgnoreCase)){
                    throw "Packaged document link escapes extracted ZIP root: $($markdown.Name) => $targetText"
                }
                if(-not(Test-Path -LiteralPath $target)){
                    throw "Broken offline link in packaged document: $($markdown.Name) => $targetText"
                }
                $checkedLinks++
            }
        }
    }
    if($checkedLinks -lt 10){throw 'Release documentation link scanner did not exercise enough local links.'}

    if (Test-Path -LiteralPath (Join-Path $root '.git')) { throw 'Release package must not contain .git metadata.' }
    if (Test-Path -LiteralPath (Join-Path $root 'tests')) { throw 'Release package should not include the repository test suite.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\REAL-WORLD-RESULTS.md'))) { throw 'Packaged real-world results ledger is missing.' }
    foreach ($requiredDoc in @('SAFE-REPAIR-PREVIEW.md','A1-LAB-RUNBOOK.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root ('docs\' + $requiredDoc)) -PathType Leaf)) {
            throw "Packaged linked runbook missing: $requiredDoc"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\DIAGNOSTIC-JSON.md'))) { throw 'Packaged diagnostic JSON schema documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\diagnosis.schema.json'))) { throw 'Packaged formal diagnosis JSON Schema is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\PRINTSERVICE-EVENTS.md'))) { throw 'Packaged PrintService event classification documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\POLICY-SOURCES.md'))) { throw 'Packaged printer policy source documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\CORRELATION.md'))) { throw 'Packaged next-layer correlation documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\MODERN-SMB-RPC.md'))) { throw 'Packaged modern SMB/RPC diagnostics documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\RELEASE-INTEGRITY.md'))) { throw 'Packaged release-integrity documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\DRIVER-CLASSIFICATION.md'))) { throw 'Packaged printer driver classification documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\WPP-READINESS.md'))) { throw 'Packaged WPP readiness documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\TEST-PAGE-VERIFICATION.md'))) { throw 'Packaged guided test-page verification documentation is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs\examples\README.md'))) { throw 'Packaged sanitized diagnosis examples are missing.' }

    $auto = Join-Path $temp 'auto-version'
    & $builder -OutputDirectory $auto | Out-Null
    $autoZip = Join-Path $auto 'Windows-Printer-Sharing-Fix-v4.2.1.zip'
    if (-not (Test-Path -LiteralPath $autoZip)) { throw 'Release builder failed to auto-detect stable version 4.2.1.' }

    Write-Host 'Package smoke passed: user ZIP/checksum are complete and auto-version detection works.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
