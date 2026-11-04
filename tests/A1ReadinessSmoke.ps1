$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=Split-Path -Parent $PSScriptRoot
$tool=Join-Path $repo 'tools\Test-A1Readiness.ps1'
$tokens=$null;$errors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($tool,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'A1 readiness tool does not parse.'}
$temp=Join-Path $env:TEMP ('wpsf-a1-smoke-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force|Out-Null
try{
    & $tool -Role Host -ShareName 'WPSF_A1_NONEXISTENT_TEST' -OutputDirectory $temp|Out-Null
    & $tool -Role Client -PrinterPath '\\127.0.0.1\WPSF_A1_NONEXISTENT_TEST' -OutputDirectory $temp|Out-Null
    $records=@(Get-ChildItem -LiteralPath $temp -Filter 'wpsf-a1-*.json' -File)
    if($records.Count -ne 2){throw 'Expected separate host/client outputs.'}
    foreach($file in $records){
        $content=Get-Content -LiteralPath $file.FullName -Raw
        $record=$content|ConvertFrom-Json
        if($record.MatrixId -ne 'A1' -or $record.FunctionalResult -ne 'Unverified' -or $record.CompatibilityMatrixStatus -ne 'Pending'){throw 'Preflight claimed successful functional printing.'}
        if($record.RealTestPageObserved -ne 'NotRecorded'){throw 'Preflight invented a test page.'}
        if($record.OS.Family -eq 'Unknown' -or $null -eq $record.SpoolerStatus){throw 'OS/spooler metadata unavailable.'}
        foreach($secret in @('127.0.0.1','WPSF_A1_NONEXISTENT_TEST',$env:COMPUTERNAME,$env:USERNAME,$env:USERDOMAIN)){
            if($secret -and $content.Contains([string]$secret)){throw 'A1 output leaked a machine or target identifier.'}
        }
        foreach($forbidden in @('ComputerName','HostName','ShareName','PrinterName','DriverName','IPAddress','SSID')){
            if($record.PSObject.Properties[$forbidden]){throw ('A1 output contains forbidden field: '+$forbidden)}
        }
        if($record.Role -eq 'Host'){
            if($record.Checks.ExpectedShareFound -eq $true){throw 'Nonexistent test share incorrectly reported as present.'}
            if($record.Checks.ShareAccessFromClient -ne 'NotTestedFromHost'){throw 'Host side invented client evidence.'}
        }elseif($record.Role -eq 'Client'){
            if($null -eq $record.Checks.TargetResolved -or $record.Checks.DriverInstallation -ne 'NotVerified'){throw 'Client invented driver verification.'}
        }else{throw 'Unexpected A1 role.'}
    }
    $invalidRejected=$false
    try{& $tool -Role Client -PrinterPath '\\127.0.0.1\bad\extra' -OutputDirectory $temp|Out-Null}catch{$invalidRejected=$true}
    if(-not $invalidRejected){throw 'A1 tool accepted invalid UNC.'}
    if(@(Get-ChildItem -LiteralPath $temp -Filter 'wpsf-a1-*.json' -File).Count -ne 2){throw 'Invalid path wrote a report.'}
    Write-Host 'A1 host/client readiness smoke passed.' -ForegroundColor Green
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
