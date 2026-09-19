$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before combined Safe Repair scope smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$temp=Join-Path $env:TEMP ('wpsf-combined-scope-'+[Guid]::NewGuid().ToString('N'))
$script:BackupRoot=Join-Path $temp 'backups'
$script:LatestStateFile=Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog=Join-Path $temp 'combined.log'
$script:Version='4.2.0'
$script:Language='EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null

$script:ChoiceQueue=@()
$script:ServiceStates=@{}
$script:FirewallFixture=@()
$script:FirewallRepairNames=@()
$script:RestartCalls=0
$script:DiscoveryCalls=0
$script:FailMessages=@()
$script:FailRestart=$false
$script:FailFirewall=$false
$script:FailDiscovery=$false

function L([string]$English,[string]$Indonesian){$English}
function T([string]$Key){$Key}
function Write-Header([string]$Text){}
function Write-Rule{}
function Write-Info([string]$Text){}
function Write-Warn([string]$Text){}
function Write-Fail([string]$Text){$script:FailMessages+=$Text}
function Write-Ok([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Pause-Tui{}
function Write-Host{param([Parameter(ValueFromRemainingArguments=$true)]$Object);$null=$Object}
function Read-Choice([string]$Prompt,[string[]]$Allowed){
    $null=@($Prompt,$Allowed)
    if(-not $script:ChoiceQueue.Count){throw 'Choice queue exhausted.'}
    $value=[string]$script:ChoiceQueue[0]
    $script:ChoiceQueue=@($script:ChoiceQueue|Select-Object -Skip 1)
    return $value
}

function Get-Service{
    [CmdletBinding()]param([string]$Name)
    if(-not $script:ServiceStates.ContainsKey($Name)){throw "Unknown service: $Name"}
    [pscustomobject]@{Name=$Name;Status=$script:ServiceStates[$Name]}
}
function Get-CimInstance{
    param([string]$ClassName,[string]$Filter)
    $null=$ClassName
    $name=([regex]::Match($Filter,"Name='([^']+)'")).Groups[1].Value
    if(-not $script:ServiceStates.ContainsKey($name)){throw "Unknown service: $name"}
    [pscustomobject]@{Name=$name;State=$script:ServiceStates[$name]}
}
function Get-FirewallSharingRules{@($script:FirewallFixture)}
function Set-NetFirewallRule{[CmdletBinding()]param([string]$Name,$Enabled,[Alias('Profile')]$FirewallProfile);$null=@($Name,$Enabled,$FirewallProfile)}
function Get-NetFirewallRule{[CmdletBinding()]param([string]$Name);$null=$Name;[pscustomobject]@{Name='synthetic';Enabled='True';Profile='Domain, Private'}}
function Enable-PrivateFirewallSharing([object[]]$FirewallRules=$null){$script:FirewallRepairNames=@($FirewallRules|ForEach-Object{[string]$_.Name})}
function Invoke-RestartSpooler{$script:RestartCalls++}
function Start-NetworkDiscoveryServices{$script:DiscoveryCalls++}
function Get-NetworkProfilesSafe{@()}

function Read-LatestState {
    $dir=([string](Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1)).Trim()
    [pscustomobject]@{Directory=$dir;State=(Get-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Raw|ConvertFrom-Json)}
}
function Assert-Names([object[]]$Items,[string[]]$Expected,[string]$Label){
    $actual=@($Items|ForEach-Object{[string]$_.Name}|Sort-Object)
    $wanted=@($Expected|Sort-Object)
    if(($actual -join '|') -ne ($wanted -join '|')){throw "$Label mismatch. Actual=$($actual -join ',') Expected=$($wanted -join ',')"}
}
function Reset-Harness {
    Remove-Item -LiteralPath $script:BackupRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null
    $script:ChoiceQueue=@('6','B')
    $script:FirewallRepairNames=@()
    $script:RestartCalls=0
    $script:DiscoveryCalls=0
}

try {
    # Mixed state: only stopped discovery service and firewall rule needing change belong in snapshot.
    Reset-Harness
    $script:ServiceStates=@{Spooler='Running';fdPHost='Stopped';FDResPub='Running'}
    $script:FirewallFixture=@(
      [pscustomobject]@{Name='FPS-Ready';Profile='Domain, Private';Enabled='True'},
      [pscustomobject]@{Name='FPS-Fix';Profile='Private';Enabled='False'},
      [pscustomobject]@{Name='FPS-Public';Profile='Public';Enabled='False'}
    )
    Show-SafeRepairMenu
    $mixed=Read-LatestState
    Assert-Names @($mixed.State.Services) @('Spooler','fdPHost') 'Combined mixed service snapshot'
    Assert-Names @($mixed.State.FirewallRules) @('FPS-Fix') 'Combined mixed firewall snapshot'
    if(($script:FirewallRepairNames -join ',') -ne 'FPS-Fix'){throw 'Combined firewall mutation set differs from its snapshot set.'}
    if($script:RestartCalls -ne 1 -or $script:DiscoveryCalls -ne 1){throw 'Combined mixed repair did not execute planned service repairs exactly once.'}
    [void](Get-ValidatedRestoreSnapshot $mixed.Directory)

    # Already-correct discovery/firewall state: combined snapshot contains Spooler only, with no firewall state.
    Reset-Harness
    $script:ServiceStates=@{Spooler='Running';fdPHost='Running';FDResPub='Running'}
    $script:FirewallFixture=@([pscustomobject]@{Name='FPS-Ready';Profile='Domain, Private';Enabled='True'})
    Show-SafeRepairMenu
    $noop=Read-LatestState
    Assert-Names @($noop.State.Services) @('Spooler') 'Combined already-correct service snapshot'
    if(@($noop.State.FirewallRules).Count -ne 0){throw 'Combined already-correct repair captured firewall state it would not mutate.'}
    if($script:FirewallRepairNames.Count -ne 0){throw 'Combined already-correct repair invoked firewall mutation.'}
    if($script:RestartCalls -ne 1 -or $script:DiscoveryCalls -ne 0){throw 'Combined already-correct repair service execution does not match planned mutation set.'}
    [void](Get-ValidatedRestoreSnapshot $noop.Directory)

    # Independent combined substeps must all be attempted even when earlier ones throw.
    Reset-Harness
    $script:ServiceStates=@{Spooler='Running';fdPHost='Stopped';FDResPub='Running'}
    $script:FirewallFixture=@([pscustomobject]@{Name='FPS-Fix';Profile='Private';Enabled='False'})
    $script:FailRestart=$true
    $script:FailFirewall=$true
    $script:FailDiscovery=$true
    Show-SafeRepairMenu
    if($script:RestartCalls -ne 1 -or $script:FirewallRepairNames.Count -ne 1 -or $script:DiscoveryCalls -ne 1){throw 'Combined substep failure stopped a later planned repair.'}
    if($script:FailMessages.Count -ne 3){throw "Combined substep failures were not reported independently. Count=$($script:FailMessages.Count)"}

    Write-Host 'Combined Safe Repair scope smoke passed: snapshot services/firewall exactly match the planned mutation set.' -ForegroundColor Green
} finally {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}