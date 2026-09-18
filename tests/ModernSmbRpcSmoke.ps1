$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before modern SMB/RPC smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

function New-State([bool]$Present,[object]$Value=$null){
    [pscustomobject]@{Present=$Present;Value=$Value;Kind=if($Present){'DWord'}else{$null}}
}

$source=Get-Content -LiteralPath $scriptFile -Raw
if($source -match 'Set-Smb(Client|Server)Configuration'){throw 'Stable diagnosis must not mutate SMB security configuration.'}
if($source -match 'RequireSecuritySignature\s+\$false|RequireEncryption\s+\$false'){throw 'Stable code must not disable SMB signing/encryption.'}

$guest=Get-SmbSecurityEventClassification 'Microsoft-Windows-SMBClient/Security' 31017
if($guest.Side -ne 'Client' -or $guest.Category -ne 'RejectedInsecureGuest'){throw 'SMB 31017 classification failed.'}
foreach($id in @(31998,31999)){
    $x=Get-SmbSecurityEventClassification 'Microsoft-Windows-SMBClient/Audit' $id
    if($x.Category -ne 'SigningOrEncryptionCompatibility'){throw "SMB client audit event $id classification failed."}
}
foreach($id in @(3021,3022)){
    $x=Get-SmbSecurityEventClassification 'Microsoft-Windows-SMBServer/Audit' $id
    if($x.Side -ne 'Server' -or $x.Category -ne 'SigningOrEncryptionCompatibility'){throw "SMB server audit event $id classification failed."}
}

$posture=Get-SmbSecurityPosture
if($null -eq $posture.Client -or $null -eq $posture.Server){throw 'SMB posture shape is incomplete.'}
if($posture.Client.Available){
    foreach($name in @('RequireSigning','RequireEncryption','InsecureGuestAllowed')){
        if($null -eq $posture.Client.PSObject.Properties[$name]){throw "SMB client posture missing $name."}
    }
}

$present=New-State $true 1;$absent=New-State $false
$rsop=[pscustomobject]@{Available=$true;Settings=@(
    [pscustomobject]@{RegistryKey='Software\Policies\Microsoft\Windows NT\Printers\RPC';ValueName='RpcTcpPort';GpoId='LocalGPO';SomId='Local';Precedence=1;Deleted=$false},
    [pscustomobject]@{RegistryKey='Software\Policies\Microsoft\Windows NT\Printers\RPC';ValueName='ForceKerberosForRpc';GpoId='{SYNTHETIC}';SomId='LDAP://synthetic';Precedence=1;Deleted=$false}
)}
$policy=Get-PrinterPolicySourceEvidence -Build 26100 -RpcPrivacy $absent -RpcUseNamedPipe $absent -RpcProtocols $absent -RpcTcpPort $present -ForceKerberosForRpc $present -RemoteRpcEndpoint $present -PointAndPrint $absent -WppGroupPolicy $absent -RsopResult $rsop -MdmEvidence ([pscustomobject]@{CombinedEvidence=$true})
if($policy.RpcTcpPort.Source -ne 'LocalGroupPolicy'){throw 'RpcTcpPort RSoP source classification failed.'}
if($policy.ForceKerberosForRpc.Source -ne 'GroupPolicy'){throw 'ForceKerberosForRpc RSoP source classification failed.'}
if($policy.RemoteRpcEndpoint.Source -ne 'PossibleMdmOrOtherPolicy'){throw 'Remote RPC endpoint MDM-aware source classification failed.'}
$diag=[pscustomobject]@{
    Spooler=[pscustomobject]@{Status='Running'}
    WPP=[pscustomobject]@{Enabled=$false}
    Profiles=@()
    PrintErrors=@()
    Printers=@()
}
$target=[pscustomobject]@{
    DnsResolved=$true;Smb445Reachable=$true;Rpc135Reachable=$true
    RpcConfiguredPort=55000;RpcConfiguredPortReachable=$false
    ShareNamespaceAccessible=$false;PrinterInstalled=$false
    SmbSecuritySignals=@('SigningOrEncryptionCompatibility')
}
$next=Get-NextInvestigation $diag $target
if($next.Layer -ne 'RpcReachability' -or $next.Reason -ne 'TargetConfiguredRpcPortFailed'){throw 'Configured print RPC port failure was not prioritized.'}
if($next.RootCauseClaimed){throw 'Modern SMB/RPC correlation must not claim root cause.'}
if(($next.Signals -join '|') -notmatch 'SmbSecurity:SigningOrEncryptionCompatibility'){throw 'Normalized SMB security signal was lost.'}

$target.RpcConfiguredPortReachable=$true
$next=Get-NextInvestigation $diag $target
if($next.Layer -ne 'ShareNamespaceOrCredentials'){throw 'Namespace failure should follow a reachable configured RPC port.'}

Write-Host 'Modern SMB/RPC smoke passed: policy evidence, SMB posture, normalized events, static RPC port ordering, and no-downgrade boundary are stable.' -ForegroundColor Green
