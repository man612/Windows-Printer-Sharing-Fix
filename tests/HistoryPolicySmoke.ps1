$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=Split-Path -Parent $PSScriptRoot
$source=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'FixPrinter.ps1 parse failed.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))
$script:Language='EN'
function L([string]$English,[string]$Indonesian){$English}
function T([string]$Key){$Key}
function Write-Header([string]$Section=''){}
function Write-Warn([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Pause-Tui{}
function Read-Choice([string]$Prompt,[string[]]$Allowed){'2'}
$script:SelectedDirectory=''
function Invoke-RestoreLatest([string]$SnapshotDirectory=''){$script:SelectedDirectory=$SnapshotDirectory}
$temp=Join-Path $env:TEMP ('wpsf-history-'+[guid]::NewGuid().ToString('N'))
$script:BackupRoot=Join-Path $temp 'backups'
New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null
try{
    $one=Join-Path $script:BackupRoot '20261104-100000-aaaaaa'
    $two=Join-Path $script:BackupRoot '20261104-110000-bbbbbb'
    $invalid=Join-Path $script:BackupRoot 'invalid'
    foreach($dir in @($one,$two,$invalid)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    function Get-ValidatedRestoreSnapshot([string]$Directory){
        if($Directory -like '*invalid'){throw 'synthetic invalid snapshot'}
        [pscustomobject]@{Directory=$Directory;State=[pscustomobject]@{Reason='Synthetic action';Created='2026-11-04T10:00:00Z'}}
    }
    Invoke-RestoreHistory
    if((Split-Path -Leaf $script:SelectedDirectory) -ne (Split-Path -Leaf $one)){throw ("History selected unexpected snapshot: actual='{0}' expected='{1}'" -f $script:SelectedDirectory,$one)}
    $script:PolicyEvidence=[pscustomobject]@{Available=$true;Settings=@(
        [pscustomobject]@{RegistryKey='Software\Policies\Microsoft\Windows NT\Printers\RPC';ValueName='RpcUseNamedPipeProtocol';GpoId='{SYNTHETIC-GPO}';SomId='LDAP://synthetic';Precedence=1;Deleted=$false}
    )}
    function Get-ComputerRsopRegistryPolicySettings {$script:PolicyEvidence}
    $blocked=$false
    try{Assert-PrinterPolicyNotManaged 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol'}catch{$blocked=$true}
    if(-not $blocked){throw 'Confirmed Group Policy-managed printer setting was not blocked.'}
    $script:PolicyEvidence.Available=$false
    Assert-PrinterPolicyNotManaged 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol'
    Write-Host 'Restore history and policy guard smoke passed.' -ForegroundColor Green
}finally{Microsoft.PowerShell.Management\Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
