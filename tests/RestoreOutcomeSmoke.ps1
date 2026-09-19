$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before restore-outcome smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join ([Environment]::NewLine + [Environment]::NewLine)))

$script:Language='EN'
$script:Ok=@()
$script:Warn=@()
$script:Fail=@()
$script:Logs=@()
function L([string]$English,[string]$Indonesian){$English}
function Write-Header([string]$Text){}
function Write-Ok([string]$Text){$script:Ok += $Text}
function Write-Warn([string]$Text){$script:Warn += $Text}
function Write-Fail([string]$Text){$script:Fail += $Text}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){$script:Logs += ($Level+':'+$Message)}
function Pause-Tui{}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){$null=@($Prompt,$DefaultNo);$true}
function Reset-Messages {$script:Ok=@();$script:Warn=@();$script:Fail=@();$script:Logs=@()}

# Helpers must surface underlying failures.
$script:RegistryPresent=$true
function Get-RegistryValueStateStrict([string]$Path,[string]$Name){$null=@($Path,$Name);[pscustomobject]@{Present=$script:RegistryPresent;Value=1;Kind='DWord'}}
function Remove-ItemProperty {[CmdletBinding()]param([string]$Path,[string]$Name);$null=@($Path,$Name);Write-Error 'synthetic registry removal failure'}
$registryThrew=$false
try{Restore-RegistryValue ([pscustomobject]@{Path='HKLM:\X';Name='Y';Present=$false;Value=$null;Kind=$null})}catch{$registryThrew=$true}
if(-not $registryThrew){throw 'Restore-RegistryValue swallowed a registry removal failure.'}


