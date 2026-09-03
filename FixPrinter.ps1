#requires -version 5.1
<#
Windows Printer Sharing Fix v4
Diagnosis-first TUI for Windows printer sharing.
English is the default language. Indonesian is optional.
#>

[CmdletBinding()]
param([switch]$NoElevation)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Version = '4.0.0'
$script:ScriptPath = $PSCommandPath
$script:Root = Split-Path -Parent $script:ScriptPath
$script:BackupRoot = Join-Path $script:Root 'backups'
$script:LogRoot = Join-Path $script:Root 'logs'
$script:LanguageFile = Join-Path $script:Root 'language.cfg'
$script:LatestStateFile = Join-Path $script:BackupRoot 'latest_backup.txt'
$script:Language = 'EN'
$script:CurrentLog = $null
$script:LastDiagnostic = $null

$script:Text = @{
    EN = @{
        Title='WINDOWS PRINTER SHARING FIX'; Subtitle='Diagnosis-first repair utility'; Main='MAIN MENU'; Diagnose='Diagnose this PC'; Safe='Safe Repair'; Compat='Compatibility Repair (Advanced)'; Legacy='Legacy Compatibility (High Risk)'; Restore='Restore latest managed changes'; Tools='Tools and Logs'; Language='Language'; Exit='Exit'; Select='Select'; Back='Back'; Recommended='RECOMMENDED'; Invalid='Invalid selection.'; Press='Press Enter to continue';
    }
    ID = @{
        Title='WINDOWS PRINTER SHARING FIX'; Subtitle='Utilitas diagnosis dan perbaikan printer sharing'; Main='MENU UTAMA'; Diagnose='Diagnosis PC ini'; Safe='Perbaikan Aman'; Compat='Perbaikan Kompatibilitas (Lanjutan)'; Legacy='Kompatibilitas Legacy (Risiko Tinggi)'; Restore='Kembalikan perubahan terakhir'; Tools='Tools dan Log'; Language='Bahasa'; Exit='Keluar'; Select='Pilih'; Back='Kembali'; Recommended='DISARANKAN'; Invalid='Pilihan tidak valid.'; Press='Tekan Enter untuk lanjut';
    }
}

function T([string]$Key) {
    if ($script:Text[$script:Language].ContainsKey($Key)) { return $script:Text[$script:Language][$Key] }
    return $script:Text.EN[$Key]
}

function Initialize-Workspace {
    foreach ($dir in @($script:BackupRoot,$script:LogRoot)) {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    if (Test-Path -LiteralPath $script:LanguageFile) {
        $value = (Get-Content -LiteralPath $script:LanguageFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim().ToUpperInvariant()
        if ($value -in @('EN','ID')) { $script:Language = $value }
    }
    $script:CurrentLog = Join-Path $script:LogRoot ('printer-fix-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Write-Log "Windows Printer Sharing Fix v$($script:Version) started."
}

function Write-Log([string]$Message,[string]$Level='INFO') {
    if ($script:CurrentLog) { ('[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message) | Add-Content -LiteralPath $script:CurrentLog -Encoding UTF8 }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Administrator {
    if (Test-IsAdministrator) { return $true }
    if ($NoElevation) { return $false }
    Write-Host 'Requesting Administrator access...' -ForegroundColor Yellow
    try {
        $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath))
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $script:Root -ArgumentList ($args -join ' ')
    } catch {
        Write-Host "Could not obtain Administrator access: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $false
}

function Write-Header([string]$Section='') {
    Clear-Host
    Write-Host ('=' * 78) -ForegroundColor DarkCyan
    Write-Host ('  {0}  v{1}' -f (T 'Title'),$script:Version) -ForegroundColor Cyan
    Write-Host ('  {0}' -f (T 'Subtitle')) -ForegroundColor Gray
    if ($Section) { Write-Host ('  > {0}' -f $Section) -ForegroundColor White }
    Write-Host ('=' * 78) -ForegroundColor DarkCyan
}
function Write-Rule { Write-Host ('-' * 78) -ForegroundColor DarkGray }
function Write-Ok([string]$Text) { Write-Host ('[OK]   {0}' -f $Text) -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host ('[INFO] {0}' -f $Text) -ForegroundColor Cyan }
function Write-Warn([string]$Text) { Write-Host ('[WARN] {0}' -f $Text) -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host ('[FAIL] {0}' -f $Text) -ForegroundColor Red }
function Pause-Tui { [void](Read-Host (T 'Press')) }

function Read-Choice([string]$Prompt,[string[]]$Allowed) {
    while ($true) {
        $value = (Read-Host $Prompt).Trim().ToUpperInvariant()
        if ($value -in $Allowed) { return $value }
        Write-Warn (T 'Invalid')
    }
}

function Read-YesNo([string]$Prompt,[bool]$DefaultNo=$true) {
    $suffix = if ($DefaultNo) {'[y/N]'} else {'[Y/n]'}
    $value = (Read-Host "$Prompt $suffix").Trim().ToUpperInvariant()
    if (-not $value) { return (-not $DefaultNo) }
    return $value -in @('Y','YES','YA')
}

function Get-OsInfo {
    $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $getProp = { param($Object,$Name,$Default='') $p=$Object.PSObject.Properties[$Name]; if($p){[string]$p.Value}else{$Default} }
    $buildText = & $getProp $key 'CurrentBuild' '0'
    $build = 0; [void][int]::TryParse($buildText,[ref]$build)
    $name = & $getProp $key 'ProductName' 'Windows'
    if ($build -ge 22000) {$name='Windows 11'} elseif ($build -ge 10240) {$name='Windows 10'}
    $display = & $getProp $key 'DisplayVersion' (& $getProp $key 'ReleaseId' '')
    return [pscustomobject]@{Name=$name;Build=$build;DisplayVersion=$display}
}

function Get-RegistryValueState([string]$Path,[string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{Present=$false;Value=$null;Kind=$null} }
    try {
        $item = Get-Item -LiteralPath $Path
        $value = $item.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value) { return [pscustomobject]@{Present=$false;Value=$null;Kind=$null} }
        return [pscustomobject]@{Present=$true;Value=$value;Kind=$item.GetValueKind($Name).ToString()}
    } catch { return [pscustomobject]@{Present=$false;Value=$null;Kind=$null} }
}

function Set-RegistryDword([string]$Path,[string]$Name,[int]$Value) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    Write-Log "Registry: $Path\\$Name=$Value"
}

function Restore-RegistryValue($Entry) {
    $path=[string]$Entry.Path; $name=[string]$Entry.Name
    if ($Entry.Present) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
        $types=@{DWord='DWord';QWord='QWord';String='String';ExpandString='ExpandString';MultiString='MultiString';Binary='Binary'}
        $type=if($types.ContainsKey([string]$Entry.Kind)){$types[[string]$Entry.Kind]}else{'String'}
        New-ItemProperty -Path $path -Name $name -PropertyType $type -Value $Entry.Value -Force | Out-Null
    } elseif (Test-Path -LiteralPath $path) {
        Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
    }
}

function Get-PrinterInventory {
    try {
        if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
            return @(Get-Printer | Select-Object Name,DriverName,PortName,Shared,ShareName,Type,ComputerName)
        }
        return @(Get-CimInstance Win32_Printer | ForEach-Object {[pscustomobject]@{Name=$_.Name;DriverName=$_.DriverName;PortName=$_.PortName;Shared=[bool]$_.Shared;ShareName=$_.ShareName;Type=$null;ComputerName=$null}})
    } catch { Write-Log $_.Exception.Message 'WARN'; return @() }
}

