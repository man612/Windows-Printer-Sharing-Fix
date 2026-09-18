$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before repair-postcondition smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join ([Environment]::NewLine + [Environment]::NewLine)))

$script:Language='EN'
$script:Ok=@()
$script:Warn=@()
$script:Fail=@()
$script:Logs=@()
function L([string]$English,[string]$Indonesian){$English}
function Write-Ok([string]$Text){$script:Ok += $Text}
function Write-Warn([string]$Text){$script:Warn += $Text}
function Write-Fail([string]$Text){$script:Fail += $Text}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){$script:Logs += ($Level+':'+$Message)}
function Reset-Messages {$script:Ok=@();$script:Warn=@();$script:Fail=@();$script:Logs=@()}

# Registry setter must verify read-back.
$script:RegistryValue=1
$script:RegistryWriteChangesState=$false
function Test-Path{param([string]$LiteralPath);$null=$LiteralPath;$true}
function New-ItemProperty{
    [CmdletBinding()] param([string]$Path,[string]$Name,$PropertyType,[int]$Value,[switch]$Force)
    $null=@($Path,$Name,$PropertyType,$Force)
    if($script:RegistryWriteChangesState){$script:RegistryValue=$Value}
}
function Get-RegistryValueState([string]$Path,[string]$Name){$null=@($Path,$Name);[pscustomobject]@{Present=$true;Value=$script:RegistryValue;Kind='DWord'}}
$threw=$false
try{Set-RegistryDword 'HKLM:\X' 'TestValue' 0}catch{$threw=$true}
if(-not $threw){throw 'Registry setter accepted a no-op write without read-back verification.'}
$script:RegistryWriteChangesState=$true
Set-RegistryDword 'HKLM:\X' 'TestValue' 0
if($script:RegistryValue -ne 0){throw 'Registry setter success fixture did not update state.'}

# Restart Spooler must verify Stopped then Running.
Reset-Messages
$script:SpoolerState='Running'
$script:SpoolerCommandsChangeState=$false
function Stop-Service{
    [CmdletBinding()] param([string]$Name,[switch]$Force)
    $null=@($Name,$Force)
    if($script:SpoolerCommandsChangeState){$script:SpoolerState='Stopped'}
}
function Start-Service{
    [CmdletBinding()] param([string]$Name)
    $null=$Name
    if($script:SpoolerCommandsChangeState){$script:SpoolerState='Running'}
}
function Get-Service{[CmdletBinding()]param([string]$Name);[pscustomobject]@{Name=$Name;Status=$script:SpoolerState}}
$threw=$false
try{Invoke-RestartSpooler}catch{$threw=$true}
if(-not $threw -or $script:Ok.Count){throw 'Restart Spooler accepted a no-op service command or reported false success.'}
Reset-Messages
$script:SpoolerCommandsChangeState=$true
Invoke-RestartSpooler
if($script:Ok.Count -ne 1 -or $script:SpoolerState -ne 'Running'){throw 'Verified Restart Spooler success path failed.'}

# Network profile change must read back Private.
Reset-Messages
$script:NetworkCategory='Public'
$script:NetworkSetterChangesState=$false
$selected=[pscustomobject]@{InterfaceIndex=7;NetworkCategory='Public';InterfaceAlias='Ethernet'}
function Set-NetConnectionProfile{
    [CmdletBinding()] param([int]$InterfaceIndex,[string]$NetworkCategory)
    $null=$InterfaceIndex
    if($script:NetworkSetterChangesState){$script:NetworkCategory=$NetworkCategory}
}
function Get-NetworkProfilesSafe{@([pscustomobject]@{InterfaceIndex=7;NetworkCategory=$script:NetworkCategory;InterfaceAlias='Ethernet'})}
$threw=$false
try{Set-OneNetworkPrivate -SelectedProfile $selected}catch{$threw=$true}
if(-not $threw -or $script:Ok.Count){throw 'Network profile change accepted a no-op setter or reported false success.'}
Reset-Messages
$script:NetworkSetterChangesState=$true
Set-OneNetworkPrivate -SelectedProfile $selected
if($script:Ok.Count -ne 1 -or $script:NetworkCategory -ne 'Private'){throw 'Verified network profile success path failed.'}

# SMB1 enable must verify optional-feature state.
Reset-Messages
$script:FeatureState='Disabled'
$script:FeatureSetterChangesState=$false
function Read-Host([string]$Prompt){$null=$Prompt;'LEGACY'}
function New-RestoreSnapshot([string]$Reason,[string[]]$Scopes){$null=@($Reason,$Scopes);'snapshot'}
function Get-WindowsFeatureState([string]$Name){$null=$Name;$script:FeatureState}
function Enable-WindowsOptionalFeature{
    [CmdletBinding()] param([switch]$Online,[string]$FeatureName,[switch]$NoRestart)
    $null=@($Online,$FeatureName,$NoRestart)
    if($script:FeatureSetterChangesState){$script:FeatureState='Enabled'}
}
$threw=$false
try{Enable-Smb1ClientLegacy}catch{$threw=$true}
if(-not $threw){throw 'SMB1 enable accepted a no-op feature command.'}
if(($script:Warn -join ' ') -match 'SMB1 CLIENT enabled'){throw 'SMB1 no-op path falsely reported enabled.'}
Reset-Messages
$script:FeatureSetterChangesState=$true
Enable-Smb1ClientLegacy
if($script:FeatureState -ne 'Enabled' -or ($script:Warn -join ' ') -notmatch 'SMB1 CLIENT enabled'){throw 'Verified SMB1 enable success path failed.'}

# Targeted printer removal must verify inventory no longer contains target.
Reset-Messages
$script:PrinterInstalled=$true
$script:PrinterRemovalChangesState=$false
function Get-PrinterInventory{if($script:PrinterInstalled){@([pscustomobject]@{Name='\\host\printer';Type='Connection'})}else{@()}}
function Read-Choice([string]$Prompt,[string[]]$Allowed){$null=@($Prompt,$Allowed);'1'}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){$null=@($Prompt,$DefaultNo);$true}
function Remove-Printer{
    [CmdletBinding()] param([string]$Name)
    $null=$Name
    if($script:PrinterRemovalChangesState){$script:PrinterInstalled=$false}
}
$threw=$false
try{Reset-ClientPrinterConnectionTargeted}catch{$threw=$true}
if(-not $threw -or $script:Ok.Count){throw 'Targeted printer removal accepted a no-op Remove-Printer or reported false success.'}
Reset-Messages
$script:PrinterInstalled=$true
$script:PrinterRemovalChangesState=$true
Reset-ClientPrinterConnectionTargeted
if($script:Ok.Count -ne 1 -or $script:PrinterInstalled){throw 'Verified targeted printer removal success path failed.'}

Write-Host 'Repair-postcondition smoke passed: registry, Spooler, network, SMB1, and printer-removal success requires verified resulting state.' -ForegroundColor Green