# Coordinator harness.
$temp=Join-Path $env:TEMP ('wpsf-restore-outcome-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$script:LatestStateFile=Join-Path $temp 'latest_backup.txt'
'dummy' | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
$script:CurrentState=$null
$script:RegistryCalls=0
$script:FirewallCalls=0
$script:NetworkCalls=0
$script:FeatureEnableCalls=0
$script:FeatureDisableCalls=0
$script:SetServiceCalls=0
$script:ServiceStartCalls=0
$script:ServiceStopCalls=0
$script:FirewallFails=$false
$script:NetworkFails=$false
$script:FirewallNoOp=$false
$script:NetworkNoOp=$false
$script:FirewallEnabled='True'
$script:FirewallProfile='Private'
$script:NetworkCategory='Private'
$script:FeatureFails=$false
$script:ServiceStartFails=$false
$script:FeatureState='Enabled'
$script:ServiceState='Stopped'

function Get-ValidatedRestoreSnapshot([string]$Directory){$null=$Directory;[pscustomobject]@{Directory=$temp;State=$script:CurrentState}}
function Restore-RegistryValue($Entry){$null=$Entry;$script:RegistryCalls++}
function Set-NetFirewallRule {
    [CmdletBinding()] param([string]$Name,$Enabled,[Alias('Profile')]$FirewallProfile)
    $null=$Name
    $script:FirewallCalls++
    if($script:FirewallFails){Write-Error 'synthetic restore firewall failure';return}
    if(-not $script:FirewallNoOp){
        $script:FirewallEnabled=[string]$Enabled
        $script:FirewallProfile=[string]$FirewallProfile
    }
}
function Get-NetFirewallRule {
    [CmdletBinding()] param([string]$Name)
    $null=$Name
    [pscustomobject]@{Name='FPS-Test';Enabled=$script:FirewallEnabled;Profile=$script:FirewallProfile}
}
function Set-NetConnectionProfile {
    [CmdletBinding()] param([int]$InterfaceIndex,[string]$NetworkCategory)
    $null=$InterfaceIndex
    $script:NetworkCalls++
    if($script:NetworkFails){Write-Error 'synthetic restore network failure';return}
    if(-not $script:NetworkNoOp){$script:NetworkCategory=[string]$NetworkCategory}
}
function Get-NetConnectionProfile {
    [CmdletBinding()] param([int]$InterfaceIndex)
    $null=$InterfaceIndex
    [pscustomobject]@{InterfaceIndex=7;NetworkCategory=$script:NetworkCategory}
}
function Get-WindowsFeatureState([string]$Name){$null=$Name;$script:FeatureState}
function Enable-WindowsOptionalFeature {
    [CmdletBinding()] param([switch]$Online,[string]$FeatureName,[switch]$NoRestart)
    $null=@($Online,$FeatureName,$NoRestart)
    $script:FeatureEnableCalls++
    if($script:FeatureFails){Write-Error 'synthetic feature enable failure';return}
    $script:FeatureState='Enabled'
}
function Disable-WindowsOptionalFeature {
    [CmdletBinding()] param([switch]$Online,[string]$FeatureName,[switch]$NoRestart)
    $null=@($Online,$FeatureName,$NoRestart)
    $script:FeatureDisableCalls++
    if($script:FeatureFails){Write-Error 'synthetic feature disable failure';return}
    $script:FeatureState='Disabled'
}
function Set-Service {
    [CmdletBinding()] param([string]$Name,[string]$StartupType)
    $null=@($Name,$StartupType)
    $script:SetServiceCalls++
}
function Start-Service {
    [CmdletBinding()] param([string]$Name)
    $null=$Name
    $script:ServiceStartCalls++
    if($script:ServiceStartFails){Write-Error 'synthetic service start failure';return}
    $script:ServiceState='Running'
}
function Stop-Service {
    [CmdletBinding()] param([string]$Name,[switch]$Force)
    $null=@($Name,$Force)
    $script:ServiceStopCalls++
    $script:ServiceState='Stopped'
}
function Get-Service {
    [CmdletBinding()] param([string]$Name)
    $null=$Name
    [pscustomobject]@{Name='Spooler';Status=$script:ServiceState}
}

function New-RestoreState {
    [pscustomobject]@{
      Registry=@([pscustomobject]@{Path='HKLM:\X';Name='Y';Present=$true;Value=1;Kind='DWord'});
      FirewallRules=@([pscustomobject]@{Name='FPS-Test';Enabled='False';Profile='Private'});
      NetworkProfiles=@([pscustomobject]@{InterfaceIndex=7;NetworkCategory='Public'});
      WindowsFeatures=@([pscustomobject]@{Name='SMB1Protocol-Client';State='Disabled'});
      Services=@([pscustomobject]@{Name='Spooler';StartMode='Manual';State='Running'})
    }
}
function Reset-Harness {
    Reset-Messages
    $script:RegistryCalls=0;$script:FirewallCalls=0;$script:NetworkCalls=0
    $script:FeatureEnableCalls=0;$script:FeatureDisableCalls=0
    $script:SetServiceCalls=0;$script:ServiceStartCalls=0;$script:ServiceStopCalls=0
    $script:FirewallFails=$false;$script:NetworkFails=$false;$script:FeatureFails=$false;$script:ServiceStartFails=$false
    $script:FirewallNoOp=$false;$script:NetworkNoOp=$false
    $script:FirewallEnabled='True';$script:FirewallProfile='Private';$script:NetworkCategory='Private'
    $script:FeatureState='Enabled';$script:ServiceState='Stopped'
    $script:CurrentState=New-RestoreState
}

try {
    # Full success.
    Reset-Harness
    Invoke-RestoreLatest
    if($script:Ok.Count -ne 1 -or $script:Fail.Count -ne 0){throw 'Successful managed Restore did not report exactly one success.'}
    if($script:RegistryCalls -ne 1 -or $script:FirewallCalls -ne 1 -or $script:NetworkCalls -ne 1 -or $script:FeatureDisableCalls -ne 1 -or $script:SetServiceCalls -ne 0 -or $script:ServiceStartCalls -ne 1){throw 'Successful managed Restore did not execute every expected category or attempted unrelated service startup-mode mutation.'}
    if($script:FeatureState -ne 'Disabled' -or $script:ServiceState -ne 'Running'){throw 'Successful managed Restore did not reach expected final state.'}

    # Firewall failure must not prevent later categories from being attempted.
    Reset-Harness
    $script:FirewallFails=$true
    Invoke-RestoreLatest
    if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Partial Restore failure produced false success or no failure.'}
    if($script:RegistryCalls -ne 1 -or $script:FirewallCalls -ne 1 -or $script:NetworkCalls -ne 1 -or $script:FeatureDisableCalls -ne 1 -or $script:ServiceStartCalls -ne 1){throw 'Restore stopped instead of attempting remaining categories after firewall failure.'}

    # Successful/no-op firewall command must be rejected by read-back.
    Reset-Harness
    $script:FirewallNoOp=$true
    Invoke-RestoreLatest
    if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Firewall restore no-op produced false success or no failure.'}
    if($script:NetworkCalls -ne 1 -or $script:FeatureDisableCalls -ne 1 -or $script:ServiceStartCalls -ne 1){throw 'Firewall no-op prevented later restore categories from being attempted.'}

    # Successful/no-op network command must be rejected by read-back.
    Reset-Harness
    $script:NetworkNoOp=$true
    Invoke-RestoreLatest
    if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Network restore no-op produced false success or no failure.'}

    # Service start failure must be reported after all earlier categories complete.
    Reset-Harness
    $script:ServiceStartFails=$true
    Invoke-RestoreLatest
    if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Service restore failure produced false success or no failure.'}
    if($script:RegistryCalls -ne 1 -or $script:FirewallCalls -ne 1 -or $script:NetworkCalls -ne 1 -or $script:FeatureDisableCalls -ne 1 -or $script:ServiceStartCalls -ne 1){throw 'Service failure scenario skipped expected restore categories.'}

    # Feature command failure must suppress success.
    Reset-Harness
    $script:FeatureFails=$true
    Invoke-RestoreLatest
    if($script:Ok.Count -ne 0 -or $script:Fail.Count -ne 1){throw 'Feature restore failure produced false success or no failure.'}

    Write-Host 'Restore-outcome smoke passed: managed Restore reports success only after every requested category succeeds, while partial failures still attempt remaining state.' -ForegroundColor Green
}
finally {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}