$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before Network/SMB1 Restore contract smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$temp=Join-Path $env:TEMP ('wpsf-network-smb-contract-'+[Guid]::NewGuid().ToString('N'))
$script:BackupRoot=Join-Path $temp 'backups'
$script:LatestStateFile=Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog=Join-Path $temp 'network-smb-contract.log'
$script:Version='4.2.0'
$script:Language='EN'
$script:FeatureState='Disabled'
$script:CurrentNetworkCategory='Private'
$script:FailMessages=@()
$script:InfoMessages=@()
New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null

function L([string]$English,[string]$Indonesian){$English}
function Write-Fail([string]$Text){$script:FailMessages+=$Text}
function Write-Warn([string]$Text){}
function Write-Ok([string]$Text){}
function Write-Info([string]$Text){$script:InfoMessages+=$Text}
function Write-Log([string]$Message,[string]$Level='INFO'){$null=@($Message,$Level)}
function Get-ManagedRegistryEntries{@()}
function Get-FirewallSharingRules{@()}
function Get-NetworkProfilesSafe{@([pscustomobject]@{InterfaceIndex=7;NetworkCategory=$script:CurrentNetworkCategory;InterfaceAlias='Ethernet'})}
function Get-WindowsFeatureState([string]$Name){$null=$Name;$script:FeatureState}

function Read-State([string]$Directory){Get-Content -LiteralPath (Join-Path $Directory 'managed-state.json') -Raw|ConvertFrom-Json}
function Write-TamperedSnapshot([string]$Leaf,[string]$Reason,[string[]]$Scopes,[object[]]$Networks,[object[]]$Features){
    $dir=Join-Path $script:BackupRoot $Leaf
    New-Item -ItemType Directory -Path $dir -Force|Out-Null
    $state=[pscustomobject]@{Version='4.2.0';Created='2026-09-19T00:00:00Z';Reason=$Reason;Scopes=@($Scopes);Registry=@();Services=@();NetworkProfiles=@($Networks);FirewallRules=@();WindowsFeatures=@($Features)}
    $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Encoding UTF8
    return $dir
}
function Assert-Rejected([string]$Directory,[string]$Label){
    $accepted=$false
    try{[void](Get-ValidatedRestoreSnapshot $Directory);$accepted=$true}catch{$null=$_.Exception.Message}
    if($accepted){throw "$Label was accepted by Restore validation."}
}

