$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
if (-not (Test-Path -LiteralPath $scriptFile)) { throw 'FixPrinter.ps1 is missing.' }

# Load function definitions without executing FixPrinter.ps1's interactive entry point.
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'FixPrinter.ps1 must parse before runtime smoke testing.' }

$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
if ($functions.Count -lt 20) { throw "Unexpectedly few v4 functions were discovered: $($functions.Count)" }
$functionSource = ($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"
. ([scriptblock]::Create($functionSource))

# Minimal script-scoped state required by the diagnostic functions.
$script:Version = '4.2.0-smoke'
$script:Language = 'EN'
$script:CurrentLog = Join-Path $env:TEMP ('windows-printer-fix-smoke-{0}.log' -f [Guid]::NewGuid().ToString('N'))
$script:LastDiagnostic = $null

function Get-ReadOnlyFingerprint {
    $registry = @(Get-ManagedRegistryEntries | Sort-Object Path,Name | ForEach-Object {
        [pscustomobject]@{Path=$_.Path;Name=$_.Name;Present=$_.Present;Value=$_.Value;Kind=$_.Kind}
    })
    $profiles = @(Get-NetworkProfilesSafe | Sort-Object InterfaceIndex | ForEach-Object {
        [pscustomobject]@{InterfaceIndex=$_.InterfaceIndex;NetworkCategory=[string]$_.NetworkCategory}
    })
    $firewall = @(Get-FirewallSharingRules | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{Name=$_.Name;Enabled=[string]$_.Enabled;Profile=[string]$_.Profile}
    })
    return [pscustomobject]@{
        Registry=$registry
        NetworkProfiles=$profiles
        FirewallRules=$firewall
        SMB1Client=(Get-WindowsFeatureState 'SMB1Protocol-Client')
    } | ConvertTo-Json -Depth 8 -Compress
}

$before = Get-ReadOnlyFingerprint
$script:LastFunctionalVerification=[pscustomobject]@{Outcome='Printed'}
$diagnostic = Invoke-Diagnosis -Quiet
if($null -ne $script:LastFunctionalVerification){throw 'A fresh diagnosis must clear stale functional-verification state.'}
$after = Get-ReadOnlyFingerprint

if ($before -ne $after) {
    throw 'Diagnosis-only execution changed managed Windows state. Diagnose must remain read-only.'
}

