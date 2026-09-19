$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before firewall Restore contract smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$temp=Join-Path $env:TEMP ('wpsf-firewall-contract-'+[Guid]::NewGuid().ToString('N'))
$script:BackupRoot=Join-Path $temp 'backups'
$script:LatestStateFile=Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog=Join-Path $temp 'firewall-contract.log'
$script:Version='4.2.0'
$script:Language='EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null

$script:FailMessages=@()
function L([string]$English,[string]$Indonesian){$English}
function Write-Fail([string]$Text){$script:FailMessages+=$Text}
function Write-Warn([string]$Text){}
function Write-Ok([string]$Text){}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){$null=@($Message,$Level)}
function Get-ManagedRegistryEntries{@()}
function Get-NetworkProfilesSafe{@()}
function Get-FirewallSharingRules{
    @(
      [pscustomobject]@{Name='FPS-Private';Enabled='False';Profile='Private'},
      [pscustomobject]@{Name='FPS-Public';Enabled='False';Profile='Public'}
    )
}

function Write-Snapshot([string]$Leaf,[string]$Reason,[string[]]$Scopes,[object[]]$Services,[object[]]$Rules){
    $dir=Join-Path $script:BackupRoot $Leaf
    New-Item -ItemType Directory -Path $dir -Force|Out-Null
    $state=[pscustomobject]@{
      Version='4.2.0';Created='2026-09-19T00:00:00Z';Reason=$Reason;Scopes=@($Scopes);
      Registry=@();Services=@($Services);NetworkProfiles=@();FirewallRules=@($Rules);WindowsFeatures=@()
    }
    $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Encoding UTF8
    return $dir
}
function Assert-Rejected([string]$Directory,[string]$Label){
    $accepted=$false
    try{[void](Get-ValidatedRestoreSnapshot $Directory);$accepted=$true}catch{$null=$_.Exception.Message}
    if($accepted){throw "$Label was accepted by Restore validation."}
}

try {
    # Snapshot creation: Public-only input filters to zero eligible rules and must fail transactionally.
    'previous-pointer'|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    $before=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
    $bad=New-RestoreSnapshot 'Enable sharing firewall rules' @('Firewall') -FirewallRules @([pscustomobject]@{Name='FPS-Public';Enabled='False';Profile='Public'})
    $after=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
    $pointer=([string](Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1)).Trim()
    if($bad){throw 'Public-only firewall action unexpectedly created a snapshot.'}
    if($after -ne $before){throw 'Rejected Public-only firewall snapshot left an orphan directory.'}
    if($pointer -ne 'previous-pointer'){throw 'Rejected Public-only firewall snapshot replaced Restore history.'}

    # Empty firewall-only tampered snapshot must be rejected.
    $empty=Write-Snapshot '20260919-141000-aaaaaa' 'Enable sharing firewall rules' @('Firewall') @() @()
    Assert-Rejected $empty 'Empty firewall-only snapshot'

    # Public-only firewall-only tampered snapshot must be rejected.
    $public=Write-Snapshot '20260919-141001-bbbbbb' 'Enable sharing firewall rules' @('Firewall') @() @([pscustomobject]@{Name='FPS-Public';Enabled='False';Profile='Public'})
    Assert-Rejected $public 'Public-only firewall snapshot'

    # Public-only state is also outside combined Safe Repair mutation scope.
    $combinedPublic=Write-Snapshot '20260919-141002-cccccc' 'Combined non-destructive Safe Repair' @('Services','Firewall') @([pscustomobject]@{Name='Spooler';State='Running'}) @([pscustomobject]@{Name='FPS-Public';Enabled='False';Profile='Public'})
    Assert-Rejected $combinedPublic 'Combined Public-only firewall snapshot'

    # A valid firewall repair snapshot remains accepted.
    $valid=Write-Snapshot '20260919-141003-dddddd' 'Enable sharing firewall rules' @('Firewall') @() @([pscustomobject]@{Name='FPS-Private';Enabled='False';Profile='Private'})
    [void](Get-ValidatedRestoreSnapshot $valid)

    Write-Host 'Firewall Restore contract smoke passed: empty/Public-only action state is rejected while valid Private/Domain repair state remains accepted.' -ForegroundColor Green
} finally {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}