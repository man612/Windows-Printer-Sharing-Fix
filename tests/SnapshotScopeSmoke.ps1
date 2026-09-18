$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before snapshot-scope smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join ([Environment]::NewLine + [Environment]::NewLine)))

$temp = Join-Path $env:TEMP ('wpsf-snapshot-scope-' + [Guid]::NewGuid().ToString('N'))
$script:BackupRoot = Join-Path $temp 'backups'
$script:LatestStateFile = Join-Path $script:BackupRoot 'latest_backup.txt'
$script:CurrentLog = Join-Path $temp 'scope.log'
$script:Version = '4.2.0'
$script:Language = 'EN'
New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null

function L([string]$English,[string]$Indonesian){$English}
function Write-Fail([string]$Text){}
function Write-Warn([string]$Text){}
function Write-Ok([string]$Text){}
function Write-Info([string]$Text){}
function Write-Log([string]$Message,[string]$Level='INFO'){$null=@($Message,$Level)}
function Get-ManagedRegistryEntries {
    @(
        [pscustomobject]@{Path='P';Name='RpcAuthnLevelPrivacyEnabled';Present=$true;Value=1;Kind='DWord'},
        [pscustomobject]@{Path='P';Name='RpcUseNamedPipeProtocol';Present=$true;Value=0;Kind='DWord'},
        [pscustomobject]@{Path='P';Name='RpcProtocols';Present=$true;Value=0;Kind='DWord'},
        [pscustomobject]@{Path='P';Name='RestrictDriverInstallationToAdministrators';Present=$true;Value=1;Kind='DWord'},
        [pscustomobject]@{Path='P';Name='AllowInsecureGuestAuth';Present=$true;Value=0;Kind='DWord'},
        [pscustomobject]@{Path='P';Name='LmCompatibilityLevel';Present=$true;Value=3;Kind='DWord'},
        [pscustomobject]@{Path='P';Name='LimitBlankPasswordUse';Present=$true;Value=1;Kind='DWord'}
    )
}
function Get-CimInstance {
    param([string]$ClassName,[string]$Filter)
    $null=$ClassName
    $name=([regex]::Match($Filter,"Name='([^']+)'")).Groups[1].Value
    [pscustomobject]@{Name=$name;State='Running';StartMode='Manual'}
}
function Get-NetworkProfilesSafe {
    @(
      [pscustomobject]@{InterfaceIndex=7;NetworkCategory='Public';InterfaceAlias='Ethernet'},
      [pscustomobject]@{InterfaceIndex=8;NetworkCategory='Private';InterfaceAlias='Wi-Fi'}
    )
}
function Get-FirewallSharingRules {
    @(
      [pscustomobject]@{Name='FPS-Private';Enabled='False';Profile='Private'},
      [pscustomobject]@{Name='FPS-Domain';Enabled='False';Profile='Domain'},
      [pscustomobject]@{Name='FPS-Public';Enabled='False';Profile='Public'}
    )
}
function Get-WindowsFeatureState([string]$Name){$null=$Name;'Disabled'}

function Read-State([string]$Directory){
    Get-Content -LiteralPath (Join-Path $Directory 'managed-state.json') -Raw | ConvertFrom-Json
}
function Assert-Names([object[]]$Items,[string[]]$Expected,[string]$Label){
    $actual=@($Items | ForEach-Object {[string]$_.Name} | Sort-Object)
    $wanted=@($Expected | Sort-Object)
    if(($actual -join '|') -ne ($wanted -join '|')){throw "$Label scope mismatch. Actual=$($actual -join ',') Expected=$($wanted -join ',')"}
}

try {
    $cases=@(
      @('High-risk RPC privacy workaround',@('RpcAuthnLevelPrivacyEnabled')),
      @('RPC Named Pipes compatibility fallback',@('RpcProtocols','RpcUseNamedPipeProtocol')),
      @('Temporary Point and Print relaxation',@('RestrictDriverInstallationToAdministrators')),
      @('Enable insecure SMB guest',@('AllowInsecureGuestAuth')),
      @('Legacy LAN Manager level',@('LmCompatibilityLevel'))
    )
    foreach($case in $cases){
        $dir=New-RestoreSnapshot ([string]$case[0]) @('Registry')
        if(-not $dir){throw "Registry snapshot failed for $($case[0])"}
        $state=Read-State $dir
        Assert-Names @($state.Registry) @($case[1]) ([string]$case[0])
    }

    $dir=New-RestoreSnapshot 'Restart Print Spooler' @('Services')
    Assert-Names @((Read-State $dir).Services) @('Spooler') 'Restart Print Spooler'

    $dir=New-RestoreSnapshot 'Start Network Discovery services' @('Services')
    Assert-Names @((Read-State $dir).Services) @('fdPHost','FDResPub') 'Network Discovery services'

    $rules=@(Get-FirewallSharingRules)
    $dir=New-RestoreSnapshot 'Enable sharing firewall rules' @('Firewall') -FirewallRules $rules
    Assert-Names @((Read-State $dir).FirewallRules) @('FPS-Private','FPS-Domain') 'Firewall repair'

    $dir=New-RestoreSnapshot 'Combined non-destructive Safe Repair' @('Services','Firewall') -FirewallRules $rules
    $combined=Read-State $dir
    Assert-Names @($combined.Services) @('Spooler','fdPHost','FDResPub') 'Combined services'
    Assert-Names @($combined.FirewallRules) @('FPS-Private','FPS-Domain') 'Combined firewall'

    $selected=[pscustomobject]@{InterfaceIndex=7;NetworkCategory='Public';InterfaceAlias='Ethernet'}
    $dir=New-RestoreSnapshot 'Change selected network profile' @('Network') -NetworkProfiles @($selected)
    $network=Read-State $dir
    if(@($network.NetworkProfiles).Count -ne 1 -or [int]$network.NetworkProfiles[0].InterfaceIndex -ne 7){throw 'Selected-network snapshot captured more than the selected interface.'}

    $dir=New-RestoreSnapshot 'Enable SMB1 client' @('SMB1')
    Assert-Names @((Read-State $dir).WindowsFeatures) @('SMB1Protocol-Client') 'SMB1 client'

    $script:NetworkSetCalls=@()
    function Set-NetConnectionProfile {
        param([int]$InterfaceIndex,[string]$NetworkCategory)
        $script:NetworkSetCalls += [pscustomobject]@{InterfaceIndex=$InterfaceIndex;NetworkCategory=$NetworkCategory}
    }
    Set-OneNetworkPrivate -SelectedProfile $selected
    if($script:NetworkSetCalls.Count -ne 1 -or $script:NetworkSetCalls[0].InterfaceIndex -ne 7 -or $script:NetworkSetCalls[0].NetworkCategory -ne 'Private'){throw 'Selected-network repair did not mutate only the supplied interface.'}

    'previous-pointer' | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    $beforeDirs=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
    $bad=New-RestoreSnapshot 'Unknown registry action' @('Registry')
    $afterDirs=@(Get-ChildItem -LiteralPath $script:BackupRoot -Directory).Count
    $pointer=([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
    if($bad){throw 'Unknown action unexpectedly created a restore snapshot.'}
    if($afterDirs -ne $beforeDirs){throw 'Failed snapshot left an orphan directory.'}
    if($pointer -ne 'previous-pointer'){throw 'Failed snapshot replaced the previous latest pointer.'}

    Write-Host 'Snapshot-scope smoke passed: restore snapshots contain only action-specific state and failed capture is transactional.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}