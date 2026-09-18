$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before JSON export smoke.'}
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"))

$temp = Join-Path $env:TEMP ('wpsf-json-export-smoke-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$script:Version = '4.1.0-smoke'
$script:Language = 'EN'
$script:ExportRoot = $temp
$script:CurrentLog = Join-Path $temp 'smoke.log'
$script:LastDiagnostic = $null
$script:LastTargetPathDiagnostic = $null
$script:LastFunctionalVerification = $null

function Get-ReadOnlyFingerprint {
    $registry = @(Get-ManagedRegistryEntries | Sort-Object Path,Name | Select-Object Path,Name,Present,Value,Kind)
    $profiles = @(Get-NetworkProfilesSafe | Sort-Object InterfaceIndex | Select-Object InterfaceIndex,NetworkCategory)
    $firewall = @(Get-FirewallSharingRules | Sort-Object Name | Select-Object Name,Enabled,Profile)
    $spooler = Get-Service Spooler -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Registry=$registry;NetworkProfiles=$profiles;FirewallRules=$firewall
        SMB1Client=(Get-WindowsFeatureState 'SMB1Protocol-Client')
        Spooler=if($spooler){[string]$spooler.Status}else{'Missing'}
    } | ConvertTo-Json -Depth 8 -Compress
}

try {
    $before = Get-ReadOnlyFingerprint
    $diagnostic = Invoke-Diagnosis -Quiet
    $afterDiagnosis = Get-ReadOnlyFingerprint
    if($before -ne $afterDiagnosis){throw 'Diagnosis changed managed Windows state.'}
    if(-not $diagnostic.CollectedAtUtc){throw 'Diagnosis did not expose CollectedAtUtc for export reuse.'}
    if($null -eq $diagnostic.TimingMs -or $diagnostic.TimingMs.Total -lt 0){throw 'Diagnosis timing metadata is missing.'}

    $script:LastTargetPathDiagnostic=[pscustomobject]@{TestedAtUtc='2026-09-16T00:00:00Z';DnsResolved=$true;Smb445Reachable=$true;Rpc135Reachable=$false;RpcConfiguredPort=55000;RpcConfiguredPortReachable=$false;ShareNamespaceAccessible=$false;PrinterInstalled=$false;SmbSecuritySignals=@('SigningOrEncryptionCompatibility');LikelyLayer='RpcReachability'}
    $script:LastFunctionalVerification=[pscustomobject]@{VerifiedAtUtc='2026-09-16T00:05:00Z';DiagnosticCollectedAtUtc=[string]$diagnostic.CollectedAtUtc;RequestStatus='Submitted';Outcome='Printed';NetworkConnection=$true;DriverModel='V3';DriverProviderClass='ThirdParty';DriverTechnology='OtherOrUnknown'}
    $firstPath = Join-Path $temp 'diagnosis-explicit.json'
    [void](Export-DiagnosticJson -Diagnostic $diagnostic -OutputPath $firstPath)
    if(-not(Test-Path -LiteralPath $firstPath)){throw 'Explicit diagnostic JSON export was not created.'}

    # Prove the cached export path does not invoke diagnosis again.
    function Invoke-Diagnosis { throw 'JSON export must reuse the cached diagnostic object instead of running diagnosis again.' }
    $cachedPath = Join-Path $temp 'diagnosis-cached.json'
    [void](Export-DiagnosticJson -OutputPath $cachedPath)
    if(-not(Test-Path -LiteralPath $cachedPath)){throw 'Cached diagnostic JSON export was not created.'}

    $afterExport = Get-ReadOnlyFingerprint
    if($before -ne $afterExport){throw 'JSON export changed managed Windows state.'}
    $jsonText = Get-Content -LiteralPath $cachedPath -Raw
    $data = $jsonText | ConvertFrom-Json
    if($data.Schema -ne 'windows-printer-sharing-fix/diagnosis' -or $data.SchemaVersion -ne 1){throw 'Unexpected JSON diagnosis schema identity/version.'}
    if(-not $data.Sanitized){throw 'JSON diagnosis export must declare itself sanitized.'}
    if($data.ToolVersion -ne '4.1.0-smoke'){throw 'JSON diagnosis export lost tool version metadata.'}
    if($data.Windows.Build -le 0 -or -not $data.Windows.Name){throw 'JSON diagnosis export is missing Windows identity.'}
    if(-not $data.Windows.FullBuild -or [string]$data.Windows.FullBuild -notmatch ('^'+[regex]::Escape([string]$data.Windows.Build)+'(?:\.\d+)?$')){throw 'JSON diagnosis export is missing normalized full-build metadata.'}
    if($null -ne $diagnostic.OS.Revision -and ([int]$data.Windows.Revision -ne [int]$diagnostic.OS.Revision -or [string]$data.Windows.FullBuild -ne [string]$diagnostic.OS.FullBuild)){throw 'JSON diagnosis export lost Windows build revision metadata.'}
    if($data.PrinterSummary.Total -ne @($diagnostic.Printers).Count){throw 'JSON printer summary does not match the reused diagnostic object.'}
    if($data.DriverSummary.TotalBindings -ne @($diagnostic.Printers).Count){throw 'JSON driver summary does not match printer bindings.'}
    if(($data.DriverSummary.Models.V3 + $data.DriverSummary.Models.V4 + $data.DriverSummary.Models.Unknown) -ne $data.DriverSummary.TotalBindings){throw 'JSON driver-model summary counts are inconsistent.'}
    if(($data.DriverSummary.Providers.MicrosoftProvided + $data.DriverSummary.Providers.ThirdParty + $data.DriverSummary.Providers.Unknown) -ne $data.DriverSummary.TotalBindings){throw 'JSON driver-provider summary counts are inconsistent.'}
    if($data.WppReadiness.TotalBindings -ne @($diagnostic.Printers).Count -or $data.WppReadiness.LocalBindingState -ne $diagnostic.WppReadiness.LocalBindingState){throw 'JSON WPP readiness summary does not match diagnosis.'}
    if(($data.WppReadiness.KnownWindowsReadyPrintBindings+$data.WppReadiness.ThirdPartyDriverBindings+$data.WppReadiness.UnknownOrOtherBindings) -ne $data.WppReadiness.TotalBindings){throw 'JSON WPP readiness bucket counts are inconsistent.'}
    if($data.WppReadiness.DeviceCompatibilityProven){throw 'JSON WPP readiness must never claim device compatibility.'}
    if($data.WppReadiness.EvidenceScope -ne 'InstalledPrinterBindingsOnly'){throw 'JSON WPP readiness evidence scope changed unexpectedly.'}
    if($data.NetworkProfiles.Count -ne @($diagnostic.Profiles).Count){throw 'JSON network profile summary does not match diagnosis.'}
    if($null -eq $data.SmbSecurity -or [bool]$data.SmbSecurity.Client.Available -ne [bool]$diagnostic.SmbSecurity.Client.Available){throw 'JSON SMB security posture does not match diagnosis.'}
    if($data.TargetPath.LikelyLayer -ne 'RpcReachability' -or $data.TargetPath.Rpc135Reachable){throw 'Sanitized target-path result was not exported correctly.'}
    if($data.TargetPath.RpcConfiguredPort -ne 55000 -or $data.TargetPath.RpcConfiguredPortReachable -or ($data.TargetPath.SmbSecuritySignals -join '|') -notmatch 'SigningOrEncryptionCompatibility'){throw 'Modern RPC/SMB target evidence was not exported correctly.'}
    if(-not($data.TargetPath.SmbSecuritySignals -is [System.Array])){throw 'Target-path SMB security signals must remain a JSON array even with one signal.'}
    if($data.NextInvestigation.Layer -ne 'RpcReachability' -or $data.NextInvestigation.Reason -ne 'TargetRpc135Failed' -or -not $data.NextInvestigation.RemoteTransportTested -or $data.NextInvestigation.RootCauseClaimed){throw 'Normalized next-layer correlation was not exported correctly.'}
    if($data.FunctionalVerification.RequestStatus -ne 'Submitted' -or $data.FunctionalVerification.Outcome -ne 'Printed' -or -not $data.FunctionalVerification.NetworkConnection -or $data.FunctionalVerification.DriverModel -ne 'V3' -or $data.FunctionalVerification.DriverProviderClass -ne 'ThirdParty'){throw 'Sanitized functional-verification record was not exported correctly.'}
    foreach($name in @('RpcPrivacy','RpcUseNamedPipe','RpcProtocols','RpcTcpPort','ForceKerberosForRpc','RemoteRpcEndpoint','PointAndPrint','WppGroupPolicy')){
        $actual=$data.PolicySources.PSObject.Properties[$name].Value
        $expected=$diagnostic.PolicySources.PSObject.Properties[$name].Value
        if($null -eq $actual -or $actual.Source -ne $expected.Source -or [bool]$actual.Configured -ne [bool]$expected.Configured){throw "Normalized policy-source evidence was not exported for $name."}
    }

    # Prove normalized PrintService metadata and policy-source labels survive export while raw identifiers do not.
    $cloneProps=@{}
    foreach($property in $diagnostic.PSObject.Properties){$cloneProps[$property.Name]=$property.Value}
    $cloneProps['PrintErrors']=@([pscustomobject]@{TimeCreated=(Get-Date);Id=372;LevelDisplayName='Error';Message='SECRET-PRINTER-NAME must never be exported';Category='PrintJob';Win32Code=1726;CodeClass='Rpc'})
    $cloneProps['Printers']=@([pscustomobject]@{Name='SECRET-PRINTER';DriverName='SECRET-DRIVER';PortName='SECRET-PORT';Shared=$false;ShareName='SECRET-SHARE';Type='Local';ComputerName=$null;DriverModel='V3';DriverProviderClass='ThirdParty';DriverTechnology='OtherOrUnknown';DriverEvidence='SECRET-PROVIDER-METADATA'})
    $cloneProps['SharedPrinters']=@();$cloneProps['Connections']=@()
    $cloneProps['PolicySources']=[pscustomobject]@{RpcPrivacy=[pscustomobject]@{Configured=$true;Source='GroupPolicy';Evidence='RsopRegistryPolicySetting';GpoId='SECRET-GPO-ID'}}
    $syntheticPayload=ConvertTo-DiagnosticExportObject ([pscustomobject]$cloneProps) $null
    $syntheticJson=$syntheticPayload|ConvertTo-Json -Depth 10
    $syntheticEvent=@($syntheticPayload.PrintServiceEvents)[0]
    if($syntheticEvent.Category -ne 'PrintJob' -or $syntheticEvent.Win32Code -ne 1726 -or $syntheticEvent.CodeClass -ne 'Rpc'){throw 'Normalized PrintService event metadata was not exported.'}
    if($syntheticPayload.PolicySources.RpcPrivacy.Source -ne 'GroupPolicy'){throw 'Normalized Group Policy source label was lost.'}
    if($syntheticPayload.DriverSummary.TotalBindings -ne 1 -or $syntheticPayload.DriverSummary.Models.V3 -ne 1 -or $syntheticPayload.DriverSummary.Providers.ThirdParty -ne 1){throw 'Normalized synthetic driver summary was not exported.'}
    if($syntheticPayload.WppReadiness.TotalBindings -ne 1 -or $syntheticPayload.WppReadiness.ThirdPartyDriverBindings -ne 1 -or $syntheticPayload.WppReadiness.LocalBindingState -ne 'ThirdPartyDriverDependenciesPresent'){throw 'Synthetic WPP readiness was not recomputed from the exported binding inventory.'}
    if($syntheticPayload.WppReadiness.DeviceCompatibilityProven){throw 'Synthetic WPP readiness claimed device compatibility.'}
    if(($syntheticPayload.NextInvestigation.Signals -join '|') -notmatch 'DriverInventory:ThirdPartyV3'){throw 'Normalized third-party v3 inventory signal was not preserved.'}
    if($syntheticJson -match 'SECRET-PRINTER-NAME'){throw 'Raw PrintService event message leaked into structured JSON.'}
    if($syntheticJson -match 'SECRET-GPO-ID'){throw 'Internal RSoP/GPO identifier leaked into structured JSON.'}
    if($syntheticJson -match 'SECRET-DRIVER|SECRET-PORT|SECRET-SHARE|SECRET-PROVIDER-METADATA|SECRET-PRINTER'){throw 'Raw printer/driver metadata leaked into structured JSON.'}
    if(($syntheticPayload.NextInvestigation.Signals -join '|') -match 'SECRET-PRINTER-NAME|SECRET-GPO-ID'){throw 'Raw identifiers leaked into next-layer supporting signals.'}
    if($syntheticPayload.NextInvestigation.RootCauseClaimed){throw 'Structured correlation must never claim root cause.'}

    foreach($key in @('ComputerName','MachineName','UserName','Domain','IPAddress','SSID','PortName','ShareName','PrinterName','DriverName','InfPath','Manufacturer','Provider','InterfaceAlias','Message','GpoId','SOMID','TenantId','MdmUrl','ProviderId','ManagementUrl')){
        if($jsonText -match ('"'+[regex]::Escape($key)+'"\s*:')){throw "JSON export exposes forbidden field: $key"}
    }
    function Get-JsonStringLeaves($Value) {
        if($null -eq $Value){return}
        if($Value -is [string]){Write-Output ([string]$Value);return}
        if($Value -is [System.Collections.IDictionary]){
            foreach($key in $Value.Keys){Get-JsonStringLeaves $Value[$key]}
            return
        }
        if($Value -is [System.Collections.IEnumerable]){
            foreach($item in $Value){Get-JsonStringLeaves $item}
            return
        }
        foreach($property in $Value.PSObject.Properties){Get-JsonStringLeaves $property.Value}
    }
    $leafStrings=@(Get-JsonStringLeaves $data)

    # Strong identifiers must not appear even embedded inside another exported value.
    $strongSecrets=@($env:COMPUTERNAME,$env:USERNAME,$env:USERDOMAIN)
    try{$strongSecrets += @(Get-NetIPAddress -ErrorAction Stop | Select-Object -ExpandProperty IPAddress)}catch{}
    foreach($secret in @($strongSecrets | Where-Object {$_} | Select-Object -Unique)){
        if(([string]$secret).Length -ge 3 -and @($leafStrings | Where-Object {$_ -match [regex]::Escape([string]$secret)}).Count){throw "JSON export leaked a strong environment identifier: $secret"}
    }

    # Printer/profile labels can be generic words (for example "Network"), so require exact leaf-value leakage.
    $labelSecrets=@()
    try{$labelSecrets += @(Get-Printer -ErrorAction Stop | ForEach-Object {$_.Name;$_.ShareName;$_.PortName;$_.ComputerName})}catch{}
    try{$labelSecrets += @(Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {$_.Name;$_.InterfaceAlias})}catch{}
    foreach($secret in @($labelSecrets | Where-Object {$_} | Select-Object -Unique)){
        if(@($leafStrings | Where-Object {$_ -eq [string]$secret}).Count){throw "JSON export leaked an environment label value: $secret"}
    }

    Write-Host ('JSON export smoke passed: schema v{0}, {1} printer(s), {2} network profile(s), cached diagnosis reused.' -f $data.SchemaVersion,$data.PrinterSummary.Total,$data.NetworkProfiles.Count) -ForegroundColor Green
    Write-Host 'Diagnosis + JSON export managed-state fingerprint was unchanged.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
