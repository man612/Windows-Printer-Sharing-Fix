#requires -version 5.1
[CmdletBinding()]
param(
    [ValidateSet('A1','A2','A3','A4','A5','A6','Other')]
    [string]$MatrixId = 'Other',
    [ValidateSet('Client','Host','Host+Client','Unknown')]
    [string]$Side = 'Unknown',
    [switch]$IncludeDriverNames,
    [switch]$IncludeSecurityPosture,
    [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'WindowsPrinterSharingFix-Evidence')
)

$ErrorActionPreference = 'Stop'
$collectorVersion = '1.1'
$repo = Split-Path -Parent $PSScriptRoot

function Get-RegistryValueState([string]$Path,[string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{Present=$false;Value=$null}
    }
    try {
        $item = Get-Item -LiteralPath $Path
        $value = $item.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value) { return [pscustomobject]@{Present=$false;Value=$null} }
        return [pscustomobject]@{Present=$true;Value=$value}
    } catch { return [pscustomobject]@{Present=$false;Value=$null} }
}

function Get-OsInfo {
    try {
        $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $build = [int]$key.CurrentBuild
        $revision = $null
        $revisionProperty = $key.PSObject.Properties['UBR']
        if($revisionProperty -and $null -ne $revisionProperty.Value){
            $parsedRevision=0
            if([int]::TryParse([string]$revisionProperty.Value,[ref]$parsedRevision) -and $parsedRevision -ge 0){$revision=$parsedRevision}
        }
        $fullBuild=if($null -ne $revision){"$build.$revision"}else{[string]$build}
        $product = [string]$key.ProductName
        $installType = [string]$key.InstallationType
        $display = if ($key.DisplayVersion) {[string]$key.DisplayVersion} else {[string]$key.ReleaseId}
        $name = if (($product -match 'Server') -or ($installType -match 'Server')) {
            $product
        } elseif ($build -ge 22000) {
            'Windows 11'
        } elseif ($build -ge 10240) {
            'Windows 10'
        } else {
            $product
        }
        return [pscustomobject]@{Name=$name;ProductName=$product;DisplayVersion=$display;Build=$build;Revision=$revision;FullBuild=$fullBuild;InstallationType=$installType}
    } catch {
        return [pscustomobject]@{Name='Unknown';ProductName='Unknown';DisplayVersion='';Build=0;Revision=$null;FullBuild='';InstallationType=''}
    }
}

function Get-WindowsFeatureState([string]$Name) {
    try {
        if (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            return [string](Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop).State
        }
    } catch {}
    return 'Unknown'
}

function Get-SafePrinterInventory {
    try {
        $items = if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
            @(Get-Printer -ErrorAction Stop)
        } else {
            @(Get-CimInstance Win32_Printer -ErrorAction Stop)
        }
        $index = 0
        return @($items | ForEach-Object {
            $index++
            $name = [string]$_.Name
            $type = [string]$_.Type
            [pscustomobject]@{
                Alias = ('Printer-{0}' -f $index)
                DriverName = if ($IncludeDriverNames) {[string]$_.DriverName} else {$null}
                Shared = [bool]$_.Shared
                Connection = (($name -like '\\*') -or ($type -eq 'Connection'))
                Type = if ($type) {$type} else {'Unknown'}
            }
        })
    } catch { return @() }
}

function Get-SafeNetworkProfiles {
    try {
        if (-not (Get-Command Get-NetConnectionProfile -ErrorAction SilentlyContinue)) { return @() }
        return @(Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                NetworkCategory = [string]$_.NetworkCategory
                IPv4Connectivity = [string]$_.IPv4Connectivity
                IPv6Connectivity = [string]$_.IPv6Connectivity
            }
        })
    } catch { return @() }
}

function Get-SafePrintEvents {
    try {
        return @(Get-WinEvent -FilterHashtable @{
            LogName='Microsoft-Windows-PrintService/Admin'
            Level=2,3
            StartTime=(Get-Date).AddDays(-7)
        } -MaxEvents 8 -ErrorAction Stop | Select-Object TimeCreated,Id,LevelDisplayName)
    } catch { return @() }
}

