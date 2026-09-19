$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before legacy no-op smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$script:Language='EN'
$script:SnapshotCalls=0
$script:SetCalls=@()
$script:ReadQueue=@()
$script:Role='Client'
$script:RegistryState=@{}
$script:FeatureState='Disabled'
$script:FeatureEnableCalls=0
$script:Info=@()
$script:Warn=@()
$script:Fail=@()

function L([string]$English,[string]$Indonesian){$English}
function Write-Header([string]$Text){}
function Write-Info([string]$Text){$script:Info+=$Text}
function Write-Warn([string]$Text){$script:Warn+=$Text}
function Write-Fail([string]$Text){$script:Fail+=$Text}
function Write-Ok([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Read-Host([string]$Prompt){$null=$Prompt;if(-not $script:ReadQueue.Count){throw 'Read queue exhausted.'};$value=[string]$script:ReadQueue[0];$script:ReadQueue=@($script:ReadQueue|Select-Object -Skip 1);$value}
function Invoke-Diagnosis{param([switch]$Quiet);$null=$Quiet;[pscustomobject]@{Role=$script:Role}}
function New-RestoreSnapshot{param([string]$Reason,[string[]]$Scopes,[string[]]$RegistryNames);$null=@($Reason,$Scopes,$RegistryNames);$script:SnapshotCalls++;'snap'}
function Get-RegistryValueStateStrict([string]$Path,[string]$Name){
    $null=$Path
    if($script:RegistryState.ContainsKey($Name)){return $script:RegistryState[$Name]}
    [pscustomobject]@{Present=$false;Value=$null;Kind=$null}
}
function Set-RegistryDword([string]$Path,[string]$Name,[int]$Value){$null=$Path;$script:SetCalls += ($Name+'='+$Value);$script:RegistryState[$Name]=[pscustomobject]@{Present=$true;Value=$Value;Kind='DWord'}}
function Get-WindowsFeatureState([string]$Name){$null=$Name;$script:FeatureState}
function Enable-WindowsOptionalFeature{[CmdletBinding()]param([switch]$Online,[string]$FeatureName,[switch]$NoRestart);$null=@($Online,$FeatureName,$NoRestart);$script:FeatureEnableCalls++;$script:FeatureState='Enabled'}

function Reset-Harness{
    $script:SnapshotCalls=0
    $script:SetCalls=@()
    $script:ReadQueue=@()
    $script:Role='Client'
    $script:RegistryState=@{}
    $script:FeatureState='Disabled'
    $script:FeatureEnableCalls=0
    $script:Info=@()
    $script:Warn=@()
    $script:Fail=@()
}

# RPC privacy already target -> no snapshot/mutation.
Reset-Harness
$script:RegistryState['RpcAuthnLevelPrivacyEnabled']=[pscustomobject]@{Present=$true;Value=0;Kind='DWord'}
$script:ReadQueue=@('RISK')
Set-RpcPrivacyCompatibility
if($script:SnapshotCalls -ne 0 -or $script:SetCalls.Count){throw 'Already-disabled RPC privacy created a snapshot or mutation.'}

# Insecure guest already target -> no snapshot/mutation.
Reset-Harness
$script:RegistryState['AllowInsecureGuestAuth']=[pscustomobject]@{Present=$true;Value=1;Kind='DWord'}
$script:ReadQueue=@('LEGACY')
Enable-InsecureGuestLegacy
if($script:SnapshotCalls -ne 0 -or $script:SetCalls.Count){throw 'Already-enabled insecure guest auth created a snapshot or mutation.'}

# LM compatibility already target -> no snapshot/mutation.
Reset-Harness
$script:RegistryState['LmCompatibilityLevel']=[pscustomobject]@{Present=$true;Value=1;Kind='DWord'}
$script:ReadQueue=@('LEGACY')
Set-LegacyLmCompatibility
if($script:SnapshotCalls -ne 0 -or $script:SetCalls.Count){throw 'Already-applied LM compatibility created a snapshot or mutation.'}

# SMB1 already Enabled -> no snapshot/feature call.
Reset-Harness
$script:FeatureState='Enabled'
$script:ReadQueue=@('LEGACY')
Enable-Smb1ClientLegacy
if($script:SnapshotCalls -ne 0 -or $script:FeatureEnableCalls -ne 0){throw 'Already-enabled SMB1 created a snapshot or feature mutation.'}

# SMB1 Unknown -> abort before snapshot/mutation.
Reset-Harness
$script:FeatureState='Unknown'
$script:ReadQueue=@('LEGACY')
Enable-Smb1ClientLegacy
if($script:SnapshotCalls -ne 0 -or $script:FeatureEnableCalls -ne 0){throw 'Unknown SMB1 baseline was mutated or snapshotted.'}
if(-not $script:Fail.Count){throw 'Unknown SMB1 baseline did not emit a failure.'}

# RPC Named Pipes Client already configured -> no snapshot/mutation.
Reset-Harness
$script:Role='Client'
$script:RegistryState['RpcUseNamedPipeProtocol']=[pscustomobject]@{Present=$true;Value=1;Kind='DWord'}
Set-RpcNamedPipeFallback
if($script:SnapshotCalls -ne 0 -or $script:SetCalls.Count){throw 'Already-configured Client Named Pipes created a snapshot or mutation.'}

# RPC Named Pipes Unknown/local with one target already correct -> snapshot/mutate only the remaining target.
Reset-Harness
$script:Role='Unknown / local only'
$script:RegistryState['RpcUseNamedPipeProtocol']=[pscustomobject]@{Present=$true;Value=1;Kind='DWord'}
$script:RegistryState['RpcProtocols']=[pscustomobject]@{Present=$true;Value=0;Kind='DWord'}
$script:CapturedRegistryNames=@()
function New-RestoreSnapshot{param([string]$Reason,[string[]]$Scopes,[string[]]$RegistryNames);$null=@($Reason,$Scopes);$script:SnapshotCalls++;$script:CapturedRegistryNames=@($RegistryNames);'snap'}
Set-RpcNamedPipeFallback
if($script:SnapshotCalls -ne 1){throw 'Partially configured Named Pipes did not create exactly one snapshot.'}
if(($script:CapturedRegistryNames -join ',') -ne 'RpcProtocols'){throw 'Named Pipes snapshot included a target already at desired state.'}
if(($script:SetCalls -join ',') -ne 'RpcProtocols=7'){throw 'Named Pipes mutation set did not match the remaining target.'}

Write-Host 'Legacy no-op smoke passed: already-satisfied legacy/high-risk actions preserve Restore history, and unknown SMB1 baseline is rejected.' -ForegroundColor Green