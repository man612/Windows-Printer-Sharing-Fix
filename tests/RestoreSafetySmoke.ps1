$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before restore-safety smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join ([Environment]::NewLine + [Environment]::NewLine)))

$temp = Join-Path $env:TEMP ('wpsf-restore-safety-' + [Guid]::NewGuid().ToString('N'))
$script:BackupRoot = Join-Path $temp 'backups'
$script:LatestStateFile = Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog = Join-Path $temp 'restore-safety.log'
$script:Language = 'EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null

function L([string]$English,[string]$Indonesian){$English}
function Write-Header([string]$Text){}
function Write-Warn([string]$Text){}
function Write-Fail([string]$Text){}
function Write-Ok([string]$Text){}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Pause-Tui{}
function Get-ManagedRegistryEntries([switch]$Strict) {
    $null=$Strict
    @([pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Print';Name='RpcAuthnLevelPrivacyEnabled';Present=$false;Value=$null;Kind=$null})
}
function Get-NetworkProfilesSafe {
    @([pscustomobject]@{InterfaceIndex=7;NetworkCategory='Private'})
}
function Get-FirewallSharingRules {
    @([pscustomobject]@{Name='FPS-Test';Enabled='False';Profile='Private'})
}

function New-State([string]$Reason,[string[]]$Scopes){
    [pscustomobject]@{
        Version='4.2.0';Created='2026-09-18T00:00:00.0000000Z';Reason=$Reason;Scopes=@($Scopes)
        Registry=@();Services=@();NetworkProfiles=@();FirewallRules=@();WindowsFeatures=@()
    }
}
function Write-Snapshot([string]$Directory,[object]$State){
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Directory 'managed-state.json') -Encoding UTF8
}
function Assert-Rejected([string]$Directory,[string]$Label){
    $accepted=$false
    try{[void](Get-ValidatedRestoreSnapshot $Directory);$accepted=$true}catch{$accepted=$false}
    if($accepted){throw "Unsafe restore snapshot was accepted: $Label"}
}

try {
    $validDir=Join-Path $script:BackupRoot '20260918-120000-abcdef'
    $valid=New-State 'Combined non-destructive Safe Repair' @('Services','Firewall')
    $valid.Services=@([pscustomobject]@{Name='Spooler';State='Stopped';StartMode='Manual'},[pscustomobject]@{Name='fdPHost';State='Running';StartMode='Manual'},[pscustomobject]@{Name='FDResPub';State='Running';StartMode='Manual'})
    $valid.FirewallRules=@([pscustomobject]@{Name='FPS-Test';Enabled='False';Profile='Private'})
    Write-Snapshot $validDir $valid
    $checked=Get-ValidatedRestoreSnapshot $validDir
    if($checked.Directory -ne [IO.Path]::GetFullPath($validDir)){throw 'Valid managed restore snapshot was not accepted.'}

    $outside=Join-Path $temp '20260918-120001-abcdef'
    Write-Snapshot $outside $valid
    Assert-Rejected $outside 'outside backup root'

    $registryDir=Join-Path $script:BackupRoot '20260918-120002-abcdef'
    $registry=New-State 'RPC Named Pipes compatibility fallback' @('Registry')
    $registry.Registry=@([pscustomobject]@{Path='HKLM:\SOFTWARE\TotallyUnmanaged';Name='Arbitrary';Present=$true;Value=1;Kind='DWord'})
    Write-Snapshot $registryDir $registry
    Assert-Rejected $registryDir 'unmanaged registry target'

    $serviceDir=Join-Path $script:BackupRoot '20260918-120003-abcdef'
    $service=New-State 'Restart Print Spooler' @('Services')
    $service.Services=@([pscustomobject]@{Name='ArbitraryService';State='Running';StartMode='Automatic'})
    Write-Snapshot $serviceDir $service
    Assert-Rejected $serviceDir 'unmanaged service target'

    $firewallDir=Join-Path $script:BackupRoot '20260918-120004-abcdef'
    $firewall=New-State 'Enable sharing firewall rules' @('Firewall')
    $firewall.FirewallRules=@([pscustomobject]@{Name='Unmanaged-Firewall-Rule';Enabled='True';Profile='Any'})
    Write-Snapshot $firewallDir $firewall
    Assert-Rejected $firewallDir 'unmanaged firewall rule'

    $networkDir=Join-Path $script:BackupRoot '20260918-120005-abcdef'
    $network=New-State 'Change selected network profile' @('Network')
    $network.NetworkProfiles=@([pscustomobject]@{InterfaceIndex=999;NetworkCategory='Public'})
    Write-Snapshot $networkDir $network
    Assert-Rejected $networkDir 'unavailable network profile'

    $scopeDir=Join-Path $script:BackupRoot '20260918-120006-abcdef'
    $scope=New-State 'Enable SMB1 client' @('Registry')
    Write-Snapshot $scopeDir $scope
    Assert-Rejected $scopeDir 'reason/scope mismatch'

    $script:MutationCount=0
    $script:PromptCount=0
    function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){$script:PromptCount++;return $true}
    function Restore-RegistryValue($Entry){$script:MutationCount++}
    function Restore-ServiceStartMode($Name,$Mode){$script:MutationCount++}
    function Set-NetFirewallRule{param($Name,$Enabled,[Alias('Profile')]$FirewallProfile,$ErrorAction);$null=@($Name,$Enabled,$FirewallProfile,$ErrorAction);$script:MutationCount++}
    function Set-NetConnectionProfile{param($InterfaceIndex,$NetworkCategory,$ErrorAction);$null=@($InterfaceIndex,$NetworkCategory,$ErrorAction);$script:MutationCount++}
    $registryDir | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    Invoke-RestoreLatest
    if($script:MutationCount -ne 0){throw 'Rejected restore snapshot reached a mutation function.'}
    if($script:PromptCount -ne 0){throw 'Rejected restore snapshot reached the confirmation prompt.'}

    Write-Host 'Restore-safety smoke passed: only managed in-root snapshots reach confirmation or mutation.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}