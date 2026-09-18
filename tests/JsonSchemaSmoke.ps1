param([switch]$RequireValidator)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$schemaFile = Join-Path $repo 'docs\diagnosis.schema.json'
if(-not(Test-Path -LiteralPath $schemaFile)){throw 'Formal diagnosis JSON Schema is missing.'}

$schemaText=Get-Content -LiteralPath $schemaFile -Raw
$schema=$schemaText|ConvertFrom-Json
$schemaUri=$schema.PSObject.Properties['$schema'].Value
$schemaId=$schema.PSObject.Properties['$id'].Value
if($schemaUri -ne 'https://json-schema.org/draft/2020-12/schema'){throw 'Unexpected JSON Schema dialect.'}
if(-not $schemaId){throw 'JSON Schema must declare a stable $id.'}

$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'FixPrinter.ps1 must parse before JSON Schema smoke.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))

$temp=Join-Path $env:TEMP ('wpsf-schema-smoke-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force|Out-Null
$script:Version='4.1.0-smoke'
$script:Language='EN'
$script:ExportRoot=$temp
$script:CurrentLog=Join-Path $temp 'schema-smoke.log'
$script:LastTargetPathDiagnostic=$null
$script:LastFunctionalVerification=$null

function Write-Payload([object]$Payload,[string]$Name){
    $path=Join-Path $temp $Name
    $Payload|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

try {
    $diagnostic=Invoke-Diagnosis -Quiet
    $basePayload=ConvertTo-DiagnosticExportObject $diagnostic $null $null
    $basePath=Write-Payload $basePayload 'base.json'

    $target=[pscustomobject]@{
        TestedAtUtc='2026-09-18T00:00:00Z';DnsResolved=$true;Smb445Reachable=$true;Rpc135Reachable=$true;
        RpcConfiguredPort=55000;RpcConfiguredPortReachable=$true;ShareNamespaceAccessible=$true;
        PrinterInstalled=$true;SmbSecuritySignals=@('SigningOrEncryptionCompatibility');LikelyLayer='HealthyPrerequisites'
    }
    $verification=[pscustomobject]@{
        VerifiedAtUtc='2026-09-18T00:05:00Z';DiagnosticCollectedAtUtc=[string]$diagnostic.CollectedAtUtc;
        RequestStatus='Submitted';Outcome='Printed';NetworkConnection=$true;DriverModel='V3';
        DriverProviderClass='ThirdParty';DriverTechnology='OtherOrUnknown'
    }
    $fullPayload=ConvertTo-DiagnosticExportObject $diagnostic $target $verification
    $fullPath=Write-Payload $fullPayload 'full.json'

    $fallback=($basePayload|ConvertTo-Json -Depth 10|ConvertFrom-Json)
    $fallback.Windows.Revision=$null
    $fallback.Windows.FullBuild=[string]$fallback.Windows.Build
    $fallbackPath=Write-Payload $fallback 'revision-null.json'

    $pwsh=Get-Command pwsh -ErrorAction SilentlyContinue
    if(-not $pwsh){
        if($RequireValidator){throw 'PowerShell 7.4+ (pwsh) is required for Draft 2020-12 schema validation in CI.'}
        Write-Warning 'pwsh not found; schema structure parsed but Draft 2020-12 instance validation was skipped.'
        return
    }

    $versionText=& $pwsh.Source -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    $majorMinor=[version]$versionText
    if($majorMinor -lt [version]'7.4'){
        if($RequireValidator){throw "PowerShell 7.4+ is required for schema validation; found $versionText."}
        Write-Warning "pwsh $versionText found; Draft 2020-12 instance validation was skipped."
        return
    }

    foreach($jsonPath in @($basePath,$fullPath,$fallbackPath)){
        $escapedJson=$jsonPath.Replace("'","''")
        $escapedSchema=$schemaFile.Replace("'","''")
        $command="if(-not(Test-Json -LiteralPath '$escapedJson' -SchemaFile '$escapedSchema' -ErrorAction Stop)){exit 2}"
        & $pwsh.Source -NoProfile -Command $command
        if($LASTEXITCODE -ne 0){throw "JSON payload failed formal schema validation: $jsonPath"}
    }

    $invalid=($basePayload|ConvertTo-Json -Depth 10|ConvertFrom-Json)
    $invalid.SchemaVersion=2
    $invalidPath=Write-Payload $invalid 'invalid-schema-version.json'
    $escapedInvalid=$invalidPath.Replace("'","''")
    $escapedSchema=$schemaFile.Replace("'","''")
    $negative="if(Test-Json -LiteralPath '$escapedInvalid' -SchemaFile '$escapedSchema' -ErrorAction SilentlyContinue){exit 2}else{exit 0}"
    & $pwsh.Source -NoProfile -Command $negative
    if($LASTEXITCODE -ne 0){throw 'Formal schema did not reject an invalid SchemaVersion.'}

    Write-Host 'JSON Schema smoke passed: base, populated optional objects, nullable revision, and negative version validation are stable.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
