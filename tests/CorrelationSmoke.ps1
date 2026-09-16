$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before correlation smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join "`r`n`r`n"))

function New-DiagnosticFixture([string]$Spooler='Running',[bool]$Wpp=$false,[string[]]$Categories=@(),[bool]$Public=$false) {
    $events=@($Categories|ForEach-Object{[pscustomobject]@{Category=$_;Message='SECRET-EVENT-MESSAGE'}})
    $profiles=if($Public){@([pscustomobject]@{NetworkCategory='Public';IPv4Connectivity='Internet'})}else{@()}
    $service=if($Spooler -eq 'Missing'){$null}else{[pscustomobject]@{Status=$Spooler}}
    return [pscustomobject]@{Spooler=$service;WPP=[pscustomobject]@{Enabled=$Wpp};Profiles=@($profiles);PrintErrors=@($events)}
}
function New-Target([bool]$Dns=$true,[bool]$Smb=$true,[bool]$Rpc=$true,[bool]$Namespace=$true,[bool]$Installed=$false) {
    return [pscustomobject]@{DnsResolved=$Dns;Smb445Reachable=$Smb;Rpc135Reachable=$Rpc;ShareNamespaceAccessible=$Namespace;PrinterInstalled=$Installed}
}
function Assert-Layer($D,$T,[string]$Layer,[string]$Reason) {
    $n=Get-NextInvestigation $D $T
    if($n.Layer -ne $Layer -or $n.Reason -ne $Reason){throw "Expected $Layer/$Reason, got $($n.Layer)/$($n.Reason)"}
    if($n.RootCauseClaimed){throw 'Correlation must never claim root cause.'}
    return $n
}
$healthy=New-DiagnosticFixture
Assert-Layer (New-DiagnosticFixture -Spooler Missing) $null 'LocalSpooler' 'SpoolerMissing'|Out-Null
Assert-Layer (New-DiagnosticFixture -Spooler Stopped) $null 'LocalSpooler' 'SpoolerNotRunning'|Out-Null
$untested=Assert-Layer $healthy $null 'RemoteTransportUntested' 'TargetPathNotTested'
if($untested.RemoteTransportTested){throw 'Untested target path was marked as tested.'}
Assert-Layer $healthy (New-Target -Dns $false -Smb $false -Rpc $false -Namespace $false) 'NameResolutionOrBasicNetwork' 'TargetDnsFailed'|Out-Null
Assert-Layer $healthy (New-Target -Smb $false -Rpc $false -Namespace $false) 'SmbFirewallOrRouting' 'TargetSmb445Failed'|Out-Null
Assert-Layer $healthy (New-Target -Rpc $false -Namespace $false) 'RpcReachability' 'TargetRpc135Failed'|Out-Null
Assert-Layer $healthy (New-Target -Namespace $false) 'ShareNamespaceOrCredentials' 'TargetNamespaceFailed'|Out-Null
Assert-Layer (New-DiagnosticFixture -Wpp $true) (New-Target) 'WppCompatibility' 'WppEnabledPrinterNotInstalled'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('DriverOrPackage')) (New-Target) 'DriverOrPackage' 'RecentDriverOrPackageEvents'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('Policy')) (New-Target) 'Policy' 'RecentPolicyEvents'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('SharingOrConnection')) (New-Target) 'SharingOrConnection' 'RecentSharingOrConnectionEvents'|Out-Null
Assert-Layer $healthy (New-Target) 'PrinterConnectionSetup' 'PrinterNotInstalledAfterTransport'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('SpoolerOrRpc')) (New-Target -Installed $true) 'SpoolerOrRpc' 'RecentSpoolerOrRpcEvents'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('PortOrProcessor')) (New-Target -Installed $true) 'PortOrProcessor' 'RecentPortOrProcessorEvents'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('PrintJob')) (New-Target -Installed $true) 'PrintJob' 'RecentPrintJobEvents'|Out-Null
Assert-Layer (New-DiagnosticFixture -Categories @('DirectoryOrGpo')) (New-Target -Installed $true) 'DirectoryOrGpo' 'RecentDirectoryOrGpoEvents'|Out-Null
Assert-Layer $healthy (New-Target -Installed $true) 'FunctionalVerification' 'PrerequisitesHealthy'|Out-Null
$signals=(Get-NextInvestigation (New-DiagnosticFixture -Wpp $true -Categories @('DriverOrPackage') -Public $true) $null).Signals
foreach($expected in @('WppEnabled','PublicNetworkProfile','PrintService:DriverOrPackage')){if($expected -notin $signals){throw "Missing supporting signal: $expected"}}
if(($signals -join '|') -match 'SECRET-EVENT-MESSAGE'){throw 'Raw PrintService event message leaked into correlation signals.'}
Write-Host 'Correlation smoke passed: dependency ordering, supporting signals, and no-root-cause boundary are stable.' -ForegroundColor Green
