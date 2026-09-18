$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$collector = Join-Path $repo 'tools\Collect-LabEvidence.ps1'
if (-not (Test-Path -LiteralPath $collector)) { throw 'Lab evidence collector is missing.' }

function Get-ManagedFingerprint {
    $registryTargets = @(
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Print','RpcAuthnLevelPrivacyEnabled'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','RpcUseNamedPipeProtocol'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','RpcProtocols'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint','RestrictDriverInstallationToAdministrators'),
        @('HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters','AllowInsecureGuestAuth'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LmCompatibilityLevel'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LimitBlankPasswordUse')
    )
    $registry = foreach ($target in $registryTargets) {
        $present = $false; $value = $null
        if (Test-Path -LiteralPath $target[0]) {
            try {
                $item = Get-Item -LiteralPath $target[0]
                $value = $item.GetValue($target[1],$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $present = ($null -ne $value)
            } catch {}
        }
        [pscustomobject]@{Path=$target[0];Name=$target[1];Present=$present;Value=$value}
    }

    $profiles = @()
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop | Sort-Object InterfaceIndex | Select-Object InterfaceIndex,NetworkCategory)
    } catch {}

    $firewall = @()
    try {
        $firewall = @(Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction Stop | Sort-Object Name | Select-Object Name,Enabled,Profile)
    } catch {}

    $smb1 = 'Unknown'
    try { $smb1 = [string](Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -ErrorAction Stop).State } catch {}
    $spooler = Get-Service Spooler -ErrorAction SilentlyContinue

    return ([pscustomobject]@{
        Registry=$registry
        Profiles=$profiles
        Firewall=$firewall
        SMB1=$smb1
        Spooler=if($spooler){[string]$spooler.Status}else{'Missing'}
    } | ConvertTo-Json -Depth 8 -Compress)
}

$temp = Join-Path $env:TEMP ('wpsf-evidence-smoke-' + [Guid]::NewGuid().ToString('N'))
$before = Get-ManagedFingerprint
try {
    & $collector -MatrixId A1 -Side Client -OutputDirectory $temp | Out-Null
    $after = Get-ManagedFingerprint
    if ($before -ne $after) { throw 'Evidence collection changed managed Windows state.' }

    $jsonFile = Get-ChildItem -LiteralPath $temp -Filter '*.json' | Select-Object -First 1
    $mdFile = Get-ChildItem -LiteralPath $temp -Filter '*.md' | Select-Object -First 1
    if (-not $jsonFile -or -not $mdFile) { throw 'Evidence collector did not create both JSON and Markdown output.' }

    $jsonText = Get-Content -LiteralPath $jsonFile.FullName -Raw
    $mdText = Get-Content -LiteralPath $mdFile.FullName -Raw
    $data = $jsonText | ConvertFrom-Json
    if ($data.MatrixId -ne 'A1' -or $data.Side -ne 'Client') { throw 'Evidence metadata did not preserve the requested matrix case/side.' }
    if ($data.ToolVersion -ne '4.1.0') { throw "Evidence collector did not detect stable tool version: $($data.ToolVersion)" }
    if (-not $data.OS.Name -or $data.OS.Build -le 0) { throw 'Evidence collector did not capture a valid Windows identity.' }
    if([string]$data.CollectorVersion -ne '1.1'){throw 'Evidence collector version was not bumped for exact-build metadata.'}
    if(-not $data.OS.FullBuild -or [string]$data.OS.FullBuild -notmatch ('^'+[regex]::Escape([string]$data.OS.Build)+'(?:\.\d+)?$')){throw 'Evidence collector did not capture normalized full-build metadata.'}
    $ubr=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).UBR
    if($null -ne $ubr -and ([int]$data.OS.Revision -ne [int]$ubr -or [string]$data.OS.FullBuild -ne ("{0}.{1}" -f $data.OS.Build,[int]$ubr))){throw 'Evidence collector lost the exact Windows UBR/full build.'}

    if ($data.IncludedDriverNames -or $data.IncludedSecurityPosture) {
        throw 'Evidence collector default unexpectedly included opt-in privacy-sensitive fields.'
    }
    foreach ($policyName in @('RpcPrivacy','RpcUseNamedPipe','RpcProtocols','PointAndPrintAdmin','InsecureGuestAuth','LmCompatibility','BlankPasswordRestriction')) {
        if ($jsonText -match ('"' + [regex]::Escape($policyName) + '"\s*:')) {
            throw "Default evidence exposed opt-in security posture: $policyName"
        }
    }
    try {
        foreach ($driver in @(Get-Printer -ErrorAction Stop | Select-Object -ExpandProperty DriverName -Unique)) {
            if ($driver -and (($jsonText -match [regex]::Escape([string]$driver)) -or ($mdText -match [regex]::Escape([string]$driver)))) {
                throw "Default evidence exposed an installed driver name: $driver"
            }
        }
    } catch {
        if ($_.Exception.Message -like 'Default evidence exposed*') { throw }
    }

    foreach ($forbiddenKey in @('ComputerName','MachineName','UserName','Domain','IPAddress','SSID','PortName','ShareName','PrinterName')) {
        if ($jsonText -match ('"' + [regex]::Escape($forbiddenKey) + '"\s*:')) {
            throw "Evidence JSON exposes forbidden field: $forbiddenKey"
        }
    }

    foreach ($secret in @($env:COMPUTERNAME,$env:USERNAME,$env:USERDOMAIN)) {
        if ($secret -and (($jsonText -match [regex]::Escape($secret)) -or ($mdText -match [regex]::Escape($secret)))) {
            throw "Evidence output leaked an environment identifier: $secret"
        }
    }


    $optIn = Join-Path $temp 'opt-in'
    & $collector -MatrixId A1 -Side Client -IncludeDriverNames -IncludeSecurityPosture -OutputDirectory $optIn | Out-Null
    $optJson = Get-ChildItem -LiteralPath $optIn -Filter '*.json' | Select-Object -First 1
    $optData = Get-Content -LiteralPath $optJson.FullName -Raw | ConvertFrom-Json
    if (-not $optData.IncludedDriverNames -or -not $optData.IncludedSecurityPosture) {
        throw 'Evidence collector opt-in flags were not honored.'
    }
    if (-not $optData.Policies.PSObject.Properties['RpcPrivacy']) { throw 'Opt-in security posture did not include RPC privacy state.' }
    if (-not $optData.Policies.PSObject.Properties['RpcUseNamedPipe']) { throw 'Opt-in security posture did not include RPC Named Pipes state.' }
    if ([string]$optData.SMB1Client -like 'Omitted*') { throw 'Opt-in security posture did not include SMB1 client state.' }
    $afterOptIn = Get-ManagedFingerprint
    if ($before -ne $afterOptIn) { throw 'Opt-in evidence collection changed managed Windows state.' }

    Write-Host ('Evidence smoke passed: read-only collection produced sanitized JSON/Markdown for {0} build {1}.' -f $data.OS.Name,$data.OS.FullBuild) -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
