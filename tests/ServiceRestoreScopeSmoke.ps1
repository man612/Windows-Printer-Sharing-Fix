$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before service-restore-scope smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$temp=Join-Path $env:TEMP ('wpsf-service-restore-'+[Guid]::NewGuid().ToString('N'))
$script:BackupRoot=Join-Path $temp 'backups'
$script:LatestStateFile=Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog=Join-Path $temp 'service-restore.log'
$script:Version='4.2.0'
$script:Language='EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null

function L([string]$English,[string]$Indonesian){$English}
$script:Ok=@();$script:Fail=@();$script:Warn=@()
function Write-Header([string]$Text){}
function Write-Ok([string]$Text){$script:Ok+=$Text}
function Write-Fail([string]$Text){$script:Fail+=$Text}
function Write-Warn([string]$Text){$script:Warn+=$Text}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){$null=@($Message,$Level)}
function Pause-Tui{}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){$null=@($Prompt,$DefaultNo);$true}
function Get-ManagedRegistryEntries([switch]$Strict){$null=$Strict;@()}
function Get-NetworkProfilesSafe{@()}
function Get-FirewallSharingRules{@()}
function Get-WindowsFeatureState([string]$Name){$null=$Name;'Disabled'}
function Get-CimInstance{
  param([string]$ClassName,[string]$Filter)
  $null=$ClassName
  $name=([regex]::Match($Filter,"Name='([^']+)'")).Groups[1].Value
  [pscustomobject]@{Name=$name;State='Running';StartMode='Disabled'}
}

try{
  # New service snapshots capture only state the repair can actually change.
  $dir=New-RestoreSnapshot 'Restart Print Spooler' @('Services')
  if(-not $dir){throw 'Runtime-only service snapshot creation failed.'}
  $state=Get-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Raw|ConvertFrom-Json
  if(@($state.Services).Count -ne 1 -or [string]$state.Services[0].Name -ne 'Spooler'){throw 'Restart Spooler snapshot did not contain exactly Spooler.'}
  if('StartMode' -in @($state.Services[0].PSObject.Properties.Name)){throw 'New service snapshot still captures unrelated startup mode.'}
  if([string]$state.Services[0].State -ne 'Running'){throw 'New service snapshot did not capture runtime state.'}

  # Legacy v4 snapshots may still contain StartMode and must remain readable.
  $legacyDir=Join-Path $script:BackupRoot '20260919-103000-abcdef'
  New-Item -ItemType Directory -Path $legacyDir -Force|Out-Null
  $legacy=[pscustomobject]@{
    Version='4.1.0';Created='2026-09-19T03:30:00Z';Reason='Restart Print Spooler';Scopes=@('Services');
    Registry=@();Services=@([pscustomobject]@{Name='Spooler';State='Running';StartMode='Disabled'});
    NetworkProfiles=@();FirewallRules=@();WindowsFeatures=@()
  }
  $legacy|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $legacyDir 'managed-state.json') -Encoding UTF8
  [void](Get-ValidatedRestoreSnapshot $legacyDir)

  # Restore the runtime state from that legacy snapshot, but never mutate StartupType.
  $script:SetServiceCalls=0;$script:StartCalls=0;$script:StopCalls=0;$script:ServiceStatus='Stopped'
  function Set-Service{
    [CmdletBinding()] param([string]$Name,[string]$StartupType)
    $null=@($Name,$StartupType);$script:SetServiceCalls++
  }
  function Start-Service{
    [CmdletBinding()] param([string]$Name)
    $null=$Name;$script:StartCalls++;$script:ServiceStatus='Running'
  }
  function Stop-Service{
    [CmdletBinding()] param([string]$Name,[switch]$Force)
    $null=@($Name,$Force);$script:StopCalls++;$script:ServiceStatus='Stopped'
  }
  function Get-Service{
    [CmdletBinding()] param([string]$Name)
    [pscustomobject]@{Name=$Name;Status=$script:ServiceStatus}
  }
  $legacyDir|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
  $script:Ok=@();$script:Fail=@()
  Invoke-RestoreLatest
  if($script:SetServiceCalls -ne 0){throw 'Restore mutated service StartupType even though the repair never manages it.'}
  if($script:StartCalls -ne 1 -or $script:StopCalls -ne 0 -or $script:ServiceStatus -ne 'Running'){throw 'Legacy service snapshot did not restore runtime state correctly.'}
  if($script:Ok.Count -ne 1 -or $script:Fail.Count){throw 'Runtime-only legacy service Restore did not report clean success.'}

  Write-Host 'Service-restore-scope smoke passed: new snapshots omit StartupType and legacy snapshots restore runtime state without Set-Service.' -ForegroundColor Green
}finally{
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}