if ($null -eq $diagnostic) { throw 'Invoke-Diagnosis returned no result.' }
if ($diagnostic.OS.Build -le 0) { throw "Invalid Windows build detected: $($diagnostic.OS.Build)" }
if(-not $diagnostic.OS.FullBuild -or [string]$diagnostic.OS.FullBuild -notmatch ('^'+[regex]::Escape([string]$diagnostic.OS.Build)+'(?:\.\d+)?$')){throw "Invalid Windows full build detected: $($diagnostic.OS.FullBuild)"}
$ubr=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).UBR
if($null -ne $ubr -and ([int]$diagnostic.OS.Revision -ne [int]$ubr -or [string]$diagnostic.OS.FullBuild -ne ("{0}.{1}" -f $diagnostic.OS.Build,[int]$ubr))){throw 'Runtime diagnosis did not preserve the exact Windows UBR/full build.'}
if (-not $diagnostic.OS.Name) { throw 'Windows name was not detected.' }
if (-not $diagnostic.Role) { throw 'Host/client role classification returned an empty value.' }
if ($null -eq $diagnostic.Findings) { throw 'Diagnostic findings collection is missing.' }
if ($null -eq $diagnostic.Printers) { throw 'Printer inventory collection is missing.' }
if ($null -eq $diagnostic.Profiles) { throw 'Network profile collection is missing.' }
$allowedDriverModels=@('V3','V4','Unknown');$allowedDriverProviders=@('MicrosoftProvided','ThirdParty','Unknown');$allowedDriverTechnologies=@('MicrosoftIppClassDriver','UniversalPrintClassDriver','OtherOrUnknown')
foreach($printer in @($diagnostic.Printers)){
    if([string]$printer.DriverModel -notin $allowedDriverModels){throw "Unexpected printer driver model: $($printer.DriverModel)"}
    if([string]$printer.DriverProviderClass -notin $allowedDriverProviders){throw "Unexpected printer driver provider class: $($printer.DriverProviderClass)"}
    if([string]$printer.DriverTechnology -notin $allowedDriverTechnologies){throw "Unexpected printer driver technology: $($printer.DriverTechnology)"}
}
if ($null -eq $diagnostic.WPP) { throw 'WPP state object is missing.' }
if ($null -eq $diagnostic.WppReadiness) { throw 'WPP readiness evidence is missing.' }
$allowedWppReadiness=@('NoInstalledPrinters','WindowsReadyPrintBindingsOnly','ThirdPartyDriverDependenciesPresent','MixedOrUnknown')
if([string]$diagnostic.WppReadiness.LocalBindingState -notin $allowedWppReadiness){throw "Unexpected WPP readiness state: $($diagnostic.WppReadiness.LocalBindingState)"}
if([int]$diagnostic.WppReadiness.TotalBindings -ne @($diagnostic.Printers).Count){throw 'WPP readiness total does not match installed printer bindings.'}
if(($diagnostic.WppReadiness.KnownWindowsReadyPrintBindings+$diagnostic.WppReadiness.ThirdPartyDriverBindings+$diagnostic.WppReadiness.UnknownOrOtherBindings) -ne $diagnostic.WppReadiness.TotalBindings){throw 'WPP readiness bucket counts are inconsistent.'}
if($diagnostic.WppReadiness.DeviceCompatibilityProven){throw 'WPP readiness must never claim physical-device compatibility.'}
$expectedWppOsSupport=($diagnostic.OS.Build -ge 26100 -and -not $diagnostic.OS.IsServer)
if([bool]$diagnostic.WppReadiness.OsSupportsWpp -ne [bool]$expectedWppOsSupport){throw 'WPP OS support evidence is inconsistent with Windows build/server state.'}
if([bool]$diagnostic.WppReadiness.WppEnabled -ne [bool]$diagnostic.WPP.Enabled){throw 'WPP readiness lost current WPP enabled state.'}
if ($null -eq $diagnostic.SmbSecurity -or $null -eq $diagnostic.SmbSecurity.Client -or $null -eq $diagnostic.SmbSecurity.Server) { throw 'Modern SMB security posture is missing.' }
if ($diagnostic.SmbSecurity.Client.Available -and $null -eq $diagnostic.SmbSecurity.Client.RequireSigning) { throw 'Available SMB client posture lost signing state.' }
if ($null -eq $diagnostic.PolicySources) { throw 'Printer policy source evidence is missing.' }
$allowedPolicySources=@('LocalGroupPolicy','GroupPolicy','PossibleMdmOrOtherPolicy','RegistryOnlyOrUnknownSource','NotConfigured')
foreach($property in $diagnostic.PolicySources.PSObject.Properties){
    if([string]$property.Value.Source -notin $allowedPolicySources){throw "Unexpected printer policy source label: $($property.Value.Source)"}
}
$next=Get-NextInvestigation $diagnostic $null
if($null -eq $next -or $next.RootCauseClaimed){throw 'Next-layer correlation is missing or claimed root cause.'}
if($diagnostic.Spooler -and [string]$diagnostic.Spooler.Status -eq 'Running' -and $next.Layer -ne 'RemoteTransportUntested'){throw 'Healthy local diagnosis without target test must keep remote transport explicitly untested.'}
foreach($printEvent in @($diagnostic.PrintErrors)){
    if(-not $printEvent.Category){throw 'PrintService event classification is missing from a runtime event.'}
}
if (-not $diagnostic.CollectedAtUtc) { throw 'Diagnosis collection timestamp is missing.' }
if ($null -eq $diagnostic.TimingMs -or $diagnostic.TimingMs.Total -lt 0) { throw 'Diagnosis timing object is missing.' }
if ($diagnostic.TimingMs.PolicySources -lt 0) { throw 'Policy-source timing metadata is invalid.' }
if ($diagnostic.TimingMs.PrinterDrivers -lt 0) { throw 'Printer-driver timing metadata is invalid.' }
if ($diagnostic.TimingMs.SmbSecurity -lt 0) { throw 'SMB-security timing metadata is invalid.' }

$timingLog = Get-Content -LiteralPath $script:CurrentLog -Raw
if ($timingLog -notmatch 'Diagnosis timing ms:') { throw 'Diagnosis performance timing was not written to the runtime log.' }

Write-Host ('Runtime smoke passed on {0} build {1}.' -f $diagnostic.OS.Name,$diagnostic.OS.FullBuild) -ForegroundColor Green
Write-Host ('Spooler: {0}; printers: {1}; network profiles: {2}; findings: {3}.' -f $(if($diagnostic.Spooler){$diagnostic.Spooler.Status}else{'Missing'}),$diagnostic.Printers.Count,$diagnostic.Profiles.Count,$diagnostic.Findings.Count)
Write-Host 'Diagnosis-only state fingerprint was unchanged.' -ForegroundColor Green

Remove-Item -LiteralPath $script:CurrentLog -Force -ErrorAction SilentlyContinue
