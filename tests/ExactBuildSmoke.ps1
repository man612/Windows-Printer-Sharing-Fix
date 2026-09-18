$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before exact-build smoke.'}
$functions=@($ast.EndBlock.Statements | Where-Object {$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions | ForEach-Object {$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$script:BuildFixture='present'
function Get-ItemProperty {
    param([string]$Path)
    $null=$Path
    $props=[ordered]@{CurrentBuild='26100';ProductName='Windows 11 Pro';InstallationType='Client';DisplayVersion='24H2';ReleaseId='2009'}
    if($script:BuildFixture -eq 'present'){$props['UBR']=4061}
    elseif($script:BuildFixture -eq 'invalid'){$props['UBR']='not-a-number'}
    return [pscustomobject]$props
}

$present=Get-OsInfo
if($present.Build -ne 26100 -or $present.Revision -ne 4061 -or $present.FullBuild -ne '26100.4061'){throw 'UBR-present exact build normalization failed.'}

$script:BuildFixture='missing'
$missing=Get-OsInfo
if($missing.Build -ne 26100 -or $null -ne $missing.Revision -or $missing.FullBuild -ne '26100'){throw 'Missing UBR must fall back to the base build without inventing a revision.'}

$script:BuildFixture='invalid'
$invalid=Get-OsInfo
if($invalid.Build -ne 26100 -or $null -ne $invalid.Revision -or $invalid.FullBuild -ne '26100'){throw 'Invalid UBR must fall back to the base build without inventing a revision.'}

Write-Host 'Exact-build smoke passed: UBR present/missing/invalid normalization is conservative.' -ForegroundColor Green