function Get-NetworkProfilesSafe {
    try {
        if (Get-Command Get-NetConnectionProfile -ErrorAction SilentlyContinue) { return @(Get-NetConnectionProfile | Select-Object Name,InterfaceAlias,InterfaceIndex,NetworkCategory,IPv4Connectivity,IPv6Connectivity) }
    } catch { Write-Log $_.Exception.Message 'WARN' }
    return @()
}

function Get-WppState {
    $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP'
    $gp=Get-RegistryValueState $path 'WindowsProtectedPrintGroupPolicyState'
    $mode=Get-RegistryValueState $path 'WindowsProtectedPrintMode'
    return [pscustomobject]@{Enabled=(($gp.Present -and [int]$gp.Value -eq 1) -or ($mode.Present -and [int]$mode.Value -eq 1));GroupPolicy=$gp;Mode=$mode}
}

function Get-WindowsFeatureState([string]$Name) {
    try { if (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) { return [string](Get-WindowsOptionalFeature -Online -FeatureName $Name).State } } catch {}
    return 'Unknown'
}

function Get-FirewallSharingRules {
    try {
        if (-not (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue)) { return @() }
        return @(Get-NetFirewallRule | Where-Object {$_.Group -eq '@FirewallAPI.dll,-28502' -or $_.DisplayGroup -eq 'File and Printer Sharing' -or $_.DisplayGroup -eq 'Berbagi File dan Printer'} | Select-Object Name,DisplayName,DisplayGroup,Enabled,Profile,Direction,Action)
    } catch { Write-Log $_.Exception.Message 'WARN'; return @() }
}

