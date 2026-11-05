$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$main=Join-Path (Split-Path -Parent $PSScriptRoot) 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($main,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Main script failed to parse.'}
$def=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Confirm-SafeRepairPreview'})|Select-Object -First 1
if(-not $def){throw 'Safe Repair preview helper is missing.'}
. ([scriptblock]::Create($def.Extent.Text))
$script:Output=@()
$script:Responses=@()
$script:DefaultValues=@()
$script:ConfirmationCount=0
function L([string]$English,[string]$Indonesian){$null=$Indonesian;return $English}
function Write-Rule {}
function Write-Info([string]$Text){$script:Output+=$Text}
function Write-Warn([string]$Text){$script:Output+=$Text}
function Write-Host {param([Parameter(ValueFromRemainingArguments=$true)]$Object);$script:Output+=(@($Object) -join ' ')}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true) {
    $script:Output+=$Prompt
    $script:DefaultValues+=$DefaultNo
    $script:ConfirmationCount++
    if(-not $script:Responses.Count){throw 'Synthetic confirmation response queue exhausted.'}
    $answer=[bool]$script:Responses[0]
    $script:Responses=@($script:Responses|Select-Object -Skip 1)
    return $answer
}
$script:Responses=@($false,$true)
$declined=Confirm-SafeRepairPreview 'Firewall change' @('FPS-A: False/Private -> True/Domain,Private') 'Trusted-network access may increase' 'Scoped Restore snapshot'
if($declined){throw 'Safe Repair preview accepted an explicit No.'}
if($script:ConfirmationCount -ne 1 -or $script:DefaultValues[0] -ne $true){throw 'Preview must default to No.'}
if(@($script:Output|Where-Object{$_ -match 'FPS-A'}).Count -ne 1 -or @($script:Output|Where-Object{$_ -match 'Scoped Restore snapshot'}).Count -ne 1){
    throw 'Preview is missing concrete intended changes or Restore limitations.'
}
$accepted=Confirm-SafeRepairPreview 'Spooler restart' @('Spooler: Running -> restart') 'Printing interrupted' 'Restore service baseline'
if(-not $accepted -or $script:ConfirmationCount -ne 2 -or $script:DefaultValues[1] -ne $true){throw 'Preview did not honor explicit Yes/default No.'}
$rejectedEmpty=$false
try{[void](Confirm-SafeRepairPreview 'Empty plan' @() 'Risk' 'Restore')}catch{$rejectedEmpty=$true}
if(-not $rejectedEmpty -or $script:ConfirmationCount -ne 2){throw 'Empty plan reached the confirmation prompt.'}
$menu=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Show-SafeRepairMenu'})|Select-Object -First 1
if(-not $menu){throw 'Safe Repair menu missing.'}
$menuText=$menu.Extent.Text
if(([regex]::Matches($menuText,'Confirm-SafeRepairPreview')).Count -lt 5){throw 'Some Safe Repair actions do not call preview.'}
if($menuText -notmatch "'2'\{Invoke-ClearPrintQueue\}"){throw 'Destructive queue cleanup must retain its own separate confirmation.'}
Write-Host 'Safe Repair preview smoke passed: explicit consent and effect/Restore preview.' -ForegroundColor Green
