Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before test-page verification smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join "`r`n`r`n"))

$diagnosisFunction=@($functions|Where-Object{$_.Name -eq 'Invoke-Diagnosis'})[0].Extent.Text
if($diagnosisFunction -match 'Invoke-GuidedTestPageVerification|Invoke-PrintUiTestPageRequest'){
    throw 'Diagnosis must never trigger a real test-page request.'
}
$requestFunction=@($functions|Where-Object{$_.Name -eq 'Invoke-PrintUiTestPageRequest'})[0].Extent.Text
foreach($required in @('printui.dll,PrintUIEntry','/k','/n')){
    if($requestFunction -notmatch [regex]::Escape($required)){throw "PrintUI request is missing: $required"}
}

$script:Language='EN'
$script:CurrentLog=Join-Path $env:TEMP ('wpsf-test-page-smoke-'+[Guid]::NewGuid().ToString('N')+'.log')
$script:LastDiagnostic=[pscustomobject]@{CollectedAtUtc='2026-09-16T00:00:00Z'}
$script:LastFunctionalVerification=$null
function T([string]$Key){return $Key}
function Write-Header([string]$Title){Write-Output $Title}
function Get-PrinterInventory {
    return @([pscustomobject]@{Name='SYNTHETIC Network Printer';DriverName='Synthetic Driver';PortName='SYNTH';Shared=$false;ShareName=$null;Type='Connection';ComputerName='\\SYNTH'})
}
function Get-PrinterDriverMetadataSafe {
    return @([pscustomobject]@{Name='Synthetic Driver';MajorVersion=3;Provider='Synthetic Vendor';Manufacturer='Synthetic Vendor';InfPath='C:\SECRET\synthetic.inf';IsPackageAware=$true;PrinterEnvironment='Windows x64'})
}

$script:CapturedStart=$null
function Start-Process {
    [CmdletBinding()]
    param([string]$FilePath,[object[]]$ArgumentList,[switch]$Wait,[switch]$PassThru)
    $script:CapturedStart=[pscustomobject]@{FilePath=$FilePath;ArgumentList=@($ArgumentList);Wait=[bool]$Wait;PassThru=[bool]$PassThru}
    return [pscustomobject]@{ExitCode=0}
}
$request=Invoke-PrintUiTestPageRequest 'Synthetic Printer With Spaces'
if(-not $request.Submitted){throw 'Stubbed PrintUI request should report submitted.'}
if($script:CapturedStart.ArgumentList[0] -ne 'printui.dll,PrintUIEntry' -or $script:CapturedStart.ArgumentList[1] -ne '/k'){
    throw 'Guided verification did not compose the documented PrintUI test-page request.'
}
if($script:CapturedStart.ArgumentList[2] -ne '/n"Synthetic Printer With Spaces"'){
    throw "Unexpected printer argument: $($script:CapturedStart.ArgumentList[2])"
}
$script:ChoiceValues=@();$script:ChoiceIndex=0
$script:YesNoValues=@();$script:YesNoIndex=0
function Read-Choice([string]$Prompt,[string[]]$Allowed){
    if($script:ChoiceIndex -ge $script:ChoiceValues.Count){throw "Unexpected Read-Choice prompt: $Prompt"}
    $value=[string]$script:ChoiceValues[$script:ChoiceIndex];$script:ChoiceIndex++
    if($value -notin $Allowed){throw "Synthetic choice $value is not allowed for: $Prompt"}
    return $value
}
function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true){
    if($script:YesNoIndex -ge $script:YesNoValues.Count){throw "Unexpected Read-YesNo prompt: $Prompt"}
    $value=[bool]$script:YesNoValues[$script:YesNoIndex];$script:YesNoIndex++
    return $value
}

