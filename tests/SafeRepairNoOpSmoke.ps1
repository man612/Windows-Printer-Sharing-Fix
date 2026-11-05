$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before Safe Repair no-op smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$script:Language='EN'
$script:Text=@{EN=@{};ID=@{}}
$script:SnapshotCalls=0
$script:SnapshotFirewallNames=@()
$script:RepairFirewallNames=@()
$script:ChoiceQueue=@()
$script:SelectedProfile=$null
$script:FirewallFixture=@()
$script:ServiceStates=@{}
$script:SnapshotServiceNames=@()

function L([string]$English,[string]$Indonesian){$English}
function T([string]$Key){$Key}
function Write-Header([string]$Text){}
function Write-Rule{}
function Write-Info([string]$Text){}
function Write-Warn([string]$Text){}
function Write-Fail([string]$Text){if($script:ExpectDrift){$script:LastDriftError=$Text;return};throw $Text}
function Write-Ok([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Pause-Tui{}
function Write-Host{param([Parameter(ValueFromRemainingArguments=$true)]$Object);$null=$Object}
$script:PreviewCalls=0
$script:PreviewConsent=$true
function Confirm-SafeRepairPreview([string]$Action,[string[]]$Steps,[string]$Impact,[string]$RestoreNote){
    $null=@($Action,$Steps,$Impact,$RestoreNote)
    $script:PreviewCalls++
    if($script:PreviewDrift -eq 'Firewall' -and $script:FirewallFixture.Count){$script:FirewallFixture[0].Profile='Public'}
    if($script:PreviewDrift -eq 'Discovery'){$script:ServiceStates['fdPHost']='Running'}
    if($script:PreviewDrift -eq 'Network'){$script:SelectedProfile.NetworkCategory='DomainAuthenticated'}
    return [bool]$script:PreviewConsent
}
function Read-Choice([string]$Prompt,[string[]]$Allowed){
    $null=@($Prompt,$Allowed)
    if(-not $script:ChoiceQueue.Count){throw 'Choice queue exhausted.'}
    $next=[string]$script:ChoiceQueue[0]
    $script:ChoiceQueue=@($script:ChoiceQueue|Select-Object -Skip 1)
    return $next
}
function New-RestoreSnapshot{
    param([string]$Reason,[string[]]$Scopes,[object[]]$FirewallRules,[object[]]$NetworkProfiles,[string[]]$ServiceNames)
    $null=@($Reason,$Scopes,$NetworkProfiles)
    $script:SnapshotCalls++
    if($PSBoundParameters.ContainsKey('FirewallRules')){$script:SnapshotFirewallNames=@($FirewallRules|ForEach-Object{[string]$_.Name})}
    if($PSBoundParameters.ContainsKey('ServiceNames')){$script:SnapshotServiceNames=@($ServiceNames)}
    return 'synthetic-snapshot'
}
function Assert-FirewallLocalPolicyEffective([object[]]$Rules,[switch]$RequireEnabled,[switch]$SkipBaselineComparison){$null=@($Rules,$RequireEnabled,$SkipBaselineComparison)}
function Get-FirewallSharingRules{@($script:FirewallFixture)}
function Set-NetFirewallRule{param($Name,$Enabled,[Alias('Profile')]$FirewallProfile,$ErrorAction);$null=@($Name,$Enabled,$FirewallProfile,$ErrorAction)}
function Get-NetFirewallRule{param($Name,$ErrorAction);$null=@($Name,$ErrorAction);[pscustomobject]@{Name=$Name;Enabled='True';Profile='Domain, Private'}}
function Enable-PrivateFirewallSharing([object[]]$FirewallRules=$null){$script:RepairFirewallNames=@($FirewallRules|ForEach-Object{[string]$_.Name})}
function Select-NetworkProfile{$script:SelectedProfile}
function Set-NetConnectionProfile{param($InterfaceIndex,$NetworkCategory,$ErrorAction);$null=@($InterfaceIndex,$NetworkCategory,$ErrorAction)}
function Get-NetConnectionProfile{param($InterfaceIndex,$ErrorAction);$null=@($InterfaceIndex,$ErrorAction);$script:SelectedProfile}
function Set-OneNetworkPrivate([object]$SelectedProfile=$null){$null=$SelectedProfile}
function Get-Service{
    [CmdletBinding()]param([string]$Name)
    if(-not $script:ServiceStates.ContainsKey($Name)){throw "Unknown service: $Name"}
    [pscustomobject]@{Name=$Name;Status=$script:ServiceStates[$Name]}
}
function Start-NetworkDiscoveryServices{}
function Invoke-RestartSpooler{}
function Invoke-ClearPrintQueue{}

$script:PreviewDrift=''
$script:ExpectDrift=$false
$script:LastDriftError=''
function Reset-Harness{
    $script:SnapshotCalls=0
    $script:SnapshotFirewallNames=@()
    $script:RepairFirewallNames=@()
    $script:ChoiceQueue=@()
    $script:SelectedProfile=$null
    $script:PreviewDrift=''
    $script:ExpectDrift=$false
    $script:LastDriftError=''
    $script:FirewallFixture=@()
    $script:ServiceStates=@{}
    $script:SnapshotServiceNames=@()
}

# Firewall no-op: only Public rule -> no snapshot.
Reset-Harness
$script:FirewallFixture=@([pscustomobject]@{Name='FPS-Public';Profile='Public';Enabled='False';Direction='Inbound';Action='Allow'})
$script:ChoiceQueue=@('3','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -ne 0){throw 'No-op firewall Safe Repair created a Restore snapshot.'}

# Firewall already desired -> no snapshot.
Reset-Harness
$script:FirewallFixture=@([pscustomobject]@{Name='FPS-Ready';Profile='Domain, Private';Enabled='True';Direction='Inbound';Action='Allow'})
$script:ChoiceQueue=@('3','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -ne 0){throw 'Already-correct firewall Safe Repair created a Restore snapshot.'}

# Firewall mixed state -> snapshot/repair only the rule needing change.
Reset-Harness
$script:FirewallFixture=@(
  [pscustomobject]@{Name='FPS-Ready';Profile='Domain, Private';Enabled='True';Direction='Inbound';Action='Allow'},
  [pscustomobject]@{Name='FPS-Fix';Profile='Private';Enabled='False';Direction='Inbound';Action='Allow'},
  [pscustomobject]@{Name='FPS-Public';Profile='Public';Enabled='False';Direction='Inbound';Action='Allow'}
)
$script:ChoiceQueue=@('3','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -ne 1){throw 'Firewall repair requiring change did not create exactly one snapshot.'}
if(($script:SnapshotFirewallNames -join ',') -ne 'FPS-Fix'){throw 'Firewall snapshot contained rules that did not need mutation.'}
if(($script:RepairFirewallNames -join ',') -ne 'FPS-Fix'){throw 'Firewall mutation set did not match snapshot set.'}

# Network already Private -> no snapshot.
Reset-Harness
$script:SelectedProfile=[pscustomobject]@{InterfaceIndex=7;NetworkCategory='Private';InterfaceAlias='Ethernet'}
$script:ChoiceQueue=@('4','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -ne 0){throw 'Already-Private network Safe Repair created a Restore snapshot.'}

# Network Discovery already running -> no snapshot.
Reset-Harness
$script:ServiceStates=@{fdPHost='Running';FDResPub='Running'}
$script:ChoiceQueue=@('5','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -ne 0){throw 'Already-running Network Discovery Safe Repair created a Restore snapshot.'}

# Network Discovery needs change -> snapshot only the stopped service before mutation.
Reset-Harness
$script:ServiceStates=@{fdPHost='Stopped';FDResPub='Running'}
$script:ChoiceQueue=@('5','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -ne 1){throw 'Network Discovery repair requiring change did not create a snapshot.'}
if(($script:SnapshotServiceNames -join ',') -ne 'fdPHost'){throw 'Network Discovery snapshot included a service already Running.'}

# If both discovery services need repair, both remain in snapshot scope.
Reset-Harness
$script:ServiceStates=@{fdPHost='Stopped';FDResPub='Stopped'}
$script:ChoiceQueue=@('5','B')
Show-SafeRepairMenu
$sortedServiceNames=@($script:SnapshotServiceNames|Sort-Object)
if(($sortedServiceNames -join ',') -ne 'fdPHost,FDResPub'){throw 'Network Discovery snapshot omitted a stopped service.'}

# Refusing a real firewall change must skip BOTH snapshot creation and mutation.
Reset-Harness
$script:PreviewConsent=$false
$script:PreviewCalls=0
$script:FirewallFixture=@([pscustomobject]@{Name='FPS-Fix';Profile='Private';Enabled='False';Direction='Inbound';Action='Allow'})
$script:ChoiceQueue=@('3','B')
Show-SafeRepairMenu
if($script:PreviewCalls -ne 1 -or $script:SnapshotCalls -ne 0 -or $script:RepairFirewallNames.Count){
    throw 'Declining a Safe Repair preview still created a snapshot or modified a firewall rule.'
}
$script:PreviewConsent=$true

# Changing the target after an approved preview must cancel BEFORE making a snapshot.
Reset-Harness
$script:PreviewConsent=$true
$script:PreviewDrift='Firewall'
$script:ExpectDrift=$true
$script:FirewallFixture=@([pscustomobject]@{Name='FPS-Fix';Profile='Private';Enabled='False';Direction='Inbound';Action='Allow'})
$script:ChoiceQueue=@('3','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -or $script:RepairFirewallNames.Count -or $script:LastDriftError -notlike '*plan changed*'){throw 'Firewall drift was not rejected before mutation or snapshot.'}

Reset-Harness
$script:PreviewDrift='Discovery'
$script:ExpectDrift=$true
$script:ServiceStates=@{fdPHost='Stopped';FDResPub='Running'}
$script:ChoiceQueue=@('5','B')
Show-SafeRepairMenu
if($script:SnapshotCalls -or $script:LastDriftError -notlike '*plan changed*'){throw 'Network Discovery drift was not rejected before snapshot.'}

Reset-Harness
$script:PreviewDrift='Network'
$script:ExpectDrift=$true
$script:SelectedProfile=[pscustomobject]@{InterfaceIndex=7;InterfaceAlias='Ethernet';Name='TestLAN';NetworkCategory='Public';IPv4Connectivity='Internet';IPv6Connectivity='Disconnected'}
$script:ChoiceQueue=@('4','B') # Select-NetworkProfile is stubbed; no second selection prompt.
Show-SafeRepairMenu
if($script:SnapshotCalls -or $script:LastDriftError -notlike '*plan changed*'){throw 'Network profile drift was not rejected before snapshot.'}
$script:PreviewDrift=''

Write-Host 'Safe-repair no-op smoke passed: no-op firewall/network/discovery actions preserve Restore history, and Network Discovery snapshots only services that need mutation.' -ForegroundColor Green