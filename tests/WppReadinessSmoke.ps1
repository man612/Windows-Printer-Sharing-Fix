$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before WPP readiness smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

function New-PrinterBinding([string]$Provider,[string]$Technology,[string]$Model='Unknown'){
    [pscustomobject]@{DriverProviderClass=$Provider;DriverTechnology=$Technology;DriverModel=$Model}
}

$client=[pscustomobject]@{Build=26100;IsServer=$false}
$server=[pscustomobject]@{Build=26100;IsServer=$true}
$wppOff=[pscustomobject]@{Enabled=$false}
$wppOn=[pscustomobject]@{Enabled=$true}

$ready=@(
    New-PrinterBinding 'MicrosoftProvided' 'MicrosoftIppClassDriver' 'V4'
    New-PrinterBinding 'MicrosoftProvided' 'UniversalPrintClassDriver' 'V4'
)
$r=Get-WppReadinessEvidence $client $wppOff $ready
if(-not $r.OsSupportsWpp -or $r.WppEnabled){throw 'Supported-client/WPP state normalization failed.'}
if($r.LocalBindingState -ne 'WindowsReadyPrintBindingsOnly' -or $r.TotalBindings -ne 2 -or $r.KnownWindowsReadyPrintBindings -ne 2 -or $r.ThirdPartyDriverBindings -ne 0 -or $r.UnknownOrOtherBindings -ne 0){throw 'Ready Print-only classification failed.'}
if($r.MicrosoftIppClassDriverBindings -ne 1 -or $r.UniversalPrintClassDriverBindings -ne 1){throw 'Known Ready Print technology counts failed.'}
if($r.DeviceCompatibilityProven){throw 'Local readiness evidence must never claim device compatibility.'}
$mixed=@(
    New-PrinterBinding 'MicrosoftProvided' 'MicrosoftIppClassDriver' 'V4'
    New-PrinterBinding 'ThirdParty' 'OtherOrUnknown' 'V3'
    New-PrinterBinding 'Unknown' 'OtherOrUnknown' 'Unknown'
)
$r=Get-WppReadinessEvidence $client $wppOff $mixed
if($r.LocalBindingState -ne 'ThirdPartyDriverDependenciesPresent' -or $r.KnownWindowsReadyPrintBindings -ne 1 -or $r.ThirdPartyDriverBindings -ne 1 -or $r.UnknownOrOtherBindings -ne 1){throw 'Third-party dependency classification failed.'}

$unknown=@(
    New-PrinterBinding 'MicrosoftProvided' 'OtherOrUnknown' 'V4'
    New-PrinterBinding 'Unknown' 'OtherOrUnknown' 'Unknown'
)
$r=Get-WppReadinessEvidence $client $wppOff $unknown
if($r.LocalBindingState -ne 'MixedOrUnknown' -or $r.UnknownOrOtherBindings -ne 2){throw 'Mixed/unknown classification failed.'}

$empty=Get-WppReadinessEvidence $client $wppOff @()
if($empty.LocalBindingState -ne 'NoInstalledPrinters' -or $empty.TotalBindings -ne 0){throw 'No-printer classification failed.'}

$unsupported=Get-WppReadinessEvidence $server $wppOff $ready
if($unsupported.OsSupportsWpp){throw 'Windows Server must not be marked as WPP-supported from build number alone.'}

$enabled=Get-WppReadinessEvidence $client $wppOn $mixed
if(-not $enabled.WppEnabled){throw 'Enabled WPP state was not preserved.'}

$conflict=@(New-PrinterBinding 'ThirdParty' 'MicrosoftIppClassDriver' 'V3')
$r=Get-WppReadinessEvidence $client $wppOff $conflict
if($r.KnownWindowsReadyPrintBindings -ne 0 -or $r.ThirdPartyDriverBindings -ne 1 -or $r.UnknownOrOtherBindings -ne 0){throw 'Conflicting synthetic metadata was double-counted as Ready Print.'}

foreach($sample in @($ready,$mixed,$unknown,$conflict)){
    $x=Get-WppReadinessEvidence $client $wppOff $sample
    if(($x.KnownWindowsReadyPrintBindings+$x.ThirdPartyDriverBindings+$x.UnknownOrOtherBindings) -ne $x.TotalBindings){throw 'WPP readiness bucket counts do not sum to TotalBindings.'}
}

Write-Host 'WPP readiness smoke passed: Ready Print, third-party, unknown, unsupported-OS, and conflict boundaries are conservative.' -ForegroundColor Green