try {
    # Valid selected-network action baseline is exactly Public.
    $public=[pscustomobject]@{InterfaceIndex=7;NetworkCategory='Public';InterfaceAlias='Ethernet'}
    $dir=New-RestoreSnapshot 'Change selected network profile' @('Network') -NetworkProfiles @($public)
    if(-not $dir){throw 'Valid Public network baseline failed snapshot creation.'}
    $state=Read-State $dir
    if(@($state.NetworkProfiles).Count -ne 1 -or [string]$state.NetworkProfiles[0].NetworkCategory -ne 'Public'){throw 'Valid Public network snapshot state is incorrect.'}
    [void](Get-ValidatedRestoreSnapshot $dir)

    # Private/DomainAuthenticated baselines are no-op or policy-owned and must not be snapshotted.
    foreach($category in @('Private','DomainAuthenticated')){
        'previous-pointer'|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
        $before=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
        $bad=New-RestoreSnapshot 'Change selected network profile' @('Network') -NetworkProfiles @([pscustomobject]@{InterfaceIndex=7;NetworkCategory=$category;InterfaceAlias='Ethernet'})
        $after=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
        $pointer=([string](Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1)).Trim()
        if($bad){throw "Network baseline $category unexpectedly created a snapshot."}
        if($after -ne $before){throw "Rejected network baseline $category left an orphan snapshot."}
        if($pointer -ne 'previous-pointer'){throw "Rejected network baseline $category replaced Restore history."}
    }

    # Tampered network action snapshots with impossible baseline state are rejected.
    $private=Write-TamperedSnapshot '20260919-151000-aaaaaa' 'Change selected network profile' @('Network') @([pscustomobject]@{InterfaceIndex=7;NetworkCategory='Private'}) @()
    Assert-Rejected $private 'Private network action baseline'
    $domain=Write-TamperedSnapshot '20260919-151001-bbbbbb' 'Change selected network profile' @('Network') @([pscustomobject]@{InterfaceIndex=7;NetworkCategory='DomainAuthenticated'}) @()
    Assert-Rejected $domain 'DomainAuthenticated network action baseline'

    # Valid SMB1 legacy baseline is exactly Disabled.
    $script:FeatureState='Disabled'
    $dir=New-RestoreSnapshot 'Enable SMB1 client' @('SMB1')
    if(-not $dir){throw 'Valid Disabled SMB1 baseline failed snapshot creation.'}
    $state=Read-State $dir
    if(@($state.WindowsFeatures).Count -ne 1 -or [string]$state.WindowsFeatures[0].State -ne 'Disabled'){throw 'Valid SMB1 snapshot baseline is incorrect.'}
    [void](Get-ValidatedRestoreSnapshot $dir)

    # Every other observed Windows feature state lacks an exact rollback contract for this action.
    $unsupported=@('Enabled','EnablePending','Unknown','DisablePending','Superseded','PartiallyInstalled','DisabledWithPayloadRemoved')
    foreach($featureState in $unsupported){
        $script:FeatureState=$featureState
        'previous-pointer'|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
        $before=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
        $bad=New-RestoreSnapshot 'Enable SMB1 client' @('SMB1')
        $after=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
        $pointer=([string](Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1)).Trim()
        if($bad){throw "Unsupported SMB1 baseline $featureState unexpectedly created a snapshot."}
        if($after -ne $before){throw "Rejected SMB1 baseline $featureState left an orphan snapshot."}
        if($pointer -ne 'previous-pointer'){throw "Rejected SMB1 baseline $featureState replaced Restore history."}
    }

    # Tampered SMB1 snapshots with non-Disabled baseline are rejected.
    $i=0
    foreach($featureState in $unsupported){
        $i++
        $leaf=('20260919-152{0:00}-abcdef' -f $i)
        $snap=Write-TamperedSnapshot $leaf 'Enable SMB1 client' @('SMB1') @() @([pscustomobject]@{Name='SMB1Protocol-Client';State=$featureState})
        Assert-Rejected $snap "SMB1 baseline $featureState"
    }

    # Legacy execution: Enabled/EnablePending are no-op; all other non-Disabled baselines abort before snapshot/mutation.
    $script:SnapshotCalls=0
    $script:FeatureEnableCalls=0
    function Read-Host([string]$Prompt){$null=$Prompt;'LEGACY'}
    function New-RestoreSnapshot{param([string]$Reason,[string[]]$Scopes);$null=@($Reason,$Scopes);$script:SnapshotCalls++;'synthetic-snapshot'}
    function Enable-WindowsOptionalFeature{[CmdletBinding()]param([switch]$Online,[string]$FeatureName,[switch]$NoRestart);$null=@($Online,$FeatureName,$NoRestart);$script:FeatureEnableCalls++}
    foreach($featureState in $unsupported){
        $script:FeatureState=$featureState
        $script:SnapshotCalls=0
        $script:FeatureEnableCalls=0
        $script:FailMessages=@()
        $script:InfoMessages=@()
        Enable-Smb1ClientLegacy
        if($script:SnapshotCalls -ne 0 -or $script:FeatureEnableCalls -ne 0){throw "Legacy SMB1 action mutated or snapshotted unsupported baseline $featureState."}
        if($featureState -notin @('Enabled','EnablePending') -and -not $script:FailMessages.Count){throw "Legacy SMB1 action did not fail unsupported baseline $featureState."}
    }

    Write-Host 'Network/SMB1 Restore contract smoke passed: selected-network baseline is Public-only and SMB1 legacy baseline is exactly Disabled.' -ForegroundColor Green
} finally {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}