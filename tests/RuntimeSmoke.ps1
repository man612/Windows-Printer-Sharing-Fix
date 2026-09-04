$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
if (-not (Test-Path -LiteralPath $scriptFile)) { throw 'FixPrinter.ps1 is missing.' }

# Load function definitions without executing FixPrinter.ps1's interactive entry point.
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'FixPrinter.ps1 must parse before runtime smoke testing.' }

$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
if ($functions.Count -lt 20) { throw "Unexpectedly few v4 functions were discovered: $($functions.Count)" }
$functionSource = ($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"
. ([scriptblock]::Create($functionSource))

# Minimal script-scoped state required by the diagnostic functions.
$script:Version = '4.0.2-smoke'
$script:Language = 'EN'
$script:CurrentLog = Join-Path $env:TEMP ('windows-printer-fix-smoke-{0}.log' -f [Guid]::NewGuid().ToString('N'))
$script:LastDiagnostic = $null

function Get-ReadOnlyFingerprint {
    $registry = @(Get-ManagedRegistryEntries | Sort-Object Path,Name | ForEach-Object {
        [pscustomobject]@{Path=$_.Path;Name=$_.Name;Present=$_.Present;Value=$_.Value;Kind=$_.Kind}
    })
    $profiles = @(Get-NetworkProfilesSafe | Sort-Object InterfaceIndex | ForEach-Object {
        [pscustomobject]@{InterfaceIndex=$_.InterfaceIndex;NetworkCategory=[string]$_.NetworkCategory}
    })
    $firewall = @(Get-FirewallSharingRules | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{Name=$_.Name;Enabled=[string]$_.Enabled;Profile=[string]$_.Profile}
    })
    return [pscustomobject]@{
        Registry=$registry
        NetworkProfiles=$profiles
        FirewallRules=$firewall
        SMB1Client=(Get-WindowsFeatureState 'SMB1Protocol-Client')
    } | ConvertTo-Json -Depth 8 -Compress
}

$before = Get-ReadOnlyFingerprint
$diagnostic = Invoke-Diagnosis -Quiet
$after = Get-ReadOnlyFingerprint

if ($before -ne $after) {
    throw 'Diagnosis-only execution changed managed Windows state. Diagnose must remain read-only.'
}

if ($null -eq $diagnostic) { throw 'Invoke-Diagnosis returned no result.' }
if ($diagnostic.OS.Build -le 0) { throw "Invalid Windows build detected: $($diagnostic.OS.Build)" }
if (-not $diagnostic.OS.Name) { throw 'Windows name was not detected.' }
if (-not $diagnostic.Role) { throw 'Host/client role classification returned an empty value.' }
if ($null -eq $diagnostic.Findings) { throw 'Diagnostic findings collection is missing.' }
if ($null -eq $diagnostic.Printers) { throw 'Printer inventory collection is missing.' }
if ($null -eq $diagnostic.Profiles) { throw 'Network profile collection is missing.' }
if ($null -eq $diagnostic.WPP) { throw 'WPP state object is missing.' }

Write-Host ('Runtime smoke passed on {0} build {1}.' -f $diagnostic.OS.Name,$diagnostic.OS.Build) -ForegroundColor Green
Write-Host ('Spooler: {0}; printers: {1}; network profiles: {2}; findings: {3}.' -f $(if($diagnostic.Spooler){$diagnostic.Spooler.Status}else{'Missing'}),$diagnostic.Printers.Count,$diagnostic.Profiles.Count,$diagnostic.Findings.Count)
Write-Host 'Diagnosis-only state fingerprint was unchanged.' -ForegroundColor Green

Remove-Item -LiteralPath $script:CurrentLog -Force -ErrorAction SilentlyContinue
