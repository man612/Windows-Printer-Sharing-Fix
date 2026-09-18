$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before repair-outcome smoke.'}
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

# Firewall: all eligible updates succeed.
Reset-Messages
$script:FirewallFailName=$null
$script:FirewallAttempts=@()
function Set-NetFirewallRule {
    [CmdletBinding()] param([string]$Name,$Enabled,[Alias('Profile')]$FirewallProfile)
    $null=@($Enabled,$FirewallProfile)
    $script:FirewallAttempts += $Name
    if($Name -eq $script:FirewallFailName){Write-Error 'synthetic firewall failure'}
}
$rules=@(
  [pscustomobject]@{Name='FPS-One';Profile='Private';Enabled='False'},
  [pscustomobject]@{Name='FPS-Two';Profile='Domain';Enabled='False'},
  [pscustomobject]@{Name='FPS-Public';Profile='Public';Enabled='False'}
)
Enable-PrivateFirewallSharing -FirewallRules $rules
if($script:Ok.Count -ne 1 -or $script:Fail.Count -ne 0){throw 'Successful firewall repair did not report exactly one success.'}
if(($script:FirewallAttempts -join ',') -ne 'FPS-One,FPS-Two'){throw 'Firewall repair touched rules outside the eligible set.'}

# Firewall: partial failure must suppress success and emit failure.
Reset-Messages
$script:FirewallAttempts=@()
$script:FirewallFailName='FPS-Two'
Enable-PrivateFirewallSharing -FirewallRules $rules
if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Partial firewall failure produced a false success or no failure.'}
if($script:FirewallAttempts.Count -ne 2){throw 'Firewall repair stopped before attempting all eligible rules.'}

# Network Discovery: both services reach Running.
Reset-Messages
$script:ServiceState=@{fdPHost='Stopped';FDResPub='Stopped'}
$script:FailStartService=$null
function Get-Service {
    param([string]$Name)
    if(-not $script:ServiceState.ContainsKey($Name)){throw "Unknown service: $Name"}
    [pscustomobject]@{Name=$Name;Status=$script:ServiceState[$Name]}
}
function Start-Service {
    [CmdletBinding()] param([string]$Name)
    if($Name -eq $script:FailStartService){Write-Error 'synthetic service start failure';return}
    $script:ServiceState[$Name]='Running'
}
Start-NetworkDiscoveryServices
if($script:Ok.Count -ne 1 -or $script:Fail.Count -ne 0){throw 'Successful Network Discovery start did not report success.'}
if($script:ServiceState.fdPHost -ne 'Running' -or $script:ServiceState.FDResPub -ne 'Running'){throw 'Network Discovery services did not reach Running.'}

# Network Discovery: one service start fails -> no OK.
Reset-Messages
$script:ServiceState=@{fdPHost='Stopped';FDResPub='Stopped'}
$script:FailStartService='FDResPub'
Start-NetworkDiscoveryServices
if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Network Discovery failure produced a false success or no failure.'}

# Queue harness.
$script:QueueEntries=@('job1.spl','job2.shd')
$script:SpoolerState='Running'
$script:StopFails=$false
$script:StartFails=$false
$script:DeleteFails=$false
$script:StopCalls=0
$script:StartCalls=0
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){$null=@($Prompt,$DefaultNo);$true}
function Stop-Service {
    [CmdletBinding()] param([string]$Name,[switch]$Force)
    $null=$Force
    if($Name -ne 'Spooler'){throw 'Unexpected service'}
    $script:StopCalls++
    if($script:StopFails){Write-Error 'synthetic stop failure';return}
    $script:SpoolerState='Stopped'
}
function Start-Service {
    [CmdletBinding()] param([string]$Name)
    if($Name -ne 'Spooler'){throw 'Unexpected service'}
    $script:StartCalls++
    if($script:StartFails){Write-Error 'synthetic start failure';return}
    $script:SpoolerState='Running'
}
function Get-Service {
    param([string]$Name)
    if($Name -ne 'Spooler'){throw 'Unexpected service'}
    [pscustomobject]@{Name='Spooler';Status=$script:SpoolerState}
}
function Test-Path {
    param([string]$LiteralPath,[System.Management.Automation.SwitchParameter]$PathType)
    $null=@($LiteralPath,$PathType)
    $true
}
function Get-ChildItem {
    param([string]$LiteralPath,[switch]$Force)
    $null=@($LiteralPath,$Force)
    @($script:QueueEntries | ForEach-Object {[pscustomobject]@{FullName=('C:\queue\'+$_)}})
}
function Remove-Item {
    [CmdletBinding()] param([string]$LiteralPath,[switch]$Force,[switch]$Recurse)
    $null=@($Force,$Recurse)
    if($script:DeleteFails){Write-Error 'synthetic delete failure';return}
    $leaf=Split-Path -Leaf $LiteralPath
    $script:QueueEntries=@($script:QueueEntries | Where-Object {$_ -ne $leaf})
}
function Reset-QueueHarness {
    Reset-Messages
    $script:QueueEntries=@('job1.spl','job2.shd')
    $script:SpoolerState='Running'
    $script:StopFails=$false
    $script:StartFails=$false
    $script:DeleteFails=$false
    $script:StopCalls=0
    $script:StartCalls=0
}

# Queue success.
Reset-QueueHarness
Invoke-ClearPrintQueue
if($script:Ok.Count -ne 1 -or $script:Fail.Count -ne 0){throw 'Successful queue cleanup did not report success.'}
if($script:QueueEntries.Count -ne 0 -or $script:SpoolerState -ne 'Running'){throw 'Successful queue cleanup did not clear files and restore Spooler.'}
if($script:StopCalls -ne 1 -or $script:StartCalls -ne 1){throw 'Successful queue cleanup service call count is wrong.'}

# Stop failure: deletion must not run, recovery start still attempted, no OK.
Reset-QueueHarness
$script:StopFails=$true
Invoke-ClearPrintQueue
if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Spooler stop failure produced a false success or no failure.'}
if($script:QueueEntries.Count -ne 2){throw 'Queue files were touched after Spooler stop failed.'}
if($script:StartCalls -ne 1){throw 'Spooler recovery was not attempted after stop failure.'}

# Delete failure: restart still attempted, no OK.
Reset-QueueHarness
$script:DeleteFails=$true
Invoke-ClearPrintQueue
if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Queue delete failure produced a false success or no failure.'}
if($script:StartCalls -ne 1 -or $script:SpoolerState -ne 'Running'){throw 'Spooler recovery failed after queue delete error.'}

# Restart failure: no OK and failure reported.
Reset-QueueHarness
$script:StartFails=$true
Invoke-ClearPrintQueue
if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Spooler restart failure produced a false success or no failure.'}
if($script:StartCalls -ne 1){throw 'Spooler restart failure path did not attempt restart exactly once.'}

Write-Host 'Repair-outcome smoke passed: firewall, Network Discovery, and queue cleanup never report OK when mocked Windows operations fail.' -ForegroundColor Green