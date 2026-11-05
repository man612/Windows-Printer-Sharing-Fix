$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$root=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $root 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 did not parse.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Get-Printer {
    [CmdletBinding()]param()
    throw 'Synthetic PrintManagement failure'
}
function Get-CimInstance {
    [CmdletBinding()]param([string]$ClassName)
    if($ClassName -ne 'Win32_Printer'){throw 'Unexpected CIM class'}
    @(
        [pscustomobject]@{Name='Office TCPIP';Network=$true;Local=$true;PortName='IP_192.0.2.10';DriverName='Mock';Shared=$false;ShareName=$null}
        [pscustomobject]@{Name='\\PRINT-PC\Shared';Network=$true;Local=$false;PortName='Ne00:';DriverName='Mock';Shared=$false;ShareName=$null}
    )
}
$printers=@(Get-PrinterInventory)
if($printers.Count -ne 2){throw "CIM fallback returned $($printers.Count) printers instead of 2."}
if($printers[0].Type -eq 'Connection'){throw 'Direct IP printer misclassified as a removable shared printer connection.'}
if($printers[1].Type -ne 'Connection'){throw 'UNC shared-printer connection was not detected.'}
$diag=[pscustomobject]@{Spooler=[pscustomobject]@{Status='Running'};WPP=[pscustomobject]@{Enabled=$false};Profiles=@();PrintErrors=@();Printers=@()}
$target=[pscustomobject]@{DnsResolved=$true;Smb445Reachable=$true;Rpc135Reachable=$true;RpcTransport='Tcp';ShareNamespaceAccessible=$null;PrinterInstalled=$false}
$next=Get-NextInvestigation $diag $target
if($next.Layer -ne 'ShareNamespaceUnverified' -or $next.Reason -ne 'TargetNamespaceProbeUnavailable'){throw "Unknown namespace was misclassified: $($next.Layer)/$($next.Reason)"}
$target.ShareNamespaceAccessible=$false
$next=Get-NextInvestigation $diag $target
if($next.Layer -ne 'ShareNamespaceOrCredentials'){throw 'Confirmed namespace failure was not detected.'}
$target.ShareNamespaceAccessible=$true
$next=Get-NextInvestigation $diag $target
if($next.Layer -ne 'PrinterConnectionSetup'){throw 'Successful namespace check did not allow connection diagnosis.'}
$diag.Profiles=@([pscustomobject]@{NetworkCategory='Public';IPv4Connectivity='Disconnected';IPv6Connectivity='Internet'})
if('PublicNetworkProfile' -notin @(Get-NextInvestigationSignals $diag)){throw 'IPv6-only Public network was not detected as a relevant signal.'}
$diag.Profiles=@([pscustomobject]@{NetworkCategory='Public';IPv4Connectivity='Disconnected';IPv6Connectivity='Disconnected'})
if('PublicNetworkProfile' -in @(Get-NextInvestigationSignals $diag)){throw 'Disconnected Public network incorrectly flagged as active.'}
Write-Host 'Network printer classification and namespace tri-state smoke passed.' -ForegroundColor Green
