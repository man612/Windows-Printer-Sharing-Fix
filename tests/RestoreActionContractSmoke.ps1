$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before restore-action-contract smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$temp=Join-Path $env:TEMP ('wpsf-action-contract-'+[Guid]::NewGuid().ToString('N'))
$script:BackupRoot=Join-Path $temp 'backups'
$script:LatestStateFile=Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog=Join-Path $temp 'contract.log'
$script:Version='4.2.0'
$script:Language='EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null

function L([string]$English,[string]$Indonesian){$English}
function Write-Fail([string]$Text){}
function Write-Warn([string]$Text){}
function Write-Ok([string]$Text){}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){$null=@($Message,$Level)}
function Get-NetworkProfilesSafe{@()}
function Get-FirewallSharingRules{@()}
function Get-WindowsFeatureState([string]$Name){$null=$Name;'Disabled'}

function Get-ManagedRegistryEntries([switch]$Strict){
    $null=$Strict
    @(
      [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC';Name='RpcUseNamedPipeProtocol';Present=$true;Value=0;Kind='DWord'},
      [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC';Name='RpcProtocols';Present=$true;Value=0;Kind='DWord'},
      [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Print';Name='RpcAuthnLevelPrivacyEnabled';Present=$true;Value=1;Kind='DWord'},
      [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='LmCompatibilityLevel';Present=$true;Value=3;Kind='DWord'}
    )
}

$script:Role='Client'
$script:Mutated=@()
function Invoke-Diagnosis{param([switch]$Quiet);$null=$Quiet;[pscustomobject]@{Role=$script:Role}}
function Set-RegistryDword([string]$Path,[string]$Name,[int]$Value){$null=@($Path,$Value);$script:Mutated+=$Name}

function Read-StateFromLatest {
    $dir=([string](Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1)).Trim()
    [pscustomobject]@{Directory=$dir;State=(Get-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Raw|ConvertFrom-Json)}
}
function Assert-ExactNames([object[]]$Items,[string[]]$Expected,[string]$Label){
    $actual=@($Items|ForEach-Object{[string]$_.Name}|Sort-Object)
    $wanted=@($Expected|Sort-Object)
    if(($actual -join '|') -ne ($wanted -join '|')){throw "$Label mismatch. Actual=$($actual -join ',') Expected=$($wanted -join ',')"}
}

try{
    # Client role: snapshot and mutation must contain only client target.
    $script:Role='Client';$script:Mutated=@()
    Set-RpcNamedPipeFallback
    $client=Read-StateFromLatest
    Assert-ExactNames @($client.State.Registry) @('RpcUseNamedPipeProtocol') 'Client RPC snapshot'
    $clientMutated=@($script:Mutated|Sort-Object)
    if(($clientMutated -join '|') -ne 'RpcUseNamedPipeProtocol'){throw 'Client RPC fallback mutated state outside the client contract.'}
    [void](Get-ValidatedRestoreSnapshot $client.Directory)

    # Host role: snapshot and mutation must contain only host target.
    $script:Role='Host';$script:Mutated=@()
    Set-RpcNamedPipeFallback
    $hostCase=Read-StateFromLatest
    Assert-ExactNames @($hostCase.State.Registry) @('RpcProtocols') 'Host RPC snapshot'
    $hostMutated=@($script:Mutated|Sort-Object)
    if(($hostMutated -join '|') -ne 'RpcProtocols'){throw 'Host RPC fallback mutated state outside the host contract.'}
    [void](Get-ValidatedRestoreSnapshot $hostCase.Directory)

    # Unknown/local role: both managed targets are captured and changed.
    $script:Role='Unknown / local only';$script:Mutated=@()
    Set-RpcNamedPipeFallback
    $both=Read-StateFromLatest
    Assert-ExactNames @($both.State.Registry) @('RpcProtocols','RpcUseNamedPipeProtocol') 'Unknown/local RPC snapshot'
    $bothMutated=@($script:Mutated|Sort-Object)
    if(($bothMutated -join '|') -ne 'RpcProtocols|RpcUseNamedPipeProtocol'){throw 'Unknown/local RPC fallback did not mutate exactly both contract targets.'}
    [void](Get-ValidatedRestoreSnapshot $both.Directory)

    # A managed registry target from another action must be rejected.
    $wrongDir=Join-Path $script:BackupRoot '20260919-102700-abcdef'
    New-Item -ItemType Directory -Path $wrongDir -Force|Out-Null
    $wrong=[pscustomobject]@{
      Version='4.2.0';Created='2026-09-19T03:27:00Z';Reason='High-risk RPC privacy workaround';Scopes=@('Registry');
      Registry=@([pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='LmCompatibilityLevel';Present=$true;Value=3;Kind='DWord'});
      Services=@();NetworkProfiles=@();FirewallRules=@();WindowsFeatures=@()
    }
    $wrong|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $wrongDir 'managed-state.json') -Encoding UTF8
    $accepted=$false
    try{[void](Get-ValidatedRestoreSnapshot $wrongDir);$accepted=$true}catch{$accepted=$false}
    if($accepted){throw 'Validator accepted a managed registry target that belongs to a different action contract.'}

    # The same target under its correct action remains valid.
    $rightDir=Join-Path $script:BackupRoot '20260919-102701-abcdef'
    New-Item -ItemType Directory -Path $rightDir -Force|Out-Null
    $right=[pscustomobject]@{
      Version='4.2.0';Created='2026-09-19T03:27:01Z';Reason='Legacy LAN Manager level';Scopes=@('Registry');
      Registry=@([pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='LmCompatibilityLevel';Present=$true;Value=3;Kind='DWord'});
      Services=@();NetworkProfiles=@();FirewallRules=@();WindowsFeatures=@()
    }
    $right|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $rightDir 'managed-state.json') -Encoding UTF8
    [void](Get-ValidatedRestoreSnapshot $rightDir)

    Write-Host 'Restore-action-contract smoke passed: RPC role snapshots match actual mutation scope and cross-action managed targets are rejected.' -ForegroundColor Green
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}