$script:RequestCount=0
function Invoke-PrintUiTestPageRequest([string]$PrinterName){$script:RequestCount++;return [pscustomobject]@{Submitted=$true;ExitCode=0}}
$script:ChoiceValues=@('1');$script:ChoiceIndex=0
$script:YesNoValues=@($false);$script:YesNoIndex=0
$script:LastFunctionalVerification=$null
Invoke-GuidedTestPageVerification | Out-Null
if($script:RequestCount -ne 0){throw 'Declining confirmation still invoked PrintUI.'}
if($null -ne $script:LastFunctionalVerification){throw 'Cancelled verification must not create a result record.'}
$script:RequestCount=0
$script:ChoiceValues=@('1','Y');$script:ChoiceIndex=0
$script:YesNoValues=@($true);$script:YesNoIndex=0
$script:LastFunctionalVerification=$null
Invoke-GuidedTestPageVerification | Out-Null
$result=$script:LastFunctionalVerification
if($script:RequestCount -ne 1 -or $null -eq $result){throw 'Confirmed verification did not submit exactly one request.'}
if($result.RequestStatus -ne 'Submitted' -or $result.Outcome -ne 'Printed'){
    throw 'User-confirmed physical print outcome was not recorded correctly.'
}
if(-not $result.NetworkConnection -or $result.DriverModel -ne 'V3' -or $result.DriverProviderClass -ne 'ThirdParty'){
    throw 'Functional verification lost normalized printer classification.'
}
$logText=Get-Content -LiteralPath $script:CurrentLog -Raw
foreach($secret in @('SYNTHETIC Network Printer','Synthetic Driver','Synthetic Vendor','C:\SECRET')){
    if($logText -match [regex]::Escape($secret)){throw "Verification log leaked printer metadata: $secret"}
}

$script:RequestCount=0
function Invoke-PrintUiTestPageRequest([string]$PrinterName){$script:RequestCount++;return [pscustomobject]@{Submitted=$false;ExitCode=5}}
$script:ChoiceValues=@('1');$script:ChoiceIndex=0
$script:YesNoValues=@($true);$script:YesNoIndex=0
$script:LastFunctionalVerification=$null
Invoke-GuidedTestPageVerification | Out-Null
if($script:RequestCount -ne 1 -or $script:LastFunctionalVerification.RequestStatus -ne 'Failed' -or $script:LastFunctionalVerification.Outcome -ne 'NotConfirmed'){
    throw 'Failed PrintUI request was not recorded conservatively.'
}
function Invoke-PrintUiTestPageRequest([string]$PrinterName){return [pscustomobject]@{Submitted=$true;ExitCode=0}}
$script:Language='ID'
$script:ChoiceValues=@('1','U');$script:ChoiceIndex=0
$script:YesNoValues=@($true);$script:YesNoIndex=0
$script:LastFunctionalVerification=$null
$idOutput=(& { Invoke-GuidedTestPageVerification } 6>&1 | Out-String)
foreach($expected in @('VERIFIKASI TEST PAGE TERPANDU','print job test page Windows sungguhan','bukan konfirmasi','belum terkonfirmasi')){
    if($idOutput -notmatch [regex]::Escape($expected)){throw "Indonesian guided verification output is missing: $expected"}
}
if($script:LastFunctionalVerification.Outcome -ne 'NotConfirmed'){throw 'Unsure physical result must remain NotConfirmed.'}

# The real request helper rejects quote-bearing names; this stub is only for guided-flow tests.
$realRequestFunction=[scriptblock]::Create((@($functions|Where-Object{$_.Name -eq 'Invoke-PrintUiTestPageRequest'})[0].Extent.Text))
. $realRequestFunction
$quoted=& (Get-Command Invoke-PrintUiTestPageRequest) 'Synthetic "Quoted" Printer'
if($quoted.Submitted){throw 'Quote-bearing printer names must be rejected before native argument construction.'}

Write-Host 'Test-page verification smoke passed: explicit opt-in, PrintUI composition, physical confirmation, privacy, and Indonesian UX are stable.' -ForegroundColor Green
Remove-Item -LiteralPath $script:CurrentLog -Force -ErrorAction SilentlyContinue
