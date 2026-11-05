$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$source=Join-Path (Split-Path -Parent $PSScriptRoot) 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'FixPrinter source does not parse.'}
foreach($name in @('Assert-SafeRepairPlanUnchanged','Test-FirewallRuleNeedsSafeRepair')){
    $fn=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $name})|Select-Object -First 1
    if(-not $fn){throw "Required check missing: $name"}
    . ([scriptblock]::Create($fn.Extent.Text))
}
$script:ServiceMap=@{Spooler='Running';fdPHost='Stopped'}
$script:Rules=@([pscustomobject]@{Name='FPS-Fix';Enabled='False';Profile='Private';Direction='Inbound';Action='Allow'})
$script:Profiles=@([pscustomobject]@{InterfaceIndex=9;InterfaceAlias='Ethernet';Name='OfficeLAN';NetworkCategory='Public';IPv4Connectivity='Internet';IPv6Connectivity='Disconnected'})
function Get-Service{
    [CmdletBinding()]param([string]$Name)
    if(-not $script:ServiceMap.ContainsKey($Name)){throw 'Service not found in the synthetic OS.'}
    [pscustomobject]@{Name=$Name;Status=$script:ServiceMap[$Name]}
}
function Get-FirewallSharingRules{return @($script:Rules)}
function Get-NetworkProfilesSafe{return @($script:Profiles)}
function Assert-Rejected([scriptblock]$Check,[string]$Case){
    $rejected=$false
    try{& $Check}catch{$rejected=$true}
    if(-not $rejected){throw "Unsafe stale state accepted: $Case"}
}
$services=@([pscustomobject]@{Name='Spooler';Status='Running'},[pscustomobject]@{Name='fdPHost';Status='Stopped'})
$firewall=@($script:Rules|Select-Object Name,Enabled,Profile,Direction,Action)
$network=$script:Profiles[0]|Select-Object InterfaceIndex,InterfaceAlias,Name,NetworkCategory,IPv4Connectivity,IPv6Connectivity
# Unchanged preview must pass, including a valid empty eligible rule list.
Assert-SafeRepairPlanUnchanged -ExpectedServices $services -ExpectedFirewallRules $firewall -CheckFirewall -ExpectedNetworkProfile $network
$script:ServiceMap['fdPHost']='Running'
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedServices $services} 'service status changed'
$script:ServiceMap['fdPHost']='Stopped'
$script:Rules[0].Enabled='True'
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedFirewallRules $firewall -CheckFirewall} 'firewall enabled changed'
$script:Rules[0].Enabled='False'
$script:Rules[0].Action='Block'
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedFirewallRules $firewall -CheckFirewall} 'firewall action changed'
$script:Rules[0].Action='Allow'
$script:Rules[0].Profile='Public'
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedFirewallRules $firewall -CheckFirewall} 'firewall became ineligible'
$script:Rules[0].Profile='Private'
$script:Rules+=([pscustomobject]@{Name='New-Eligible';Enabled='False';Profile='Domain';Direction='Inbound';Action='Allow'})
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedFirewallRules $firewall -CheckFirewall} 'new firewall rule became eligible'
$script:Rules=@($script:Rules|Where-Object{$_.Name -eq 'FPS-Fix'})
$script:Profiles[0].NetworkCategory='Private'
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedNetworkProfile $network} 'network category changed'
$script:Profiles[0].NetworkCategory='Public'
$script:Profiles[0].InterfaceAlias='Ethernet Renamed'
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedNetworkProfile $network} 'network identity changed'
$script:Profiles=@()
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedNetworkProfile $network} 'interface disappeared'
$script:Rules=@()
Assert-Rejected {Assert-SafeRepairPlanUnchanged -ExpectedFirewallRules $firewall -CheckFirewall} 'firewall inventory unavailable'
Write-Host 'Safe Repair state-drift smoke passed: service, firewall, and network previews fail closed on stale state.' -ForegroundColor Green
