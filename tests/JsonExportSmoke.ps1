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
$script:Version = '4.0.3-smoke'
$script:Language = 'EN'
$script:ExportRoot = $temp
$script:CurrentLog = Join-Path $temp 'smoke.log'
$script:LastDiagnostic = $null
$script:LastTargetPathDiagnostic = $null

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

    $script:LastTargetPathDiagnostic=[pscustomobject]@{TestedAtUtc='2026-09-16T00:00:00Z';DnsResolved=$true;Smb445Reachable=$true;Rpc135Reachable=$false;ShareNamespaceAccessible=$false;PrinterInstalled=$false;LikelyLayer='RpcReachability'}
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
    if($data.ToolVersion -ne '4.0.3-smoke'){throw 'JSON diagnosis export lost tool version metadata.'}
    if($data.Windows.Build -le 0 -or -not $data.Windows.Name){throw 'JSON diagnosis export is missing Windows identity.'}
    if($data.PrinterSummary.Total -ne @($diagnostic.Printers).Count){throw 'JSON printer summary does not match the reused diagnostic object.'}
    if($data.NetworkProfiles.Count -ne @($diagnostic.Profiles).Count){throw 'JSON network profile summary does not match diagnosis.'}
    if($data.TargetPath.LikelyLayer -ne 'RpcReachability' -or $data.TargetPath.Rpc135Reachable){throw 'Sanitized target-path result was not exported correctly.'}

    foreach($key in @('ComputerName','MachineName','UserName','Domain','IPAddress','SSID','PortName','ShareName','PrinterName','InterfaceAlias','Message')){
        if($jsonText -match ('"'+[regex]::Escape($key)+'"\s*:')){throw "JSON export exposes forbidden field: $key"}
    }
    $secrets=@($env:COMPUTERNAME,$env:USERNAME,$env:USERDOMAIN)
    try{$secrets += @(Get-Printer -ErrorAction Stop | ForEach-Object {$_.Name;$_.ShareName;$_.PortName;$_.ComputerName})}catch{}
    try{$secrets += @(Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {$_.Name;$_.InterfaceAlias})}catch{}
    foreach($secret in @($secrets | Where-Object {$_} | Select-Object -Unique)){
        if(([string]$secret).Length -ge 3 -and $jsonText -match [regex]::Escape([string]$secret)){throw "JSON export leaked an environment identifier: $secret"}
    }

    Write-Host ('JSON export smoke passed: schema v{0}, {1} printer(s), {2} network profile(s), cached diagnosis reused.' -f $data.SchemaVersion,$data.PrinterSummary.Total,$data.NetworkProfiles.Count) -ForegroundColor Green
    Write-Host 'Diagnosis + JSON export managed-state fingerprint was unchanged.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
