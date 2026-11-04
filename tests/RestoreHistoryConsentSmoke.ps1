$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=Split-Path -Parent $PSScriptRoot
$source=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Invalid source syntax.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))
$script:Language='EN'
function L([string]$English,[string]$Indonesian){$English}
function Write-Header([string]$Name){}
function Write-Warn([string]$Message){}
function Write-Fail([string]$Message){}
function Write-Log([string]$Message,[string]$Level='INFO'){}
function Pause-Tui{}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){throw 'Ordinary restore confirmation must not execute after historical consent was denied.'}
$script:HistoryConsentRequests=0
function Read-Host([string]$Prompt){$script:HistoryConsentRequests++;return 'NO'}
$temp=Join-Path $env:TEMP ('wpsf-old-restore-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force|Out-Null
try{
    $script:LatestStateFile=Join-Path $temp 'latest_backup.txt'
    $current=Join-Path $temp 'latest'
    $older=Join-Path $temp 'older'
    $current|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8
    function Get-ValidatedRestoreSnapshot([string]$Directory){[pscustomobject]@{Directory=$Directory;State=[pscustomobject]@{Registry=@();FirewallRules=@();NetworkProfiles=@();WindowsFeatures=@();Services=@()}}}
    Invoke-RestoreLatest -SnapshotDirectory $older
    if($script:HistoryConsentRequests -ne 1){throw 'Older Restore snapshot was not protected by explicit typed confirmation.'}
    Write-Host 'Historical Restore consent smoke passed.' -ForegroundColor Green
}finally{Microsoft.PowerShell.Management\Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