function Get-RecentPrintErrors {
    try { return @(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Admin';Level=2,3;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 8 | Select-Object TimeCreated,Id,LevelDisplayName,Message) } catch { return @() }
}

function Test-TcpPort([string]$ComputerName,[int]$Port) {
    try {
        if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) { return [bool](Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue) }
        $client=New-Object System.Net.Sockets.TcpClient
        $async=$client.BeginConnect($ComputerName,$Port,$null,$null)
        if(-not $async.AsyncWaitHandle.WaitOne(2500,$false)){$client.Close();return $false}
        $client.EndConnect($async);$client.Close();return $true
    } catch { return $false }
}

function Invoke-Diagnosis([switch]$Quiet) {
    $os=Get-OsInfo; $spooler=Get-Service Spooler -ErrorAction SilentlyContinue; $printers=Get-PrinterInventory; $profiles=Get-NetworkProfilesSafe; $wpp=Get-WppState; $errors=Get-RecentPrintErrors
    $shared=@($printers|Where-Object{$_.Shared -or $_.ShareName}); $connections=@($printers|Where-Object{$_.Name -like '\\*' -or $_.Type -eq 'Connection'})
    $role=if($shared.Count -and $connections.Count){'Host + Client'}elseif($shared.Count){'Host'}elseif($connections.Count){'Client'}else{'Unknown / local only'}
    $rpcPrivacy=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' 'RpcAuthnLevelPrivacyEnabled'
    $rpcPipe=Get-RegistryValueState 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol'
    $rpcProtocols=Get-RegistryValueState 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcProtocols'
    $point=Get-RegistryValueState 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' 'RestrictDriverInstallationToAdministrators'
    $guest=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth'
    $lm=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LmCompatibilityLevel'
    $blank=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LimitBlankPasswordUse'
    $smb1=Get-WindowsFeatureState 'SMB1Protocol-Client'
    $findings=New-Object System.Collections.Generic.List[object]
    if(-not $spooler){$findings.Add([pscustomobject]@{Severity='FAIL';Text='Print Spooler service is missing.'})}elseif($spooler.Status -ne 'Running'){$findings.Add([pscustomobject]@{Severity='WARN';Text='Print Spooler is not running.'})}
    if($wpp.Enabled){$findings.Add([pscustomobject]@{Severity='INFO';Text='Windows Protected Print Mode appears enabled. Legacy third-party printer drivers can be removed or blocked.'})}
    if($rpcPrivacy.Present -and [int]$rpcPrivacy.Value -eq 0){$findings.Add([pscustomobject]@{Severity='WARN';Text='RPC packet privacy hardening is disabled (RpcAuthnLevelPrivacyEnabled=0).'})}
    if($point.Present -and [int]$point.Value -eq 0){$findings.Add([pscustomobject]@{Severity='WARN';Text='Point and Print driver-installation protection is disabled.'})}
    if($guest.Present -and [int]$guest.Value -eq 1){$findings.Add([pscustomobject]@{Severity='WARN';Text='Insecure SMB guest authentication is enabled.'})}
    if($lm.Present -and [int]$lm.Value -le 2){$findings.Add([pscustomobject]@{Severity='WARN';Text="LAN Manager authentication is configured for legacy compatibility (level $($lm.Value))."})}
    if($blank.Present -and [int]$blank.Value -eq 0){$findings.Add([pscustomobject]@{Severity='WARN';Text='Remote use of blank-password local accounts is allowed. This utility will never enable that setting.'})}
    if($smb1 -match '^Enabled'){$findings.Add([pscustomobject]@{Severity='WARN';Text='SMB1 client is enabled.'})}
    if(@($profiles|Where-Object{$_.NetworkCategory -eq 'Public' -and $_.IPv4Connectivity -ne 'Disconnected'}).Count){$findings.Add([pscustomobject]@{Severity='INFO';Text='At least one active network is Public; sharing may be intentionally restricted.'})}
    if($errors.Count){$findings.Add([pscustomobject]@{Severity='INFO';Text="Recent PrintService warnings/errors found: $($errors.Count)."})}
    $result=[pscustomobject]@{OS=$os;PowerShell=$PSVersionTable.PSVersion.ToString();Role=$role;Spooler=$spooler;Printers=$printers;SharedPrinters=$shared;Connections=$connections;Profiles=$profiles;WPP=$wpp;PrintErrors=$errors;RpcPrivacy=$rpcPrivacy;RpcUseNamedPipe=$rpcPipe;RpcProtocols=$rpcProtocols;PointAndPrint=$point;GuestAuth=$guest;LmCompatibility=$lm;BlankPassword=$blank;SMB1Client=$smb1;Findings=$findings}
    $script:LastDiagnostic=$result; Write-Log "Diagnosis role=$role printers=$($printers.Count) findings=$($findings.Count)"
    if(-not $Quiet){Show-DiagnosticReport $result}; return $result
}

function Show-DiagnosticReport($D) {
    Write-Header 'DIAGNOSTIC REPORT'
    Write-Host ('OS              : {0} {1} (build {2})' -f $D.OS.Name,$D.OS.DisplayVersion,$D.OS.Build)
    Write-Host ('PowerShell      : {0}' -f $D.PowerShell)
    Write-Host ('Detected role   : {0}' -f $D.Role)
    Write-Host ('Print Spooler   : {0}' -f $(if($D.Spooler){$D.Spooler.Status}else{'Missing'}))
    Write-Host ('Printers        : {0} total / {1} shared / {2} network connection(s)' -f $D.Printers.Count,$D.SharedPrinters.Count,$D.Connections.Count)
    Write-Host ('WPP             : {0}' -f $(if($D.WPP.Enabled){'ENABLED'}else{'not detected as enabled'}))
    Write-Host ('SMB1 client     : {0}' -f $D.SMB1Client)
    Write-Rule
    if(-not $D.Findings.Count){Write-Ok 'No obvious critical problem was detected.'}
    foreach($f in $D.Findings){switch($f.Severity){'FAIL'{Write-Fail $f.Text};'WARN'{Write-Warn $f.Text};default{Write-Info $f.Text}}}
    if($D.SharedPrinters.Count){Write-Rule;Write-Host 'Shared printers:';foreach($p in $D.SharedPrinters){Write-Host ('  - {0} | share={1} | driver={2}' -f $p.Name,$p.ShareName,$p.DriverName)}}
    if($D.Connections.Count){Write-Rule;Write-Host 'Network printer connections:';foreach($p in $D.Connections){Write-Host ('  - {0} | driver={1}' -f $p.Name,$p.DriverName)}}
    if($D.Profiles.Count){Write-Rule;Write-Host 'Network profiles:';foreach($n in $D.Profiles){Write-Host ('  [{0}] {1} / {2} / IPv4={3}' -f $n.InterfaceIndex,$n.InterfaceAlias,$n.NetworkCategory,$n.IPv4Connectivity)}}
    if($D.PrintErrors.Count){Write-Rule;Write-Host 'Recent PrintService events:';foreach($e in $D.PrintErrors|Select-Object -First 5){$m=([string]$e.Message -replace '\s+',' ');if($m.Length -gt 120){$m=$m.Substring(0,120)+'...'};Write-Host ('  {0:g} ID {1}: {2}' -f $e.TimeCreated,$e.Id,$m)}}
    Write-Rule; Write-Info "Log: $script:CurrentLog"
    if(Read-YesNo 'Test a specific shared printer path now?' $true){Invoke-SharedPrinterPathDiagnosis}
    Pause-Tui
}

function Invoke-SharedPrinterPathDiagnosis {
    Write-Rule; Write-Host 'SHARED PRINTER PATH TEST' -ForegroundColor White
    $unc=(Read-Host 'Enter printer path like \\PRINT-PC\OfficePrinter (blank = cancel)').Trim(); if(-not $unc){return}
    if($unc -notmatch '^\\\\([^\\]+)\\([^\\]+)$'){Write-Warn 'Invalid UNC printer path.';return}
    $hostName=$Matches[1]
    $dns=$false;try{$dns=([System.Net.Dns]::GetHostAddresses($hostName).Count -gt 0)}catch{}
    $smb=if($dns){Test-TcpPort $hostName 445}else{$false}; $rpc=if($dns){Test-TcpPort $hostName 135}else{$false}; $root=$false
    if($smb){try{$root=Test-Path -LiteralPath ("\\{0}\" -f $hostName) -ErrorAction SilentlyContinue}catch{}}
    $installed=@((Get-PrinterInventory)|Where-Object{$_.Name -eq $unc}).Count -gt 0
    if($dns){Write-Ok "Host resolves: $hostName"}else{Write-Fail "Host does not resolve: $hostName"}
    if($smb){Write-Ok 'TCP 445 (SMB) reachable.'}else{Write-Fail 'TCP 445 (SMB) not reachable.'}
    if($rpc){Write-Ok 'TCP 135 (RPC Endpoint Mapper) reachable.'}else{Write-Warn 'TCP 135 (RPC Endpoint Mapper) not reachable.'}
    if($root){Write-Ok "Host share namespace accessible: \\$hostName"}elseif($smb){Write-Warn 'SMB port is reachable but the share namespace was not accessible; credentials, sharing, or policy may be involved.'}
    if($installed){Write-Ok "Printer installed locally: $unc"}else{Write-Info "Printer not currently installed locally: $unc"}
    Write-Rule
    if(-not $dns){Write-Fail 'Most likely layer: name resolution/basic network. Do not change printer security policies yet.'}
    elseif(-not $smb){Write-Fail 'Most likely layer: SMB/firewall/routing. Do not enable SMB1 unless the target is proven SMB1-only.'}
    elseif(-not $rpc){Write-Warn 'RPC reachability is suspicious. Check RPC/firewall before compatibility fallbacks.'}
    elseif(-not $installed -and (Get-WppState).Enabled){Write-Warn 'WPP is enabled. If this printer depends on a legacy third-party driver, WPP compatibility is a strong candidate.'}
    elseif(-not $installed){Write-Info 'Basic transport is reachable. Driver installation, Point and Print policy, credentials, or the remote printer share are the next likely layers.'}
    else{Write-Ok 'Basic prerequisites look healthy. Printing a test page is the final functional verification.'}
    Write-Log "Target test $unc dns=$dns smb445=$smb rpc135=$rpc root=$root installed=$installed"
}

function Get-ManagedRegistryEntries {
    $targets=@(
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Print','RpcAuthnLevelPrivacyEnabled'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','RpcUseNamedPipeProtocol'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','RpcProtocols'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint','RestrictDriverInstallationToAdministrators'),
        @('HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters','AllowInsecureGuestAuth'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LmCompatibilityLevel'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LimitBlankPasswordUse')
    )
    $out=@();foreach($t in $targets){$s=Get-RegistryValueState $t[0] $t[1];$out+=[pscustomobject]@{Path=$t[0];Name=$t[1];Present=$s.Present;Value=$s.Value;Kind=$s.Kind}};return $out
}

function New-RestoreSnapshot([string]$Reason) {
    try {
        $dir=Join-Path $script:BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6));New-Item -ItemType Directory -Path $dir -Force|Out-Null
        $services=@();foreach($name in @('Spooler','LanmanServer','LanmanWorkstation','fdPHost','FDResPub')){try{$s=Get-CimInstance Win32_Service -Filter "Name='$name'";$services+=[pscustomobject]@{Name=$name;State=$s.State;StartMode=$s.StartMode}}catch{}}
        $profiles=@(Get-NetworkProfilesSafe|ForEach-Object{[pscustomobject]@{InterfaceIndex=[int]$_.InterfaceIndex;NetworkCategory=[string]$_.NetworkCategory}})
        $fw=@(Get-FirewallSharingRules|ForEach-Object{[pscustomobject]@{Name=[string]$_.Name;Enabled=[string]$_.Enabled;Profile=[string]$_.Profile}})
        $state=[pscustomobject]@{Version=$script:Version;Created=(Get-Date).ToString('o');Reason=$Reason;Registry=(Get-ManagedRegistryEntries);Services=$services;NetworkProfiles=$profiles;FirewallRules=$fw;WindowsFeatures=@([pscustomobject]@{Name='SMB1Protocol-Client';State=(Get-WindowsFeatureState 'SMB1Protocol-Client')})}
        $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Encoding UTF8;$dir|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8;Write-Log "Snapshot: $dir reason=$Reason";return $dir
    } catch {Write-Fail "Snapshot failed: $($_.Exception.Message)";Write-Log $_.Exception.Message 'ERROR';return $null}
}

function Restore-ServiceStartMode([string]$Name,[string]$Mode){$map=@{Auto='Automatic';Automatic='Automatic';Manual='Manual';Disabled='Disabled'};if($map.ContainsKey($Mode)){Set-Service -Name $Name -StartupType $map[$Mode] -ErrorAction SilentlyContinue}}

function Invoke-RestoreLatest {
    Write-Header 'RESTORE';Write-Warn 'Restore reverts states managed by v4. Deleted print jobs cannot be recovered.'
    if(-not(Test-Path -LiteralPath $script:LatestStateFile)){Write-Warn 'No v4 restore snapshot exists yet.';Pause-Tui;return}
    $dir=(Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1).Trim();$file=Join-Path $dir 'managed-state.json';if(-not(Test-Path -LiteralPath $file)){Write-Fail 'Latest snapshot is missing or damaged.';Pause-Tui;return}
    if(-not(Read-YesNo "Restore state from $dir ?" $true)){return}
    try{
        $state=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
        foreach($r in $state.Registry){Restore-RegistryValue $r}
        foreach($f in $state.FirewallRules){if(Get-Command Set-NetFirewallRule -ErrorAction SilentlyContinue){Set-NetFirewallRule -Name $f.Name -Enabled ([string]$f.Enabled) -Profile ([string]$f.Profile) -ErrorAction SilentlyContinue}}
        foreach($n in $state.NetworkProfiles){if(Get-Command Set-NetConnectionProfile -ErrorAction SilentlyContinue){Set-NetConnectionProfile -InterfaceIndex ([int]$n.InterfaceIndex) -NetworkCategory ([string]$n.NetworkCategory) -ErrorAction SilentlyContinue}}
        foreach($feature in $state.WindowsFeatures){if($feature.Name -eq 'SMB1Protocol-Client' -and (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)){$current=Get-WindowsFeatureState $feature.Name;if([string]$feature.State -match '^Enabled' -and $current -notmatch '^Enabled'){Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue|Out-Null}elseif([string]$feature.State -match '^Disabled' -and $current -notmatch '^Disabled'){Disable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue|Out-Null}}}
        foreach($s in $state.Services){Restore-ServiceStartMode $s.Name $s.StartMode;if($s.State -eq 'Running'){Start-Service $s.Name -ErrorAction SilentlyContinue}else{Stop-Service $s.Name -Force -ErrorAction SilentlyContinue}}
        Write-Ok 'Managed state restored.';Write-Log "Restore completed from $dir"
    }catch{Write-Fail $_.Exception.Message;Write-Log $_.Exception.Message 'ERROR'};Pause-Tui
}

function Invoke-RestartSpooler {Stop-Service Spooler -Force;Start-Service Spooler;Write-Ok 'Print Spooler restarted.'}
function Invoke-ClearPrintQueue {Write-Warn 'This permanently removes pending print jobs and cannot be restored.';if(-not(Read-YesNo 'Continue?' $true)){return};Stop-Service Spooler -Force -ErrorAction SilentlyContinue;$q="$env:SystemRoot\System32\spool\PRINTERS";if(Test-Path $q){Get-ChildItem $q -Force -ErrorAction SilentlyContinue|Remove-Item -Force -Recurse -ErrorAction SilentlyContinue};Start-Service Spooler -ErrorAction SilentlyContinue;Write-Ok 'Pending queue files cleared.';Write-Log 'Queue cleared; irreversible.' 'WARN'}

function Enable-PrivateFirewallSharing {
    if(-not(Get-Command Set-NetFirewallRule -ErrorAction SilentlyContinue)){Write-Warn 'Modern firewall cmdlets unavailable.';return}
    $rules=Get-FirewallSharingRules;if(-not $rules.Count){Write-Warn 'File and Printer Sharing firewall group could not be identified.';return}
    $count=0;foreach($r in $rules){if([string]$r.Profile -match 'Private|Domain|Any'){Set-NetFirewallRule -Name $r.Name -Enabled True -Profile Domain,Private -ErrorAction SilentlyContinue;$count++}};Write-Ok "Enabled/limited $count sharing firewall rule(s) to Domain/Private."
}

function Select-NetworkProfile {
    $p=@(Get-NetworkProfilesSafe|Where-Object{$_.IPv4Connectivity -ne 'Disconnected'});if(-not $p.Count){Write-Warn 'No active network profile found.';return $null}
    for($i=0;$i -lt $p.Count;$i++){Write-Host ('[{0}] {1} / {2} / {3}' -f ($i+1),$p[$i].InterfaceAlias,$p[$i].Name,$p[$i].NetworkCategory)}
    $allowed=@(1..$p.Count|ForEach-Object{[string]$_})+'B';$c=Read-Choice 'Select interface, or B' $allowed;if($c -eq 'B'){return $null};return $p[[int]$c-1]
}
function Set-OneNetworkPrivate {if(-not(Get-Command Set-NetConnectionProfile -ErrorAction SilentlyContinue)){Write-Warn 'Set-NetConnectionProfile unavailable.';return};$p=Select-NetworkProfile;if($null -eq $p){return};if($p.NetworkCategory -eq 'DomainAuthenticated'){Write-Warn 'DomainAuthenticated profiles should be controlled by domain policy.';return};Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private;Write-Ok "Interface $($p.InterfaceAlias) is now Private."}
function Start-NetworkDiscoveryServices {foreach($n in @('fdPHost','FDResPub')){if(Get-Service $n -ErrorAction SilentlyContinue){Start-Service $n -ErrorAction SilentlyContinue}};Write-Ok 'Network Discovery services requested.'}

function Show-SafeRepairMenu {
    while($true){Write-Header 'SAFE REPAIR';Write-Info 'Safe Repair never disables RPC privacy, Point and Print protection, SMB security, or blank-password restrictions.';Write-Host '[1] Restart Print Spooler';Write-Host '[2] Clear stuck queue (removes pending jobs)';Write-Host '[3] Enable File and Printer Sharing firewall rules for Private/Domain only';Write-Host '[4] Change one selected active network to Private';Write-Host '[5] Start Network Discovery services';Write-Host '[6] Run all non-destructive safe repairs';Write-Host "[B] $(T 'Back')";$c=Read-Choice (T 'Select') @('1','2','3','4','5','6','B');if($c -eq 'B'){return};$snap=New-RestoreSnapshot "Safe Repair option $c";if(-not $snap){Pause-Tui;continue};try{switch($c){'1'{Invoke-RestartSpooler};'2'{Invoke-ClearPrintQueue};'3'{Enable-PrivateFirewallSharing};'4'{Set-OneNetworkPrivate};'5'{Start-NetworkDiscoveryServices};'6'{Invoke-RestartSpooler;Enable-PrivateFirewallSharing;Start-NetworkDiscoveryServices}}}catch{Write-Fail $_.Exception.Message};Write-Info "Restore snapshot: $snap";Pause-Tui}
}

function Set-RpcNamedPipeFallback {
    $d=Invoke-Diagnosis -Quiet;$snap=New-RestoreSnapshot 'RPC Named Pipes compatibility fallback';if(-not $snap){return};Write-Warn 'RPC over TCP is the Windows default. Named Pipes is a compatibility fallback.'
    if($d.Role -match 'Client' -or $d.Role -eq 'Unknown / local only'){Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol' 1;Write-Ok 'Client outgoing printer RPC set to Named Pipes fallback.'}
    if($d.Role -match 'Host' -or $d.Role -eq 'Unknown / local only'){Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcProtocols' 7;Write-Ok 'Print host RPC listener set to allow supported protocol families.'};Write-Info "Restore snapshot: $snap"
}

function Connect-SharedPrinterTemporarilyRelaxed {
    $unc=(Read-Host 'Shared printer path, e.g. \\PRINT-PC\OfficePrinter').Trim();if($unc -notmatch '^\\\\[^\\]+\\[^\\]+$'){Write-Warn 'Invalid printer UNC path.';return}
    $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint';$original=Get-RegistryValueState $path 'RestrictDriverInstallationToAdministrators';$snap=New-RestoreSnapshot 'Temporary Point and Print relaxation';if(-not $snap){return}
    Write-Warn 'This temporarily reduces Point and Print driver-installation protection. It will be restored immediately after the connection attempt.';if((Read-Host 'Type RISK to continue').Trim().ToUpperInvariant() -ne 'RISK'){return}
    try{Set-RegistryDword $path 'RestrictDriverInstallationToAdministrators' 0;if(Get-Command Add-Printer -ErrorAction SilentlyContinue){Add-Printer -ConnectionName $unc}else{Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /in /n "{0}"' -f $unc) -Wait};Write-Ok "Connection attempt completed: $unc"}catch{Write-Fail $_.Exception.Message}finally{Restore-RegistryValue ([pscustomobject]@{Path=$path;Name='RestrictDriverInstallationToAdministrators';Present=$original.Present;Value=$original.Value;Kind=$original.Kind});Write-Ok 'Point and Print protection returned to its previous state.'}
}

function Set-RpcPrivacyCompatibility {Write-Header 'RPC PRIVACY COMPATIBILITY';Write-Fail 'This disables RPC packet-level privacy enforcement for incoming printer connections.';Write-Warn 'Use only for proven legacy incompatibility and restore it after testing.';if((Read-Host 'Type RISK to continue').Trim().ToUpperInvariant() -ne 'RISK'){return};$snap=New-RestoreSnapshot 'High-risk RPC privacy workaround';if($snap){Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' 'RpcAuthnLevelPrivacyEnabled' 0;Write-Warn 'RPC packet privacy is now disabled.';Write-Info "Restore snapshot: $snap"}}

function Show-WppHelp {$w=Get-WppState;if($w.Enabled){Write-Warn 'Windows Protected Print Mode appears enabled.';Write-Info 'Legacy third-party-driver printers may be removed or blocked.';if($w.GroupPolicy.Present -and [int]$w.GroupPolicy.Value -eq 1){Write-Warn 'WPP appears policy-enforced. This utility will not bypass organizational policy.'}else{Write-Info 'Manage WPP in Settings > Bluetooth & devices > Printers & scanners > Printer preferences.';if(Read-YesNo 'Open Settings now?' $false){Start-Process 'ms-settings:printers'}}}else{Write-Ok 'WPP is not detected as enabled.'}}

function Reset-ClientPrinterConnectionTargeted {$p=@(Get-PrinterInventory|Where-Object{$_.Name -like '\\*' -or $_.Type -eq 'Connection'});if(-not $p.Count){Write-Warn 'No network printer connection detected.';return};for($i=0;$i -lt $p.Count;$i++){Write-Host ('[{0}] {1}' -f ($i+1),$p[$i].Name)};$allowed=@(1..$p.Count|ForEach-Object{[string]$_})+'B';$c=Read-Choice 'Choose one connection to remove, or B' $allowed;if($c -eq 'B'){return};$target=$p[[int]$c-1].Name;$snap=New-RestoreSnapshot "Targeted connection removal: $target";if(-not $snap -or -not(Read-YesNo "Remove only $target ?" $true)){return};if(Get-Command Remove-Printer -ErrorAction SilentlyContinue){Remove-Printer -Name $target}else{Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /dn /n "{0}"' -f $target) -Wait};Write-Ok "Removed targeted connection: $target";Write-Info 'Reconnect the same UNC path after restarting the spooler.'}

function Show-CompatibilityMenu {while($true){Write-Header 'COMPATIBILITY REPAIR';Write-Host '[1] RPC Named Pipes fallback (role-aware; keeps RPC privacy)';Write-Host '[2] Connect shared printer with TEMPORARY Point and Print relaxation';Write-Host '[3] Check Windows Protected Print Mode (WPP)';Write-Host '[4] Remove one targeted network-printer connection for clean reconnect';Write-Host '[5] Disable RPC packet privacy [HIGH RISK]';Write-Host "[B] $(T 'Back')";$c=Read-Choice (T 'Select') @('1','2','3','4','5','B');if($c -eq 'B'){return};try{switch($c){'1'{Set-RpcNamedPipeFallback};'2'{Connect-SharedPrinterTemporarilyRelaxed};'3'{Show-WppHelp};'4'{Reset-ClientPrinterConnectionTargeted};'5'{Set-RpcPrivacyCompatibility}}}catch{Write-Fail $_.Exception.Message};Pause-Tui}}

function Enable-Smb1ClientLegacy {Write-Fail 'SMB1 is obsolete and unsafe. Use only when a specific old device is proven SMB1-only.';if((Read-Host 'Type LEGACY to continue').Trim().ToUpperInvariant() -ne 'LEGACY'){return};$snap=New-RestoreSnapshot 'Enable SMB1 client';if($snap -and (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue)){Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart|Out-Null;Write-Warn 'SMB1 CLIENT enabled. SMB1 server was not enabled.';Write-Info "Restore snapshot: $snap"}}
function Enable-InsecureGuestLegacy {Write-Fail 'Insecure guest SMB authentication weakens credential protection.';if((Read-Host 'Type LEGACY to continue').Trim().ToUpperInvariant() -ne 'LEGACY'){return};$snap=New-RestoreSnapshot 'Enable insecure SMB guest';if($snap){Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth' 1;Write-Warn 'Insecure SMB guest authentication enabled.';Write-Info "Restore snapshot: $snap"}}
function Set-LegacyLmCompatibility {Write-Fail 'This lowers machine-wide LAN Manager/NTLM authentication compatibility.';if((Read-Host 'Type LEGACY to continue').Trim().ToUpperInvariant() -ne 'LEGACY'){return};$snap=New-RestoreSnapshot 'Legacy LAN Manager level';if($snap){Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LmCompatibilityLevel' 1;Write-Warn 'LmCompatibilityLevel=1 applied. Restore after testing.';Write-Info "Restore snapshot: $snap"}}

function Show-LegacyMenu {while($true){Write-Header 'LEGACY COMPATIBILITY';Write-Fail 'There is intentionally no one-click insecure Full Fix anymore.';Write-Host '[1] Enable SMB1 CLIENT only';Write-Host '[2] Allow insecure SMB guest authentication';Write-Host '[3] Set LAN Manager compatibility level 1 [VERY HIGH RISK]';Write-Host '[4] Blank-password remote logon: NOT AUTOMATED (use a password instead)';Write-Host "[B] $(T 'Back')";$c=Read-Choice (T 'Select') @('1','2','3','4','B');if($c -eq 'B'){return};try{switch($c){'1'{Enable-Smb1ClientLegacy};'2'{Enable-InsecureGuestLegacy};'3'{Set-LegacyLmCompatibility};'4'{Write-Warn 'This utility intentionally refuses to disable LimitBlankPasswordUse. Use password-protected credentials instead.'}}}catch{Write-Fail $_.Exception.Message};Pause-Tui}}

function Export-DiagnosticText {$d=Invoke-Diagnosis -Quiet;$path=Join-Path $script:LogRoot ('diagnostic-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'));$lines=@("Windows Printer Sharing Fix v$($script:Version) - Diagnostic Report","Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')","OS: $($d.OS.Name) $($d.OS.DisplayVersion) build $($d.OS.Build)","Role: $($d.Role)","Spooler: $(if($d.Spooler){$d.Spooler.Status}else{'Missing'})","WPP enabled: $($d.WPP.Enabled)","SMB1 client: $($d.SMB1Client)",'','Findings:');foreach($f in $d.Findings){$lines+="[$($f.Severity)] $($f.Text)"};$lines+='';$lines+='Printers:';foreach($p in $d.Printers){$lines+="- $($p.Name) | driver=$($p.DriverName) | share=$($p.ShareName)"};$lines|Set-Content -LiteralPath $path -Encoding UTF8;Write-Ok "Diagnostic report exported: $path"}

function Show-ToolsMenu {while($true){Write-Header 'TOOLS AND LOGS';Write-Host '[1] Printers & scanners Settings';Write-Host '[2] Print Management';Write-Host '[3] Services';Write-Host '[4] Network Connections';Write-Host '[5] Open current log';Write-Host '[6] Open backup folder';Write-Host '[7] Export fresh diagnostic report';Write-Host '[8] Test a shared printer path';Write-Host "[B] $(T 'Back')";$c=Read-Choice (T 'Select') @('1','2','3','4','5','6','7','8','B');if($c -eq 'B'){return};switch($c){'1'{Start-Process 'ms-settings:printers' -ErrorAction SilentlyContinue};'2'{Start-Process 'printmanagement.msc' -ErrorAction SilentlyContinue};'3'{Start-Process 'services.msc'};'4'{Start-Process 'ncpa.cpl'};'5'{Start-Process notepad.exe -ArgumentList ('"{0}"' -f $script:CurrentLog)};'6'{Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:BackupRoot)};'7'{Export-DiagnosticText;Pause-Tui};'8'{Invoke-SharedPrinterPathDiagnosis;Pause-Tui}}}}

function Show-LanguageMenu {Write-Header 'LANGUAGE';Write-Host '[1] English (default)';Write-Host '[2] Indonesia';Write-Host "[B] $(T 'Back')";$c=Read-Choice (T 'Select') @('1','2','B');if($c -eq 'B'){return};$script:Language=if($c -eq '2'){'ID'}else{'EN'};$script:Language|Set-Content -LiteralPath $script:LanguageFile -Encoding ASCII}

function Show-MainMenu {
    while($true){Write-Header (T 'Main');$os=Get-OsInfo;$spool=Get-Service Spooler -ErrorAction SilentlyContinue;Write-Host ('  OS: {0} build {1}    Language: {2}    Spooler: {3}' -f $os.Name,$os.Build,$script:Language,$(if($spool){$spool.Status}else{'Missing'})) -ForegroundColor DarkGray;Write-Rule;Write-Host "[1] $(T 'Diagnose')  <$(T 'Recommended')>" -ForegroundColor Green;Write-Host "[2] $(T 'Safe')";Write-Host "[3] $(T 'Compat')";Write-Host "[4] $(T 'Legacy')" -ForegroundColor Yellow;Write-Host "[5] $(T 'Restore')";Write-Host "[6] $(T 'Tools')";Write-Host "[7] $(T 'Language')";Write-Host "[8] $(T 'Exit')";Write-Rule;$c=Read-Choice (T 'Select') @('1','2','3','4','5','6','7','8');switch($c){'1'{[void](Invoke-Diagnosis)};'2'{Show-SafeRepairMenu};'3'{Show-CompatibilityMenu};'4'{Show-LegacyMenu};'5'{Invoke-RestoreLatest};'6'{Show-ToolsMenu};'7'{Show-LanguageMenu};'8'{return}}}
}

try {
    Initialize-Workspace
    if(-not(Ensure-Administrator)){if(-not(Test-IsAdministrator)){exit 0}}
    Show-MainMenu
} catch {
    Write-Host "Fatal error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log $_.Exception.ToString() 'FATAL'
    Pause-Tui
    exit 1
}
