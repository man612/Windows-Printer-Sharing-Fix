$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$main=Join-Path (Split-Path -Parent $PSScriptRoot) 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($main,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Main source must parse before firewall policy smoke.'}
foreach($name in @('Assert-FirewallLocalPolicyEffective','Test-FirewallRuleNeedsSafeRepair','Enable-PrivateFirewallSharing')){
    $fn=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $name})|Select-Object -First 1
    if(-not $fn){throw "Firewall safety function missing: $name"}
    . ([scriptblock]::Create($fn.Extent.Text))
}
$script:ActiveSource='Local'
$script:ActiveOverride=$false
$script:MergeLocal='True'
$script:FirewallOn='True'
$script:ActiveRuleMissing=$false
$script:LogMessages=@()
$script:SuccessMessages=@()
$script:FailureMessages=@()
$script:WarningMessages=@()
$script:Writes=0
$script:LocalEnabled='False'
$script:LocalProfile='Private'
function L([string]$English,[string]$Indonesian){$null=$Indonesian;return $English}
function Write-Log([string]$Message,[string]$Level='INFO'){$script:LogMessages+=("$Level : $Message")}
function Write-Ok([string]$Text){$script:SuccessMessages+=$Text}
function Write-Fail([string]$Text){$script:FailureMessages+=$Text}
function Write-Warn([string]$Text){$script:WarningMessages+=$Text}
function Get-NetFirewallProfile {
    [CmdletBinding()]param([string]$PolicyStore)
    if($PolicyStore -ne 'ActiveStore'){throw 'Effective profile query must use ActiveStore.'}
    @([pscustomobject]@{Name='Domain';AllowLocalFirewallRules=$script:MergeLocal;Enabled=$script:FirewallOn},
      [pscustomobject]@{Name='Private';AllowLocalFirewallRules=$script:MergeLocal;Enabled=$script:FirewallOn})
}
function Get-NetFirewallRule {
    [CmdletBinding()]param([string]$Name,[string]$PolicyStore,[switch]$TracePolicyStore)
    if($Name -ne 'FPS-Test'){throw 'Unexpected firewall rule name.'}
    if($PolicyStore -eq 'ActiveStore'){
        if(-not $TracePolicyStore){throw 'Effective firewall query did not trace provenance.'}
        if($script:ActiveRuleMissing){return}
        $activeEnabled=if($script:ActiveOverride){'False'}else{$script:LocalEnabled}
        $activeProfile=if($script:ActiveOverride){'Public'}else{$script:LocalProfile}
        return [pscustomobject]@{Name=$Name;Enabled=$activeEnabled;Profile=$activeProfile;Direction='Inbound';Action='Allow';PolicyStoreSourceType=$script:ActiveSource}
    }
    return [pscustomobject]@{Name=$Name;Enabled=$script:LocalEnabled;Profile=$script:LocalProfile;Direction='Inbound';Action='Allow'}
}
function Set-NetFirewallRule {
    [CmdletBinding()]param([string]$Name,$Enabled,[Alias('Profile')][string[]]$FirewallProfile)
    if($Name -ne 'FPS-Test'){throw 'Unexpected firewall write target.'}
    $script:Writes++
    $script:LocalEnabled=[string]$Enabled
    $script:LocalProfile=@($FirewallProfile) -join ', '
}
function Reset-Fixture {
    $script:ActiveSource='Local';$script:ActiveOverride=$false;$script:MergeLocal='True'
    $script:FirewallOn='True';$script:ActiveRuleMissing=$false
    $script:LogMessages=@();$script:SuccessMessages=@();$script:FailureMessages=@();$script:WarningMessages=@();$script:Writes=0
    $script:LocalEnabled='False';$script:LocalProfile='Private'
}
function Assert-Reject([scriptblock]$Check,[string]$Label){
    $rejected=$false
    try{& $Check}catch{$rejected=$true}
    if(-not $rejected){throw "Unsafe effective firewall policy accepted: $Label"}
}
$baseline=@([pscustomobject]@{Name='FPS-Test';Enabled='False';Profile='Private';Direction='Inbound';Action='Allow'})
Reset-Fixture
Assert-FirewallLocalPolicyEffective -Rules $baseline
$script:ActiveSource='GroupPolicy'
Assert-Reject {Assert-FirewallLocalPolicyEffective -Rules $baseline} 'GPO precedence'
$script:ActiveSource='Local'
$script:MergeLocal='False'
Assert-Reject {Assert-FirewallLocalPolicyEffective -Rules $baseline} 'local merge disabled'
$script:MergeLocal='True'
$script:FirewallOn='False'
Assert-Reject {Assert-FirewallLocalPolicyEffective -Rules $baseline} 'effective firewall disabled'
$script:FirewallOn='True'
$script:ActiveSource='Unknown'
Assert-Reject {Assert-FirewallLocalPolicyEffective -Rules $baseline} 'unknown provenance'
$script:ActiveSource='Local'
$script:ActiveOverride=$true
Assert-Reject {Assert-FirewallLocalPolicyEffective -Rules $baseline} 'stale effective state'
$script:ActiveOverride=$false
$script:ActiveRuleMissing=$true
Assert-Reject {Assert-FirewallLocalPolicyEffective -Rules $baseline} 'missing active rule'
Reset-Fixture
Enable-PrivateFirewallSharing -FirewallRules $baseline
if($script:Writes -ne 1 -or $script:SuccessMessages.Count -ne 1 -or $script:FailureMessages.Count){
    throw 'Effective local firewall repair incorrectly failed the successful ActiveStore verification.'
}
Reset-Fixture
$script:ActiveOverride=$true
Enable-PrivateFirewallSharing -FirewallRules $baseline
if($script:Writes -ne 1 -or $script:SuccessMessages.Count -or $script:FailureMessages.Count -ne 1 -or $script:WarningMessages.Count -ne 1){
    throw 'ActiveStore override after local write was incorrectly reported as success.'
}
$menu=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Show-SafeRepairMenu'})|Select-Object -First 1
if(-not $menu -or ([regex]::Matches($menu.Extent.Text,'Assert-FirewallLocalPolicyEffective')).Count -lt 2){
    throw 'Safe and combined repair paths must both block policy-managed firewall mutations before snapshot.'
}
Write-Host 'Effective firewall policy smoke passed: ActiveStore overrides and local-merge restrictions fail closed.' -ForegroundColor Green
