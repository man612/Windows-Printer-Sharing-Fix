$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before PrintService classification smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"))

$categoryCases = @(
    @{Id=215;Expected='DriverOrPackage'},
    @{Id=315;Expected='SharingOrConnection'},
    @{Id=359;Expected='DriverOrPackage'},
    @{Id=372;Expected='PrintJob'},
    @{Id=808;Expected='DriverOrPackage'},
    @{Id=851;Expected='Policy'},
    @{Id=871;Expected='Policy'},
    @{Id=9999;Expected='OtherPrintService'}
)
foreach($case in $categoryCases){
    $actual=(Get-PrintServiceEventClassification $case.Id).Category
    if($actual -ne $case.Expected){throw "Event $($case.Id) classified as $actual, expected $($case.Expected)."}
}
$codeCases = @(
    @{Code=0;Expected='AmbiguousSuccessCode'},
    @{Code=2;Expected='FileOrSpoolPath'},
    @{Code=5;Expected='AccessOrPermission'},
    @{Code=53;Expected='NetworkPathOrName'},
    @{Code=62;Expected='QueueOrSpool'},
    @{Code=1722;Expected='Rpc'},
    @{Code=1726;Expected='Rpc'},
    @{Code=1801;Expected='PrinterOrDriverState'},
    @{Code=3012;Expected='PrinterOrDriverState'},
    @{Code=424242;Expected='OtherWin32'}
)
foreach($case in $codeCases){
    $actual=Get-PrintServiceWin32CodeClass $case.Code
    if($actual -ne $case.Expected){throw "Win32 code $($case.Code) classified as $actual, expected $($case.Expected)."}
}
if($null -ne (Get-PrintServiceWin32CodeClass $null)){throw 'Null Win32 code must stay unclassified.'}

$props=@(0..10|ForEach-Object{[pscustomobject]@{Value=$null}})
$props[9]=[pscustomobject]@{Value=1726}
$fake372=[pscustomobject]@{Id=372;Properties=$props}
if((Get-PrintServiceEventWin32Code $fake372) -ne 1726){throw 'Event 372 Win32 code extraction failed.'}
$fake215=[pscustomobject]@{Id=215;Properties=$props}
if($null -ne (Get-PrintServiceEventWin32Code $fake215)){throw 'Non-372 events must not reuse the 372 property position.'}
function Get-WinEvent {
    param($FilterHashtable,$MaxEvents)
    $null=$FilterHashtable;$null=$MaxEvents
    $p372=@(0..10|ForEach-Object{[pscustomobject]@{Value=$null}})
    $p372[9]=[pscustomobject]@{Value=67}
    return @(
        [pscustomobject]@{TimeCreated=Get-Date;Id=372;LevelDisplayName='Error';Message='synthetic print failure';Properties=$p372},
        [pscustomobject]@{TimeCreated=Get-Date;Id=9999;LevelDisplayName='Warning';Message='synthetic unknown event';Properties=@()}
    )
}
$events=@(Get-RecentPrintErrors)
if($events.Count -ne 2){throw 'Synthetic Get-RecentPrintErrors fixture did not return two events.'}
if($events[0].Category -ne 'PrintJob' -or $events[0].Win32Code -ne 67 -or $events[0].CodeClass -ne 'NetworkPathOrName'){
    throw 'Event 372 normalization did not preserve the expected category/code class.'
}
if($events[1].Category -ne 'OtherPrintService' -or $null -ne $events[1].Win32Code){
    throw 'Unknown PrintService event should stay OtherPrintService without a fabricated Win32 code.'
}

Write-Host 'PrintService classification smoke passed: event layers and conservative Win32 code classes are stable.' -ForegroundColor Green