function Get-FirewallSummary {
    try {
        if (-not (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{Available=$false;Total=0;Enabled=0;Profiles=@()}
        }
        $rules = @(Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction SilentlyContinue)
        if (-not $rules.Count) {
            $rules = @(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
                $_.Group -eq '@FirewallAPI.dll,-28502'
            })
        }
        $profiles = @($rules | ForEach-Object {[string]$_.Profile} | Sort-Object -Unique)
        return [pscustomobject]@{
            Available=$true
            Total=$rules.Count
            Enabled=@($rules | Where-Object {$_.Enabled -eq 'True'}).Count
            Profiles=$profiles
        }
    } catch {
        return [pscustomobject]@{Available=$false;Total=0;Enabled=0;Profiles=@()}
    }
}

$toolVersion = 'unknown'
$fixScript = Join-Path $repo 'FixPrinter.ps1'
if (Test-Path -LiteralPath $fixScript) {
    $source = Get-Content -LiteralPath $fixScript -Raw -ErrorAction SilentlyContinue
    $pattern = '\$script:Version\s*=\s*''([^'']+)'''
    $match = [regex]::Match([string]$source,$pattern,'IgnoreCase')
    if ($match.Success) { $toolVersion = $match.Groups[1].Value }
}

$os = Get-OsInfo
$spooler = Get-Service Spooler -ErrorAction SilentlyContinue
$spoolerCim = $null
try { $spoolerCim = Get-CimInstance Win32_Service -Filter "Name='Spooler'" -ErrorAction Stop } catch {}
$printers = @(Get-SafePrinterInventory)
$profiles = @(Get-SafeNetworkProfiles)
$events = @(Get-SafePrintEvents)
$firewall = Get-FirewallSummary

$wppPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP'
$wppGp = Get-RegistryValueState $wppPath 'WindowsProtectedPrintGroupPolicyState'
$wppMode = Get-RegistryValueState $wppPath 'WindowsProtectedPrintMode'
$wppEnabled = (($wppGp.Present -and [int]$wppGp.Value -eq 1) -or ($wppMode.Present -and [int]$wppMode.Value -eq 1))

$policyTargets = @()
if ($IncludeSecurityPosture) {
    $policyTargets = @(
        @('RpcPrivacy','HKLM:\SYSTEM\CurrentControlSet\Control\Print','RpcAuthnLevelPrivacyEnabled'),
        @('RpcUseNamedPipe','HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','RpcUseNamedPipeProtocol'),
        @('RpcProtocols','HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','RpcProtocols'),
        @('PointAndPrintAdmin','HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint','RestrictDriverInstallationToAdministrators'),
        @('InsecureGuestAuth','HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters','AllowInsecureGuestAuth'),
        @('LmCompatibility','HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LmCompatibilityLevel'),
        @('BlankPasswordRestriction','HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LimitBlankPasswordUse')
    )
}

$policies = [ordered]@{}
foreach ($target in $policyTargets) {
    $state = Get-RegistryValueState $target[1] $target[2]
    $policies[$target[0]] = [pscustomobject]@{Present=$state.Present;Value=$state.Value}
}

$report = [ordered]@{
    SchemaVersion = 1
    CollectorVersion = $collectorVersion
    ToolVersion = $toolVersion
    MatrixId = $MatrixId
    Side = $Side
    CollectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    Privacy = 'Common machine/network identifiers are omitted. Driver names and security-posture values are opt-in.'
    IncludedDriverNames = [bool]$IncludeDriverNames
    IncludedSecurityPosture = [bool]$IncludeSecurityPosture
    OS = $os
    PowerShell = $PSVersionTable.PSVersion.ToString()
    Spooler = [pscustomobject]@{
        Status = if ($spooler) {[string]$spooler.Status} else {'Missing'}
        StartMode = if ($spoolerCim) {[string]$spoolerCim.StartMode} else {'Unknown'}
    }
    Printers = $printers
    NetworkProfiles = $profiles
    WPP = [pscustomobject]@{Enabled=$wppEnabled;GroupPolicy=$wppGp;Mode=$wppMode}
    Policies = $policies
    SMB1Client = if ($IncludeSecurityPosture) {Get-WindowsFeatureState 'SMB1Protocol-Client'} else {'Omitted (use -IncludeSecurityPosture)'}
    FirewallSharing = $firewall
    RecentPrintEvents = $events
}

