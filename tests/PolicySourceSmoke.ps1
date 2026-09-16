$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before policy-source smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"))

function New-State([bool]$Present,[object]$Value=$null) {
    [pscustomobject]@{Present=$Present;Value=$Value;Kind=if($Present){'DWord'}else{$null}}
}

$present = New-State $true 1
$absent = New-State $false
if((Normalize-PolicyRegistryKey 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC') -ne 'software\policies\microsoft\windows nt\printers\rpc') {
    throw 'Policy registry-path normalization failed.'
}
$rsop = [pscustomobject]@{Available=$true;Settings=@(
    [pscustomobject]@{RegistryKey='Software\Policies\Microsoft\Windows NT\Printers\RPC';ValueName='RpcUseNamedPipeProtocol';GpoId='LocalGPO';SomId='Local';Precedence=1;Deleted=$false},
    [pscustomobject]@{RegistryKey='Software\Policies\Microsoft\Windows NT\Printers\RPC';ValueName='RpcProtocols';GpoId='{SYNTHETIC-GPO-ID}';SomId='LDAP://synthetic';Precedence=1;Deleted=$false}
)}
$mdmYes = Get-MdmManagementEvidence -OmaDmAccounts @([pscustomobject]@{Id='synthetic'}) -PolicyManagerProviders @([pscustomobject]@{Id='synthetic'})
$mdmNo = Get-MdmManagementEvidence -OmaDmAccounts @() -PolicyManagerProviders @([pscustomobject]@{Id='synthetic'})
if(-not $mdmYes.CombinedEvidence -or $mdmNo.CombinedEvidence){throw 'Combined MDM evidence guard is incorrect.'}

$result = Get-PrinterPolicySourceEvidence -Build 26100 -RpcPrivacy $present -RpcUseNamedPipe $present -RpcProtocols $present -PointAndPrint $absent -WppGroupPolicy $present -RsopResult $rsop -MdmEvidence $mdmYes
if($result.RpcUseNamedPipe.Source -ne 'LocalGroupPolicy'){throw 'LocalGPO RSoP evidence was not classified as LocalGroupPolicy.'}
if($result.RpcProtocols.Source -ne 'GroupPolicy'){throw 'Non-local RSoP evidence was not classified as GroupPolicy.'}
if($result.RpcPrivacy.Source -ne 'PossibleMdmOrOtherPolicy'){throw 'Unmatched MDM-capable policy with combined MDM evidence was not classified conservatively.'}
if($result.WppGroupPolicy.Source -ne 'PossibleMdmOrOtherPolicy'){throw 'WPP MDM-capable source classification failed.'}
if($result.PointAndPrint.Source -ne 'NotConfigured'){throw 'Absent policy must remain NotConfigured.'}
$emptyRsop = [pscustomobject]@{Available=$true;Settings=@()}
$unknown = Get-PrinterPolicySourceEvidence -Build 26100 -RpcPrivacy $present -RpcUseNamedPipe $absent -RpcProtocols $absent -PointAndPrint $absent -WppGroupPolicy $absent -RsopResult $emptyRsop -MdmEvidence $mdmNo
if($unknown.RpcPrivacy.Source -ne 'RegistryOnlyOrUnknownSource'){throw 'Registry-only policy must not be attributed to Group Policy or MDM.'}

$older = Get-PrinterPolicySourceEvidence -Build 22621 -RpcPrivacy $present -RpcUseNamedPipe $absent -RpcProtocols $absent -PointAndPrint $absent -WppGroupPolicy $absent -RsopResult $emptyRsop -MdmEvidence $mdmYes
if($older.RpcPrivacy.Source -ne 'RegistryOnlyOrUnknownSource'){throw 'MDM attribution ignored the documented minimum build.'}

$deletedRsop = [pscustomobject]@{Available=$true;Settings=@(
    [pscustomobject]@{RegistryKey='System\CurrentControlSet\Control\Print';ValueName='RpcAuthnLevelPrivacyEnabled';GpoId='LocalGPO';SomId='Local';Precedence=1;Deleted=$true}
)}
$deleted = Get-PrinterPolicySourceEvidence -Build 26100 -RpcPrivacy $present -RpcUseNamedPipe $absent -RpcProtocols $absent -PointAndPrint $absent -WppGroupPolicy $absent -RsopResult $deletedRsop -MdmEvidence $mdmNo
if($deleted.RpcPrivacy.Source -ne 'RegistryOnlyOrUnknownSource'){throw 'Deleted RSoP entries must not be treated as active source evidence.'}

Write-Host 'Policy-source smoke passed: Local GPO, Group Policy, possible MDM, unknown source, and build guards are stable.' -ForegroundColor Green
