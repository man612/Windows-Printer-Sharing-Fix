$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before driver-classification smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join "`r`n`r`n"))

function New-Printer([string]$DriverName){[pscustomobject]@{Name='Synthetic';DriverName=$DriverName;PortName='PORT';Shared=$false;ShareName='';Type='Local';ComputerName=$null}}
function New-Driver([string]$Name,[int]$Major,[string]$Provider,[string]$Manufacturer=$null){[pscustomobject]@{Name=$Name;MajorVersion=$Major;provider=$Provider;Manufacturer=$Manufacturer;InfPath='C:\synthetic.inf';IsPackageAware=$true;PrinterEnvironment='Windows x64'}}

$drivers=@(
    (New-Driver 'Microsoft IPP Class Driver' 4 'Microsoft'),
    (New-Driver 'Universal Print Class Driver' 4 'Microsoft'),
    (New-Driver 'Vendor V4 Driver' 4 'VendorCo'),
    (New-Driver 'Vendor V3 Driver' 3 'VendorCo'),
    (New-Driver 'Metadata Missing' 3 '' '')
)
$cases=@(
    @('Microsoft IPP Class Driver','V4','MicrosoftProvided','MicrosoftIppClassDriver'),
    @('Universal Print Class Driver','V4','MicrosoftProvided','UniversalPrintClassDriver'),
    @('Vendor V4 Driver','V4','ThirdParty','OtherOrUnknown'),
    @('Vendor V3 Driver','V3','ThirdParty','OtherOrUnknown'),
    @('Metadata Missing','V3','Unknown','OtherOrUnknown'),
    @('No Metadata','Unknown','Unknown','OtherOrUnknown')
)
foreach($case in $cases){
    $r=Get-PrinterDriverClassification (New-Printer $case[0]) $drivers
    if($r.DriverModel -ne $case[1] -or $r.ProviderClass -ne $case[2] -or $r.Technology -ne $case[3]){throw "Unexpected classification for $($case[0]): $($r|ConvertTo-Json -Compress)"}
}

$fake=@(New-Driver 'Microsoft IPP Class Driver Fake' 4 'VendorCo')
$r=Get-PrinterDriverClassification (New-Printer 'Microsoft IPP Class Driver Fake') $fake
if($r.Technology -ne 'OtherOrUnknown' -or $r.ProviderClass -ne 'ThirdParty'){throw 'Name-like third-party driver was misclassified as Microsoft IPP.'}

$conflict=@((New-Driver 'Conflicted' 3 'VendorCo'),(New-Driver 'Conflicted' 4 'VendorCo'))
$r=Get-PrinterDriverClassification (New-Printer 'Conflicted') $conflict
if($r.DriverModel -ne 'Unknown'){throw 'Conflicting driver-model metadata must remain Unknown.'}
$printers=@(
    (New-Printer 'Vendor V3 Driver'),
    (New-Printer 'Vendor V4 Driver'),
    (New-Printer 'Metadata Missing'),
    (New-Printer 'Microsoft IPP Class Driver')
)
$classed=@(Add-PrinterDriverClassifications $printers $drivers)
$summary=Get-PrinterDriverClassificationSummary $classed
if($summary.Total -ne 4 -or $summary.V3 -ne 2 -or $summary.V4 -ne 2){throw 'Driver-model summary counts are wrong.'}
if($summary.ThirdParty -ne 2 -or $summary.MicrosoftProvided -ne 1 -or $summary.ProviderUnknown -ne 1){throw 'Driver-provider summary counts are wrong.'}
if($summary.MicrosoftIppClassDriver -ne 1){throw 'Microsoft IPP class-driver summary count is wrong.'}
if(@($classed|Where-Object{$_.$null}).Count){throw 'Classification produced an invalid property access.'}

Write-Host 'Driver-classification smoke passed: v3/v4, provider evidence, exact class drivers, unknowns, and conflicts are conservative.' -ForegroundColor Green
