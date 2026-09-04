$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'FixPrinter.ps1 must parse before localization smoke testing.' }

$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
$functionSource = ($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"
. ([scriptblock]::Create($functionSource))

$script:Version = '4.0.2-smoke'
$script:Language = 'ID'
$script:CurrentLog = Join-Path $env:TEMP 'windows-printer-fix-localization-smoke.log'
$script:Text = @{
    EN = @{Title='WINDOWS PRINTER SHARING FIX';Subtitle='Diagnosis-first repair utility';Guide='Guide';Press='Press Enter to continue'}
    ID = @{Title='WINDOWS PRINTER SHARING FIX';Subtitle='Utilitas diagnosis dan perbaikan printer sharing';Guide='Panduan';Press='Tekan Enter untuk lanjut'}
}

function Pause-Tui {}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true) { return $false }
$diagnostic = [pscustomobject]@{
    OS=[pscustomobject]@{Name='Windows 11';DisplayVersion='24H2';Build=26100}
    PowerShell='5.1';Role='Client';Spooler=[pscustomobject]@{Status='Running'}
    Printers=@();SharedPrinters=@();Connections=@();Profiles=@()
    WPP=[pscustomobject]@{Enabled=$false};SMB1Client='Disabled'
    Findings=@();PrintErrors=@()
}

$report = (& { Show-DiagnosticReport $diagnostic } 6>&1 | Out-String)
foreach($expected in @('LAPORAN DIAGNOSIS','Peran terdeteksi: Klien','Klien SMB1','Tidak aktif')) {
    if($report -notmatch [regex]::Escape($expected)){throw "Indonesian diagnostic output is missing: $expected"}
}
if($report -match 'Detected role|Shared printers:|Network profiles:'){throw 'English diagnostic labels leaked into Indonesian mode.'}

$guide = (& { Show-GuideMenu } 6>&1 | Out-String)
foreach($expected in @('Panduan','DIAGNOSIS DULU','PERBAIKAN AMAN UNTUK MASALAH UMUM','LEGACY ADALAH PILIHAN TERAKHIR')) {
    if($guide -notmatch [regex]::Escape($expected)){throw "Indonesian guide output is missing: $expected"}
}

Write-Host 'Localization smoke passed: Indonesian report and guide render without core English labels.' -ForegroundColor Green
Remove-Item -LiteralPath $script:CurrentLog -Force -ErrorAction SilentlyContinue
