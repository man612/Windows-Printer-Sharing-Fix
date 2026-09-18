$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before Point and Print safety smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join ([Environment]::NewLine + [Environment]::NewLine)))

$temp = Join-Path $env:TEMP ('wpsf-pointprint-safety-' + [Guid]::NewGuid().ToString('N'))
$script:BackupRoot = Join-Path $temp 'backups'
$script:LatestStateFile = Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog = Join-Path $temp 'pointprint.log'
$script:Language = 'EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null

function L([string]$English,[string]$Indonesian){$English}
function Write-Warn([string]$Text){}
function Write-Fail([string]$Text){}
function Write-Ok([string]$Text){}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Get-RegistryValueState([string]$Path,[string]$Name){
    $null=@($Path,$Name)
    [pscustomobject]@{Present=$true;Value=1;Kind='DWord'}
}

function Reset-Harness {
    Remove-Item -LiteralPath $script:BackupRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
    $script:ReadCount=0
    $script:SetCount=0
    $script:RestoreCount=0
    $script:AddCount=0
    $script:FailAdd=$false
    $script:FailRollback=$false
}
function Read-Host([string]$Prompt){
    $null=$Prompt
    $script:ReadCount++
    if($script:ReadCount -eq 1){return '\\host\printer'}
    return 'RISK'
}
function New-RestoreSnapshot([string]$Reason,[string[]]$Scopes){
    $null=@($Reason,$Scopes)
    $dir=Join-Path $script:BackupRoot '20260918-120000-abcdef'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dir | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    return $dir
}
function Set-RegistryDword([string]$Path,[string]$Name,[int]$Value){
    $null=@($Path,$Name,$Value)
    $script:SetCount++
}
function Add-Printer{
    param([string]$ConnectionName)
    $null=$ConnectionName
    $script:AddCount++
    if($script:FailAdd){throw 'synthetic Add-Printer failure'}
}
function Restore-RegistryValue($Entry){
    $null=$Entry
    $script:RestoreCount++
    if($script:FailRollback){throw 'synthetic rollback failure'}
}

try {
    # Existing Restore history survives a successful temporary relaxation.
    Reset-Harness
    $previous=Join-Path $script:BackupRoot '20260917-110000-fedcba'
    New-Item -ItemType Directory -Path $previous -Force | Out-Null
    $previous | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    Connect-SharedPrinterTemporarilyRelaxed
    $latest=([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
    if($latest -ne $previous){throw 'Successful temporary Point and Print replaced existing Restore history.'}
    if(Test-Path -LiteralPath (Join-Path $script:BackupRoot '20260918-120000-abcdef')){throw 'Successful temporary Point and Print left its emergency snapshot behind.'}
    if($script:SetCount -ne 1 -or $script:RestoreCount -ne 1 -or $script:AddCount -ne 1){throw 'Successful Point and Print call counts are inconsistent.'}

    # With no previous history, success leaves no synthetic latest pointer.
    Reset-Harness
    Connect-SharedPrinterTemporarilyRelaxed
    if(Test-Path -LiteralPath $script:LatestStateFile){throw 'Successful temporary Point and Print created user-visible Restore history when none existed before.'}
    if(Test-Path -LiteralPath (Join-Path $script:BackupRoot '20260918-120000-abcdef')){throw 'Successful temporary Point and Print left an orphan emergency snapshot.'}

    # Connection failure still rolls protection back and restores previous history.
    Reset-Harness
    $previous=Join-Path $script:BackupRoot '20260917-110001-fedcba'
    New-Item -ItemType Directory -Path $previous -Force | Out-Null
    $previous | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    $script:FailAdd=$true
    Connect-SharedPrinterTemporarilyRelaxed
    $latest=([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
    if($latest -ne $previous){throw 'Failed connection attempt did not restore previous Restore history after successful rollback.'}
    if($script:RestoreCount -ne 1){throw 'Failed connection attempt did not execute rollback exactly once.'}

    # Rollback failure must retain the emergency snapshot as latest.
    Reset-Harness
    $previous=Join-Path $script:BackupRoot '20260917-110002-fedcba'
    New-Item -ItemType Directory -Path $previous -Force | Out-Null
    $previous | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    $script:FailRollback=$true
    Connect-SharedPrinterTemporarilyRelaxed
    $latest=([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
    $emergency=Join-Path $script:BackupRoot '20260918-120000-abcdef'
    if($latest -ne $emergency){throw 'Rollback failure did not retain the emergency snapshot as latest.'}
    if(-not(Test-Path -LiteralPath $emergency -PathType Container)){throw 'Rollback failure deleted the emergency snapshot.'}

    Write-Host 'Point-and-Print safety smoke passed: successful rollback preserves Restore history; failed rollback retains emergency recovery state.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}