$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=Split-Path -Parent $PSScriptRoot
$main=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($main,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Main PowerShell source failed to parse.'}
$defs=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($defs|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))
$script:Status='Running'
$script:Consent=$true
$script:ChoiceDefault=$null
$script:Stops=0;$script:Starts=0
$script:StopThrows=$false
$script:Warnings=@();$script:Infos=@();$script:Successes=@();$script:Failures=@();$script:Prompts=0
function L([string]$English,[string]$Indonesian){$null=$Indonesian;return $English}
function Write-Warn([string]$Message){$script:Warnings+= $Message}
function Write-Info([string]$Message){$script:Infos+= $Message}
function Write-Ok([string]$Message){$script:Successes+= $Message}
function Write-Fail([string]$Message){$script:Failures+= $Message}
function Write-Log([string]$Message,[string]$Level='INFO'){$null=@($Message,$Level)}
function Write-Header([string]$Message){$null=$Message}
function Pause-Tui {}
function Read-YesNo([string]$Message,[bool]$Default){$null=$Message;$script:Prompts++;$script:ChoiceDefault=$Default;return $script:Consent}
function Get-Service {
    [CmdletBinding()]param([string]$Name)
    if($Name -ne 'Spooler'){throw 'Unexpected service name.'}
    return [pscustomobject]@{Name=$Name;Status=$script:Status}
}
function Stop-Service {
    [CmdletBinding()]param([string]$Name,[switch]$Force)
    if($Name -ne 'Spooler'){throw 'Unexpected Stop-Service target.'}
    if(-not $Force){throw 'Mock Stop-Service expected -Force.'}
    $script:Stops++
    $script:Status='Stopped'
    if($script:StopThrows){throw 'Synthetic service-stop failure after status transition.'}
}
function Start-Service {
    [CmdletBinding()]param([string]$Name)
    if($Name -ne 'Spooler'){throw 'Unexpected Start-Service target.'}
    $script:Starts++
    $script:Status='Running'
}
function Get-EffectiveSpoolDirectory {return $script:QueueRoot}
function Reset-Mock([string]$Initial,[bool]$Yes=$true){
    $script:Status=$Initial;$script:Consent=$Yes;$script:Stops=0;$script:Starts=0;$script:StopThrows=$false
    $script:Warnings=@();$script:Infos=@();$script:Successes=@();$script:Failures=@();$script:Prompts=0;$script:ChoiceDefault=$null
}
$temp=Join-Path $env:TEMP ('wpsf-queue-gate-'+[guid]::NewGuid().ToString('N'))
$script:QueueRoot=Join-Path $temp 'spool'
New-Item -ItemType Directory -Path $script:QueueRoot -Force|Out-Null
try{
    # Running baseline: only SPL/SHD files are deleted; unrelated files survive.
    Reset-Mock 'Running'
    Set-Content -LiteralPath (Join-Path $script:QueueRoot 'one.SPL') 'test'
    Set-Content -LiteralPath (Join-Path $script:QueueRoot 'one.SHD') 'test'
    Set-Content -LiteralPath (Join-Path $script:QueueRoot 'keep.txt') 'keep'
    Invoke-ClearPrintQueue
    if($script:Status -ne 'Running' -or $script:Stops -ne 1 -or $script:Starts -ne 1){throw 'Running Spooler baseline was not preserved.'}
    if($script:ChoiceDefault -ne $true -or $script:Prompts -ne 1){throw 'Queue cleanup consent was not explicit default-No.'}
    if(@(Get-ChildItem $script:QueueRoot -Filter '*.SPL').Count -or @(Get-ChildItem $script:QueueRoot -Filter '*.SHD').Count){throw 'Spool files remained after successful cleanup.'}
    if(-not(Test-Path -LiteralPath (Join-Path $script:QueueRoot 'keep.txt'))){throw 'Non-spool file was deleted.'}
    if($script:Failures.Count -or $script:Successes.Count -ne 1){throw 'Running baseline cleanup status is incorrect.'}

    # Security-managed Stopped baseline must not be enabled just because cleanup ran.
    Reset-Mock 'Stopped'
    Set-Content -LiteralPath (Join-Path $script:QueueRoot 'two.SPL') 'test'
    Invoke-ClearPrintQueue
    if($script:Status -ne 'Stopped' -or $script:Stops -or $script:Starts){throw 'Stopped Spooler baseline was altered.'}
    if(Test-Path -LiteralPath (Join-Path $script:QueueRoot 'two.SPL')){throw 'Stopped queue was not cleaned.'}

    # The user declining must not touch service or spool files.
    Reset-Mock 'Running' $false
    Set-Content -LiteralPath (Join-Path $script:QueueRoot 'three.SHD') 'test'
    Invoke-ClearPrintQueue
    if($script:Stops -or $script:Starts -or $script:Successes.Count -or -not(Test-Path -LiteralPath (Join-Path $script:QueueRoot 'three.SHD'))){throw 'Declined queue cleanup had side effects.'}

    # A synthetic stop failure after state transition still restores Running and preserves job files.
    Reset-Mock 'Running'
    $script:StopThrows=$true
    Invoke-ClearPrintQueue
    if($script:Status -ne 'Running' -or $script:Starts -ne 1 -or $script:Failures.Count -ne 1){throw 'Failed stop did not attempt safe recovery.'}
    if(-not(Test-Path -LiteralPath (Join-Path $script:QueueRoot 'three.SHD'))){throw 'Stop failure still deleted a queued job.'}

    # A validated security emergency blocks further repairs but does not block read-only diagnosis.
    $script:BackupRoot=Join-Path $temp 'backups'
    New-Item -ItemType Directory -Path $script:BackupRoot -Force|Out-Null
    $script:LatestStateFile=Join-Path $script:BackupRoot 'latest_backup.txt'
    $pending=Join-Path $script:BackupRoot '20261105-010000-abcdef'
    New-Item -ItemType Directory -Path $pending -Force|Out-Null
    $pending|Set-Content -LiteralPath (Get-PendingPointAndPrintMarkerPath)
    $script:SavedPolicy=1;$script:CurrentPolicy=0
    function Get-ValidatedRestoreSnapshot([string]$Directory){
        if($Directory -ne $pending){throw 'Unsupported synthetic emergency snapshot.'}
        return [pscustomobject]@{Directory=$Directory;State=[pscustomobject]@{Reason='Temporary Point and Print relaxation';Registry=@([pscustomobject]@{Name='RestrictDriverInstallationToAdministrators';Path='HKLM:\Test';Present=$true;Kind='DWord';Value=$script:SavedPolicy})}}
    }
    function Get-RegistryValueStateStrict([string]$Path,[string]$Name){$null=@($Path,$Name);return [pscustomobject]@{Present=$true;Kind='DWord';Value=$script:CurrentPolicy}}
    if(-not(Test-PointAndPrintRecoveryRequired)){throw 'Pending security mismatch was not detected.'}
    if(Test-RepairAllowedAfterRecovery){throw 'Repair permitted during a security emergency.'}
    if(-not $script:Failures.Count){throw 'Security emergency did not produce a clear warning.'}
    $script:CurrentPolicy=1
    if(Test-PointAndPrintRecoveryRequired){throw 'Recovered policy baseline remained blocked.'}
    Remove-Item -LiteralPath (Get-PendingPointAndPrintMarkerPath) -Force
    $pending|Set-Content -LiteralPath (Get-PendingPointAndPrintMarkerPath)
    function Get-ValidatedRestoreSnapshot([string]$Directory){$null=$Directory;throw 'Simulated corrupted emergency snapshot.'}
    if(-not(Test-PointAndPrintRecoveryRequired)){throw 'Unverifiable emergency marker did not fail closed.'}

    # All entry menus must consult the recovery guard at action selection.
    foreach($menu in @('Show-MainMenu','Show-SafeRepairMenu','Show-CompatibilityMenu','Show-LegacyMenu')){
        $func=@($defs|Where-Object{$_.Name -eq $menu})|Select-Object -First 1
        if(-not $func -or $func.Extent.Text -notmatch 'Test-RepairAllowedAfterRecovery'){throw "Menu $menu bypasses the recovery gate."}
    }
    $restore=@($defs|Where-Object{$_.Name -eq 'Invoke-RestoreLatest'})|Select-Object -First 1
    if(-not $restore -or $restore.Extent.Text -notmatch 'Test-PointAndPrintRecoveryRequired'){throw 'Historical Restore does not enforce the emergency boundary.'}
    Write-Host 'Queue baseline and Point and Print recovery-gate smoke passed.' -ForegroundColor Green
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
