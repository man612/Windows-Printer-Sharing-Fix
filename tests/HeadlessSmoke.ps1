$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$temp = Join-Path $env:TEMP ('wpsf-headless-' + [Guid]::NewGuid().ToString('N'))
$explicit = Join-Path $temp 'nested\diagnosis.json'
$dataRoot = Join-Path $temp 'data-root'
$oldDataRoot = $env:WPSF_DATA_ROOT

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptFile -DiagnoseOnly -Json $explicit 2>&1)
    $exitCode = $LASTEXITCODE
    if($exitCode -ne 0){throw "Explicit headless diagnosis failed with exit code ${exitCode}: $($output -join ' ')"}
    if(-not(Test-Path -LiteralPath $explicit)){throw 'Explicit headless JSON output was not created.'}
    if(($output -join "`n") -match 'MAIN MENU|MENU UTAMA|Select|Pilih'){throw 'Headless diagnosis entered the interactive TUI.'}

    $json = Get-Content -LiteralPath $explicit -Raw | ConvertFrom-Json
    if($json.Schema -ne 'windows-printer-sharing-fix/diagnosis' -or $json.SchemaVersion -ne 1 -or -not $json.Sanitized){throw 'Headless JSON did not reuse the structured sanitized diagnosis payload.'}
    if(-not $json.Windows.FullBuild){throw 'Headless JSON lost exact Windows build metadata.'}

    $env:WPSF_DATA_ROOT = $dataRoot
    $defaultOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptFile -DiagnoseOnly 2>&1)
    $defaultExit = $LASTEXITCODE
    if($defaultExit -ne 0){throw "Default headless diagnosis failed with exit code ${defaultExit}: $($defaultOutput -join ' ')"}
    $expected = Join-Path $dataRoot 'exports\diagnostic-headless.json'
    if(-not(Test-Path -LiteralPath $expected)){throw 'Default deterministic headless JSON path was not created.'}
    if(($defaultOutput -join "`n") -match 'MAIN MENU|MENU UTAMA|Select|Pilih'){throw 'Default headless diagnosis entered the interactive TUI.'}

    $previousErrorAction=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    $invalid = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptFile -Json (Join-Path $temp 'invalid.json') 2>&1)
    $invalidExit = $LASTEXITCODE
    $ErrorActionPreference=$previousErrorAction
    if($invalidExit -eq 0){throw '-Json without -DiagnoseOnly must fail.'}
    if(($invalid -join "`n") -match 'MAIN MENU|MENU UTAMA|Select|Pilih'){throw 'Invalid headless CLI usage fell into the interactive TUI.'}
    $global:LASTEXITCODE=0

    Write-Host 'Headless smoke passed: explicit/default JSON output, structured payload reuse, no-TUI behavior, and invalid-CLI exit are stable.' -ForegroundColor Green
}
finally {
    if($null -eq $oldDataRoot){Remove-Item Env:WPSF_DATA_ROOT -ErrorAction SilentlyContinue}else{$env:WPSF_DATA_ROOT=$oldDataRoot}
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