function ConvertTo-MarkdownCell([object]$Value) {
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $OutputDirectory ("wpsf-lab-evidence-$stamp.json")
$mdPath = Join-Path $OutputDirectory ("wpsf-lab-evidence-$stamp.md")
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Windows Printer Sharing Fix - Lab Evidence')
$lines.Add('')
$lines.Add(('- Matrix case: `{0}`' -f $MatrixId))
$lines.Add(('- Side: `{0}`' -f $Side))
$lines.Add(('- Tool version: `{0}`' -f $toolVersion))
$lines.Add(('- Collector version: `{0}`' -f $collectorVersion))
$lines.Add(('- Collected UTC: `{0}`' -f $report.CollectedAtUtc))
$lines.Add('')
$lines.Add('> Privacy: common machine/network identifiers are omitted. Driver names and security-posture values are opt-in and omitted by default.')
$lines.Add('')
$lines.Add('## Windows')
$lines.Add('')
$lines.Add(('- OS: {0} {1} build {2}' -f (ConvertTo-MarkdownCell $os.Name),(ConvertTo-MarkdownCell $os.DisplayVersion),(ConvertTo-MarkdownCell $os.FullBuild)))
$lines.Add(('- Installation type: {0}' -f (ConvertTo-MarkdownCell $os.InstallationType)))
$lines.Add(('- PowerShell: {0}' -f $report.PowerShell))
$lines.Add(('- Spooler: {0}; start mode: {1}' -f $report.Spooler.Status,$report.Spooler.StartMode))

$lines.Add('')
$lines.Add('## Printer inventory (sanitized)')
$lines.Add('')
$lines.Add('| Alias | Driver | Shared | Connection | Type |')
$lines.Add('| --- | --- | --- | --- | --- |')
if ($printers.Count) {
    foreach ($printer in $printers) {
        $driver = if ($printer.DriverName) {(ConvertTo-MarkdownCell $printer.DriverName)} else {'(omitted; add target driver manually)'}
        $lines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f $printer.Alias,$driver,$printer.Shared,$printer.Connection,(ConvertTo-MarkdownCell $printer.Type)))
    }
} else {
    $lines.Add('| - | No printer inventory available | - | - | - |')
}

$lines.Add('')
$lines.Add('## Network profiles (sanitized)')
$lines.Add('')
$lines.Add('| Category | IPv4 | IPv6 |')
$lines.Add('| --- | --- | --- |')
if ($profiles.Count) {
    foreach ($profile in $profiles) {
        $lines.Add(('| {0} | {1} | {2} |' -f $profile.NetworkCategory,$profile.IPv4Connectivity,$profile.IPv6Connectivity))
    }
} else {
    $lines.Add('| Unknown | Unknown | Unknown |')
}

$lines.Add('')
$lines.Add('## Protection / compatibility state')
$lines.Add('')
$lines.Add(('- WPP detected: `{0}`' -f $wppEnabled))
$lines.Add(('- SMB1 client: `{0}`' -f $report.SMB1Client))
$lines.Add(('- File and Printer Sharing firewall rules: total `{0}`, enabled `{1}`' -f $firewall.Total,$firewall.Enabled))

$lines.Add('')
$lines.Add('| Policy | Present | Value |')
$lines.Add('| --- | --- | --- |')
foreach ($key in $policies.Keys) {
    $state = $policies[$key]
    $value = if ($state.Present) {(ConvertTo-MarkdownCell $state.Value)} else {'(absent)'}
    $lines.Add(('| {0} | {1} | {2} |' -f $key,$state.Present,$value))
}

$lines.Add('')
$lines.Add('## Recent PrintService events')
$lines.Add('')
if ($events.Count) {
    $lines.Add('| UTC/local timestamp | Event ID | Level |')
    $lines.Add('| --- | --- | --- |')
    foreach ($event in $events) {
        $lines.Add(('| {0} | {1} | {2} |' -f $event.TimeCreated.ToString('s'),$event.Id,(ConvertTo-MarkdownCell $event.LevelDisplayName)))
    }
} else {
    $lines.Add('No recent PrintService warning/error metadata was available.')
}

$lines.Add('')
$lines.Add('## Manual result fields')
$lines.Add('')
$lines.Add('- Earliest failing / relevant layer:')
$lines.Add('- Highest repair tier needed:')
$lines.Add('- Functional result:')
$lines.Add('- Restore result (if applicable):')
$lines.Add('- Notes:')

$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8
Write-Host ('Evidence JSON created: {0}' -f (Split-Path -Leaf $jsonPath)) -ForegroundColor Green
Write-Host ('Paste-ready Markdown created: {0}' -f (Split-Path -Leaf $mdPath)) -ForegroundColor Green
Write-Host 'Files were written to the selected output directory.' -ForegroundColor DarkGray
