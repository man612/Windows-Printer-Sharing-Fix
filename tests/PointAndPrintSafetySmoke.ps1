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
$script:OkMessages=@()
$script:FailMessages=@()
$script:InfoMessages=@()
function Write-Warn([string]$Text){}
function Write-Fail([string]$Text){$script:FailMessages += $Text}
function Write-Ok([string]$Text){$script:OkMessages += $Text}
function Write-Info([string]$Text){$script:InfoMessages += $Text}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Get-RegistryValueStateStrict([string]$Path,[string]$Name){
    $null=@($Path,$Name)
    $script:RegistryReadCount++
    [pscustomobject]@{Present=$true;Value=$script:RegistryValue;Kind='DWord'}
}

function Reset-Harness {
    Remove-Item -LiteralPath $script:BackupRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
    $script:ReadCount=0
    $script:SnapshotCount=0
    $script:RegistryValue=1
    $script:ChangeRegistryOnRisk=$false
    $script:RollbackValue=$null
    $script:RegistryReadCount=0
    $script:SetCount=0
    $script:RestoreCount=0
    $script:AddCount=0
    $script:FailAdd=$false
    $script:FailRollback=$false
    $script:AddChangesInventory=$true
    $script:PrinterInstalled=$false
    $script:OkMessages=@()
    $script:FailMessages=@()
    $script:InfoMessages=@()
}
function Read-Host([string]$Prompt){
    $null=$Prompt
    $script:ReadCount++
    if($script:ReadCount -eq 1){return '\\host\printer'}
    if($script:ChangeRegistryOnRisk){$script:RegistryValue=1}
    return 'RISK'
}
function New-RestoreSnapshot([string]$Reason,[string[]]$Scopes){
    $null=@($Reason,$Scopes)
    $script:SnapshotCount++
    $dir=Join-Path $script:BackupRoot '20260918-120000-abcdef'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dir | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    return $dir
}
function Set-RegistryDword([string]$Path,[string]$Name,[int]$Value){
    $null=@($Path,$Name)
    $script:SetCount++
    $script:RegistryValue=$Value
}
function Add-Printer{
    [CmdletBinding()] param([string]$ConnectionName)
    $null=$ConnectionName
    $script:AddCount++
    if($script:FailAdd){throw 'synthetic Add-Printer failure'}
    if($script:AddChangesInventory){$script:PrinterInstalled=$true}
}
function Get-PrinterInventory{
    if($script:PrinterInstalled){return @([pscustomobject]@{Name='\\host\printer';Type='Connection'})}
    return @()
}
function Restore-RegistryValue($Entry){
    $script:RestoreCount++
    if($script:FailRollback){throw 'synthetic rollback failure'}
    $script:RollbackValue=$Entry.Value
    $script:RegistryValue=[int]$Entry.Value
}

try {
    # An already-connected target must return before RISK confirmation, snapshot, or security relaxation.
    Reset-Harness
    $previous=Join-Path $script:BackupRoot '20260917-105959-fedcba'
    New-Item -ItemType Directory -Path $previous -Force | Out-Null
    $previous | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    $script:PrinterInstalled=$true
    Connect-SharedPrinterTemporarilyRelaxed
    $latest=([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
    if($latest -ne $previous){throw 'Already-connected Point and Print changed Restore history.'}
    if($script:ReadCount -ne 1){throw 'Already-connected Point and Print requested RISK confirmation unnecessarily.'}
    if($script:SnapshotCount -ne 0 -or $script:RegistryReadCount -ne 0 -or $script:SetCount -ne 0 -or $script:AddCount -ne 0 -or $script:RestoreCount -ne 0){throw 'Already-connected Point and Print touched snapshot, registry, connection, or rollback paths.'}
    if(($script:InfoMessages -join ' ') -notmatch 'already connected'){throw 'Already-connected Point and Print did not explain that protection was left unchanged.'}

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
    if(-not $script:PrinterInstalled){throw 'Successful Point and Print did not leave the connection in inventory.'}
    if(($script:OkMessages -join ' ') -notmatch 'Shared printer connection verified'){throw 'Successful Point and Print did not report verified connection.'}

    # Baseline must be captured after RISK confirmation so a change while the prompt is open is not overwritten by stale rollback.
    Reset-Harness
    $script:RegistryValue=0
    $script:ChangeRegistryOnRisk=$true
    Connect-SharedPrinterTemporarilyRelaxed
    if($script:RollbackValue -ne 1 -or $script:RegistryValue -ne 1){throw 'Point and Print rollback used a stale pre-confirmation registry baseline.'}

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

    # A successful/no-op Add-Printer command must fail connection verification but still roll protection back.
    Reset-Harness
    $previous=Join-Path $script:BackupRoot '20260917-110003-fedcba'
    New-Item -ItemType Directory -Path $previous -Force | Out-Null
    $previous | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    $script:AddChangesInventory=$false
    Connect-SharedPrinterTemporarilyRelaxed
    $latest=([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
    if($latest -ne $previous){throw 'Unverified connection did not restore previous Restore history after successful rollback.'}
    if($script:PrinterInstalled){throw 'No-op Add-Printer unexpectedly appeared in inventory.'}
    if(-not $script:FailMessages.Count){throw 'No-op Add-Printer did not produce a connection verification failure.'}
    if(($script:OkMessages -join ' ') -match 'Shared printer connection verified'){throw 'No-op Add-Printer produced false connection success.'}

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