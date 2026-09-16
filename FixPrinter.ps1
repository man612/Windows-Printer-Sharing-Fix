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

$script:Version = '4.0.3'
$script:ScriptPath = $PSCommandPath
$script:Root = Split-Path -Parent $script:ScriptPath
$script:LegacyBackupRoot = Join-Path $script:Root 'backups'
$script:LegacyLanguageFile = Join-Path $script:Root 'language.cfg'
$script:Language = 'EN'

function Set-WorkspacePaths([string]$DataRoot) {
    $script:DataRoot = $DataRoot
    $script:BackupRoot = Join-Path $DataRoot 'backups'
    $script:LogRoot = Join-Path $DataRoot 'logs'
    $script:ExportRoot = Join-Path $DataRoot 'exports'
    $script:LanguageFile = Join-Path $DataRoot 'language.cfg'
    $script:LatestStateFile = Join-Path $script:BackupRoot 'latest_backup.txt'
}

$preferredDataRoot = if ($env:WPSF_DATA_ROOT) { $env:WPSF_DATA_ROOT } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'WindowsPrinterSharingFix' } elseif ($env:TEMP) { Join-Path $env:TEMP 'WindowsPrinterSharingFix' } else { Join-Path $script:Root '.runtime' }
Set-WorkspacePaths $preferredDataRoot
$script:CurrentLog = $null
$script:LastDiagnostic = $null
$script:LastTargetPathDiagnostic = $null

$script:Text = @{
    EN = @{
        Title='WINDOWS PRINTER SHARING FIX'; Subtitle='Diagnosis-first repair utility'; Main='MAIN MENU'; Diagnose='Diagnose this PC'; Safe='Safe Repair'; Compat='Compatibility Repair (Advanced)'; Legacy='Legacy Compatibility (High Risk)'; Restore='Restore latest managed changes'; Tools='Tools and Logs'; Guide='Guide'; Language='Language'; Exit='Exit'; Select='Select'; Back='Back'; Recommended='RECOMMENDED'; Invalid='Invalid selection.'; Press='Press Enter to continue';
    }
    ID = @{
        Title='WINDOWS PRINTER SHARING FIX'; Subtitle='Utilitas diagnosis dan perbaikan printer sharing'; Main='MENU UTAMA'; Diagnose='Diagnosis PC ini'; Safe='Perbaikan Aman'; Compat='Perbaikan Kompatibilitas (Lanjutan)'; Legacy='Kompatibilitas Legacy (Risiko Tinggi)'; Restore='Kembalikan perubahan terakhir'; Tools='Alat dan Log'; Guide='Panduan'; Language='Bahasa'; Exit='Keluar'; Select='Pilih'; Back='Kembali'; Recommended='DISARANKAN'; Invalid='Pilihan tidak valid.'; Press='Tekan Enter untuk lanjut';
    }
}

function T([string]$Key) {
    if ($script:Text[$script:Language].ContainsKey($Key)) { return $script:Text[$script:Language][$Key] }
    return $script:Text.EN[$Key]
}

function L([string]$English,[string]$Indonesian) {
    if ($script:Language -eq 'ID') { return $Indonesian }
    return $English
}

function Localize-SystemValue([string]$Value) {
    if ($script:Language -ne 'ID') { return $Value }
    $map = @{
        'Running'='Berjalan'; 'Stopped'='Berhenti'; 'Missing'='Tidak ditemukan';
        'Host'='Host'; 'Client'='Klien'; 'Host + Client'='Host + Klien'; 'Unknown / local only'='Tidak diketahui / lokal saja';
        'Public'='Publik'; 'Private'='Privat'; 'DomainAuthenticated'='Domain';
        'Connected'='Terhubung'; 'Disconnected'='Terputus';
        'Enabled'='Aktif'; 'Disabled'='Tidak aktif'; 'Unknown'='Tidak diketahui'
    }
    if ($map.ContainsKey($Value)) { return $map[$Value] }
    if ($Value -match '^Enabled') { return ($Value -replace '^Enabled','Aktif') }
    if ($Value -match '^Disabled') { return ($Value -replace '^Disabled','Tidak aktif') }
    return $Value
}

function Initialize-Workspace {
    try {
        foreach ($dir in @($script:DataRoot,$script:BackupRoot,$script:LogRoot,$script:ExportRoot)) {
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
    } catch {
        $fallbackRoot = if ($env:TEMP) { Join-Path $env:TEMP 'WindowsPrinterSharingFix' } else { Join-Path $script:Root '.runtime' }
        Set-WorkspacePaths $fallbackRoot
        foreach ($dir in @($script:DataRoot,$script:BackupRoot,$script:LogRoot,$script:ExportRoot)) {
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
    }

    if (-not (Test-Path -LiteralPath $script:LanguageFile) -and (Test-Path -LiteralPath $script:LegacyLanguageFile)) {
        $legacyLanguage = Get-Content -LiteralPath $script:LegacyLanguageFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $legacyLanguage -and ([string]$legacyLanguage).Trim().ToUpperInvariant() -in @('EN','ID')) {
            ([string]$legacyLanguage).Trim().ToUpperInvariant() | Set-Content -LiteralPath $script:LanguageFile -Encoding ASCII
        }
    }
    if (-not (Test-Path -LiteralPath $script:LatestStateFile) -and (Test-Path -LiteralPath $script:LegacyBackupRoot)) {
        $legacyLatest = Join-Path $script:LegacyBackupRoot 'latest_backup.txt'
        if (Test-Path -LiteralPath $legacyLatest) {
            $legacySnapshot = ([string](Get-Content -LiteralPath $legacyLatest -ErrorAction SilentlyContinue | Select-Object -First 1)).Trim()
            Copy-Item -Path (Join-Path $script:LegacyBackupRoot '*') -Destination $script:BackupRoot -Recurse -Force -ErrorAction SilentlyContinue
            if ($legacySnapshot) {
                $snapshotName = Split-Path -Leaf $legacySnapshot
                $migratedSnapshot = Join-Path $script:BackupRoot $snapshotName
                if (Test-Path -LiteralPath $migratedSnapshot) { $migratedSnapshot | Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8 }
            }
        }
    }
    if (Test-Path -LiteralPath $script:LanguageFile) {
        $rawLanguage = Get-Content -LiteralPath $script:LanguageFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $rawLanguage) {
            $value = ([string]$rawLanguage).Trim().ToUpperInvariant()
            if ($value -in @('EN','ID')) { $script:Language = $value }
        }
    }
    $script:CurrentLog = Join-Path $script:LogRoot ('printer-fix-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Write-Log "Windows Printer Sharing Fix v$($script:Version) started. data=$script:DataRoot"
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
    Write-Host (L 'Requesting Administrator access...' 'Meminta akses Administrator...') -ForegroundColor Yellow
    try {
        $argumentLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $script:ScriptPath
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $script:Root -ArgumentList $argumentLine
    } catch {
        Write-Host ((L 'Could not obtain Administrator access: {0}' 'Tidak dapat memperoleh akses Administrator: {0}') -f $_.Exception.Message) -ForegroundColor Red
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

function Resolve-WindowsProductName([string]$ProductName,[string]$InstallationType,[int]$Build) {
    $isServer = ($ProductName -match 'Server') -or ($InstallationType -match 'Server')
    if ($isServer) { return $ProductName }
    if ($Build -ge 22000) { return 'Windows 11' }
    if ($Build -ge 10240) { return 'Windows 10' }
    return $ProductName
}

function Get-OsInfo {
    $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $getProp = { param($Object,$Name,$Default='') $p=$Object.PSObject.Properties[$Name]; if($p){[string]$p.Value}else{$Default} }
    $buildText = & $getProp $key 'CurrentBuild' '0'
    $build = 0; [void][int]::TryParse($buildText,[ref]$build)
    $productName = & $getProp $key 'ProductName' 'Windows'
    $installationType = & $getProp $key 'InstallationType' ''
    $name = Resolve-WindowsProductName $productName $installationType $build
    $isServer = ($productName -match 'Server') -or ($installationType -match 'Server')
    $display = & $getProp $key 'DisplayVersion' (& $getProp $key 'ReleaseId' '')
    return [pscustomobject]@{Name=$name;Build=$build;DisplayVersion=$display;InstallationType=$installationType;IsServer=$isServer}
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
    $enabledBy=Get-RegistryValueState $path 'EnabledBy'
    return [pscustomobject]@{Enabled=(($gp.Present -and [int]$gp.Value -eq 1) -or ($mode.Present -and [int]$mode.Value -eq 1));GroupPolicy=$gp;Mode=$mode;EnabledBy=$enabledBy}
}

function Get-WindowsFeatureState([string]$Name) {
    try { if (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) { return [string](Get-WindowsOptionalFeature -Online -FeatureName $Name).State } } catch {}
    return 'Unknown'
}

function Get-FirewallSharingRules {
    try {
        if (-not (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue)) { return @() }
        $rules=@(Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction SilentlyContinue)
        if(-not $rules.Count){
            $rules=@(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {$_.Group -eq '@FirewallAPI.dll,-28502' -or $_.DisplayGroup -eq 'File and Printer Sharing' -or $_.DisplayGroup -eq 'Berbagi File dan Printer'})
        }
        return @($rules | Select-Object Name,DisplayName,DisplayGroup,Enabled,Profile,Direction,Action)
    } catch { Write-Log $_.Exception.Message 'WARN'; return @() }
}

function Get-PrintServiceWin32CodeClass([object]$Code=$null) {
    if($null -eq $Code){return $null}
    try{$n=[int64]$Code}catch{return 'OtherWin32'}
    if($n -eq 0){return 'AmbiguousSuccessCode'}
    if($n -in @(2,3,3002)){return 'FileOrSpoolPath'}
    if($n -in @(5,65)){return 'AccessOrPermission'}
    if($n -in @(53,64,67)){return 'NetworkPathOrName'}
    if($n -in @(61,62,63,72,3009,3020)){return 'QueueOrSpool'}
    if($n -in @(1722,1726,1727)){return 'Rpc'}
    if($n -in @(1796,1797,1798,1801,1804,1905,1906,3000,3007,3012,3013,3014,3015,3016,3019,3021,3022)){return 'PrinterOrDriverState'}
    return 'OtherWin32'
}

function Get-PrintServiceEventClassification([int]$Id,[object]$Win32Code=$null) {
    $category='OtherPrintService'
    if($Id -in @(107,111,123,125,314,350,353,372,828)){$category='PrintJob'}
    elseif($Id -in @(115,213,215,217,219,348,351,359,368,369,370,600,601,808,852,869,870) -or ($Id -ge 225 -and $Id -le 242)){$category='DriverOrPackage'}
    elseif($Id -in @(101,119,201,205,207,211,221,224,315,371,513,514,515,516,517,518,519,520,827)){$category='SharingOrConnection'}
    elseif($Id -in @(99,354,362,373,815,816,817,818) -or ($Id -ge 502 -and $Id -le 512)){$category='SpoolerOrRpc'}
    elseif($Id -in @(319,320,361,364,365,367,814,820,822,824,825,867) -or ($Id -ge 701 -and $Id -le 704)){$category='PortOrProcessor'}
    elseif($Id -in @(851,871)){$category='Policy'}
    elseif($Id -in @(322,323,325,326,327,328,329,331,333,335,337,347)){$category='DirectoryOrGpo'}
    return [pscustomobject]@{Category=$category;Win32Code=if($null -ne $Win32Code){[int64]$Win32Code}else{$null};CodeClass=(Get-PrintServiceWin32CodeClass $Win32Code)}
}

function Get-PrintServiceEventWin32Code($Event) {
    if($null -eq $Event -or [int]$Event.Id -ne 372){return $null}
    try {
        if($Event.Properties -and $Event.Properties.Count -gt 9 -and $null -ne $Event.Properties[9].Value){return [int64]$Event.Properties[9].Value}
    } catch {}
    return $null
}

function Get-PrintServiceCategoryLabel([string]$Category) {
    switch($Category){
        'PrintJob'{return (L 'print job' 'job cetak')}
        'DriverOrPackage'{return (L 'driver/package' 'driver/paket')}
        'SharingOrConnection'{return (L 'sharing/connection' 'sharing/koneksi')}
        'SpoolerOrRpc'{return 'Spooler/RPC'}
        'PortOrProcessor'{return (L 'port/processor' 'port/processor')}
        'Policy'{return (L 'policy' 'kebijakan')}
        'DirectoryOrGpo'{return (L 'directory/GPO' 'direktori/GPO')}
        default{return (L 'other' 'lainnya')}
    }
}

function Get-PrintServiceCodeClassLabel([string]$CodeClass) {
    switch($CodeClass){
        'AmbiguousSuccessCode'{return (L 'ambiguous code 0' 'kode 0 ambigu')}
        'FileOrSpoolPath'{return (L 'file/spool path' 'file/path spool')}
        'AccessOrPermission'{return (L 'access/permission' 'akses/izin')}
        'NetworkPathOrName'{return (L 'network path/name' 'path/nama jaringan')}
        'QueueOrSpool'{return (L 'queue/spool' 'antrean/spool')}
        'Rpc'{return 'RPC'}
        'PrinterOrDriverState'{return (L 'printer/driver state' 'status printer/driver')}
        'OtherWin32'{return (L 'other Win32 code' 'kode Win32 lain')}
        default{return ''}
    }
}

function Get-RecentPrintErrors {
    try {
        $events=@(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Admin';Level=2,3;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 8)
        return @($events|ForEach-Object{
            $code=Get-PrintServiceEventWin32Code $_
            $classification=Get-PrintServiceEventClassification ([int]$_.Id) $code
            [pscustomobject]@{TimeCreated=$_.TimeCreated;Id=[int]$_.Id;LevelDisplayName=[string]$_.LevelDisplayName;Message=[string]$_.Message;Category=$classification.Category;Win32Code=$classification.Win32Code;CodeClass=$classification.CodeClass}
        })
    } catch { return @() }
}

function Resolve-HostAddresses([string]$ComputerName,[int]$TimeoutMs=2500) {
    $async=$null
    try {
        $async=[System.Net.Dns]::BeginGetHostAddresses($ComputerName,$null,$null)
        if(-not $async.AsyncWaitHandle.WaitOne($TimeoutMs,$false)){return @()}
        return @([System.Net.Dns]::EndGetHostAddresses($async))
    } catch { return @() }
    finally { if($async -and $async.AsyncWaitHandle){$async.AsyncWaitHandle.Close()} }
}

function Test-TcpPort([string]$ComputerName,[int]$Port,[int]$TimeoutMs=2500,[System.Net.IPAddress[]]$Addresses=$null) {
    $targets=@(if($PSBoundParameters.ContainsKey('Addresses')){@($Addresses)}else{@(Resolve-HostAddresses $ComputerName $TimeoutMs)})
    if(-not $targets.Count){return $false}
    $clock=[System.Diagnostics.Stopwatch]::StartNew()
    foreach($address in $targets){
        $remaining=$TimeoutMs-[int]$clock.ElapsedMilliseconds
        if($remaining -le 0){return $false}
        $client=New-Object System.Net.Sockets.TcpClient($address.AddressFamily)
        $async=$null
        try {
            $async=$client.BeginConnect($address,$Port,$null,$null)
            if($async.AsyncWaitHandle.WaitOne($remaining,$false)){
                $client.EndConnect($async)
                if($client.Connected){return $true}
            }
        } catch {}
        finally {
            if($async -and $async.AsyncWaitHandle){$async.AsyncWaitHandle.Close()}
            $client.Close()
        }
    }
    return $false
}

function Invoke-Diagnosis([switch]$Quiet) {
    $script:LastTargetPathDiagnostic = $null
    $diagClock=[System.Diagnostics.Stopwatch]::StartNew();$step=[System.Diagnostics.Stopwatch]::StartNew()
    $os=Get-OsInfo;$osMs=$step.ElapsedMilliseconds;$step.Restart()
    $spooler=Get-Service Spooler -ErrorAction SilentlyContinue;$spoolerMs=$step.ElapsedMilliseconds;$step.Restart()
    $printers=@(Get-PrinterInventory);$printersMs=$step.ElapsedMilliseconds;$step.Restart()
    $profiles=@(Get-NetworkProfilesSafe);$profilesMs=$step.ElapsedMilliseconds;$step.Restart()
    $wpp=Get-WppState;$wppMs=$step.ElapsedMilliseconds;$step.Restart()
    $errors=@(Get-RecentPrintErrors);$eventsMs=$step.ElapsedMilliseconds
    $shared=@($printers|Where-Object{$_.Shared -or $_.ShareName})
    $connections=@($printers|Where-Object{$_.Name -like '\\*' -or $_.Type -eq 'Connection'})
    $role=if($shared.Count -and $connections.Count){'Host + Client'}elseif($shared.Count){'Host'}elseif($connections.Count){'Client'}else{'Unknown / local only'}
    $rpcPrivacy=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' 'RpcAuthnLevelPrivacyEnabled'
    $rpcPipe=Get-RegistryValueState 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol'
    $rpcProtocols=Get-RegistryValueState 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcProtocols'
    $point=Get-RegistryValueState 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' 'RestrictDriverInstallationToAdministrators'
    $guest=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth'
    $lm=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LmCompatibilityLevel'
    $blank=Get-RegistryValueState 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LimitBlankPasswordUse'
    $step.Restart();$smb1=Get-WindowsFeatureState 'SMB1Protocol-Client';$smb1Ms=$step.ElapsedMilliseconds
    $findings=New-Object System.Collections.Generic.List[object]
    if(-not $spooler){$findings.Add([pscustomobject]@{Severity='FAIL';Text=(L 'Print Spooler service is missing.' 'Layanan Print Spooler tidak ditemukan.')})}elseif($spooler.Status -ne 'Running'){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L 'Print Spooler is not running.' 'Print Spooler sedang tidak berjalan.')})}
    if($wpp.Enabled){$findings.Add([pscustomobject]@{Severity='INFO';Text=(L 'Windows Protected Print Mode appears enabled. Legacy third-party printer drivers can be removed or blocked.' 'Windows Protected Print Mode tampak aktif. Driver printer pihak ketiga yang lama dapat dihapus atau diblokir.')})}
    if($rpcPrivacy.Present -and [int]$rpcPrivacy.Value -eq 0){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L 'RPC packet privacy hardening is disabled (RpcAuthnLevelPrivacyEnabled=0).' 'Penguatan privasi paket RPC sedang dinonaktifkan (RpcAuthnLevelPrivacyEnabled=0).')})}
    if($point.Present -and [int]$point.Value -eq 0){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L 'Point and Print driver-installation protection is disabled.' 'Proteksi pemasangan driver Point and Print sedang dinonaktifkan.')})}
    if($guest.Present -and [int]$guest.Value -eq 1){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L 'Insecure SMB guest authentication is enabled.' 'Autentikasi guest SMB yang tidak aman sedang diaktifkan.')})}
    if($lm.Present -and [int]$lm.Value -le 2){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L "LAN Manager authentication is configured for legacy compatibility (level $($lm.Value))." "Autentikasi LAN Manager diatur untuk kompatibilitas lama (level $($lm.Value)).")})}
    if($blank.Present -and [int]$blank.Value -eq 0){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L 'Remote use of blank-password local accounts is allowed. This utility will never enable that setting.' 'Penggunaan remote akun lokal tanpa password diizinkan. Utilitas ini tidak akan pernah mengaktifkan pengaturan tersebut.')})}
    if($smb1 -match '^Enabled'){$findings.Add([pscustomobject]@{Severity='WARN';Text=(L 'SMB1 client is enabled.' 'Klien SMB1 sedang aktif.')})}
    if(@($profiles|Where-Object{$_.NetworkCategory -eq 'Public' -and $_.IPv4Connectivity -ne 'Disconnected'}).Count){$findings.Add([pscustomobject]@{Severity='INFO';Text=(L 'At least one active network is Public; sharing may be intentionally restricted.' 'Setidaknya satu jaringan aktif berprofil Publik; fitur sharing mungkin memang dibatasi.')})}
    if($errors.Count){
        $eventLayers=@($errors|Group-Object Category|ForEach-Object{('{0}={1}' -f (Get-PrintServiceCategoryLabel $_.Name),$_.Count)}) -join ', '
        $findings.Add([pscustomobject]@{Severity='INFO';Text=(L "Recent PrintService warnings/errors by layer: $eventLayers." "Peringatan/error PrintService terbaru menurut lapisan: $eventLayers.")})
    }
    $diagClock.Stop()
    $timing=[pscustomobject]@{OS=[int64]$osMs;Spooler=[int64]$spoolerMs;Printers=[int64]$printersMs;Profiles=[int64]$profilesMs;WPP=[int64]$wppMs;PrintEvents=[int64]$eventsMs;SMB1=[int64]$smb1Ms;Total=[int64]$diagClock.ElapsedMilliseconds}
    $result=[pscustomobject]@{CollectedAtUtc=(Get-Date).ToUniversalTime().ToString('o');OS=$os;PowerShell=$PSVersionTable.PSVersion.ToString();Role=$role;Spooler=$spooler;Printers=$printers;SharedPrinters=$shared;Connections=$connections;Profiles=$profiles;WPP=$wpp;PrintErrors=$errors;RpcPrivacy=$rpcPrivacy;RpcUseNamedPipe=$rpcPipe;RpcProtocols=$rpcProtocols;PointAndPrint=$point;GuestAuth=$guest;LmCompatibility=$lm;BlankPassword=$blank;SMB1Client=$smb1;Findings=$findings;TimingMs=$timing}
    $script:LastDiagnostic=$result
    Write-Log "Diagnosis role=$role printers=$($printers.Count) findings=$($findings.Count)"
    Write-Log "Diagnosis timing ms: os=$osMs spooler=$spoolerMs printers=$printersMs profiles=$profilesMs wpp=$wppMs events=$eventsMs smb1=$smb1Ms total=$($diagClock.ElapsedMilliseconds)"
    if(-not $Quiet){Show-DiagnosticReport $result}; return $result
}

function Show-DiagnosticReport($D) {
    Write-Header (L 'DIAGNOSTIC REPORT' 'LAPORAN DIAGNOSIS')
    $spoolerState = if($D.Spooler){Localize-SystemValue ([string]$D.Spooler.Status)}else{Localize-SystemValue 'Missing'}
    $wppState = if($D.WPP.Enabled){L 'ENABLED' 'AKTIF'}else{L 'not detected as enabled' 'tidak terdeteksi aktif'}
    Write-Host ('OS              : {0} {1} (build {2})' -f $D.OS.Name,$D.OS.DisplayVersion,$D.OS.Build)
    Write-Host ('PowerShell      : {0}' -f $D.PowerShell)
    Write-Host ((L 'Detected role   : {0}' 'Peran terdeteksi: {0}') -f (Localize-SystemValue $D.Role))
    Write-Host ('Print Spooler   : {0}' -f $spoolerState)
    Write-Host ((L 'Printers        : {0} total / {1} shared / {2} network connection(s)' 'Printer         : {0} total / {1} dishare / {2} koneksi jaringan') -f $D.Printers.Count,$D.SharedPrinters.Count,$D.Connections.Count)
    Write-Host ('WPP             : {0}' -f $wppState)
    Write-Host ((L 'SMB1 client     : {0}' 'Klien SMB1      : {0}') -f (Localize-SystemValue ([string]$D.SMB1Client)))
    Write-Rule
    if(-not $D.Findings.Count){Write-Ok (L 'No obvious critical problem was detected.' 'Tidak ditemukan masalah kritis yang terlihat jelas.')}
    foreach($f in $D.Findings){switch($f.Severity){'FAIL'{Write-Fail $f.Text};'WARN'{Write-Warn $f.Text};default{Write-Info $f.Text}}}
    if($D.SharedPrinters.Count){Write-Rule;Write-Host (L 'Shared printers:' 'Printer yang dishare:');foreach($p in $D.SharedPrinters){Write-Host ('  - {0} | share={1} | driver={2}' -f $p.Name,$p.ShareName,$p.DriverName)}}
    if($D.Connections.Count){Write-Rule;Write-Host (L 'Network printer connections:' 'Koneksi printer jaringan:');foreach($p in $D.Connections){Write-Host ('  - {0} | driver={1}' -f $p.Name,$p.DriverName)}}
    if($D.Profiles.Count){Write-Rule;Write-Host (L 'Network profiles:' 'Profil jaringan:');foreach($n in $D.Profiles){Write-Host ('  [{0}] {1} / {2} / IPv4={3}' -f $n.InterfaceIndex,$n.InterfaceAlias,(Localize-SystemValue ([string]$n.NetworkCategory)),(Localize-SystemValue ([string]$n.IPv4Connectivity)))}}
    if($D.PrintErrors.Count){Write-Rule;Write-Host (L 'Recent PrintService events:' 'Event PrintService terbaru:');foreach($e in $D.PrintErrors|Select-Object -First 5){$m=([string]$e.Message -replace '\s+',' ');if($m.Length -gt 120){$m=$m.Substring(0,120)+'...'};$layer=Get-PrintServiceCategoryLabel ([string]$e.Category);$code='';if($null -ne $e.Win32Code){$code=' | Win32={0}/{1}' -f $e.Win32Code,(Get-PrintServiceCodeClassLabel ([string]$e.CodeClass))};Write-Host ('  {0:g} ID {1} [{2}{3}]: {4}' -f $e.TimeCreated,$e.Id,$layer,$code,$m)}}
    Write-Rule; Write-Info ('Log: {0}' -f $script:CurrentLog)
    if(Read-YesNo (L 'Test a specific shared printer path now?' 'Tes path printer sharing tertentu sekarang?') $true){Invoke-SharedPrinterPathDiagnosis}
    Pause-Tui
}

function Invoke-SharedPrinterPathDiagnosis {
    Write-Rule; Write-Host (L 'SHARED PRINTER PATH TEST' 'TES PATH PRINTER SHARING') -ForegroundColor White
    $unc=(Read-Host (L 'Enter printer path like \\PRINT-PC\OfficePrinter (blank = cancel)' 'Masukkan path printer seperti \\PC-PRINT\PrinterKantor (kosong = batal)')).Trim(); if(-not $unc){return}
    if($unc -notmatch '^\\\\([^\\]+)\\([^\\]+)$'){Write-Warn (L 'Invalid UNC printer path.' 'Path UNC printer tidak valid.');return}
    $hostName=$Matches[1]
    $testedAt=(Get-Date).ToUniversalTime().ToString('o')
    $addresses=@(Resolve-HostAddresses $hostName 2500); $dns=($addresses.Count -gt 0)
    $smb=if($dns){Test-TcpPort $hostName 445 2500 $addresses}else{$false}; $rpc=if($dns){Test-TcpPort $hostName 135 2500 $addresses}else{$false}; $root=$false
    if($smb){try{$root=Test-Path -LiteralPath ("\\{0}\" -f $hostName) -ErrorAction SilentlyContinue}catch{}}
    $installed=@((Get-PrinterInventory)|Where-Object{$_.Name -eq $unc}).Count -gt 0
    if($dns){Write-Ok ((L 'Host resolves: {0}' 'Host berhasil di-resolve: {0}') -f $hostName)}else{Write-Fail ((L 'Host does not resolve: {0}' 'Host tidak dapat di-resolve: {0}') -f $hostName)}
    if($smb){Write-Ok (L 'TCP 445 (SMB) reachable.' 'TCP 445 (SMB) dapat dijangkau.')}else{Write-Fail (L 'TCP 445 (SMB) not reachable.' 'TCP 445 (SMB) tidak dapat dijangkau.')}
    if($rpc){Write-Ok (L 'TCP 135 (RPC Endpoint Mapper) reachable.' 'TCP 135 (RPC Endpoint Mapper) dapat dijangkau.')}else{Write-Warn (L 'TCP 135 (RPC Endpoint Mapper) not reachable.' 'TCP 135 (RPC Endpoint Mapper) tidak dapat dijangkau.')}
    if($root){Write-Ok ((L 'Host share namespace accessible: \\{0}' 'Namespace share host dapat diakses: \\{0}') -f $hostName)}elseif($smb){Write-Warn (L 'SMB port is reachable but the share namespace was not accessible; credentials, sharing, or policy may be involved.' 'Port SMB dapat dijangkau tetapi namespace share tidak dapat diakses; kredensial, pengaturan sharing, atau kebijakan Windows mungkin terlibat.')}
    if($installed){Write-Ok ((L 'Printer installed locally: {0}' 'Printer sudah terpasang lokal: {0}') -f $unc)}else{Write-Info ((L 'Printer not currently installed locally: {0}' 'Printer belum terpasang lokal: {0}') -f $unc)}
    Write-Rule
    $likelyLayer='HealthyPrerequisites'
    if(-not $dns){$likelyLayer='NameResolutionOrBasicNetwork';Write-Fail (L 'Most likely layer: name resolution/basic network. Do not change printer security policies yet.' 'Lapisan yang paling mungkin bermasalah: resolusi nama/jaringan dasar. Jangan ubah kebijakan keamanan printer dulu.')}
    elseif(-not $smb){$likelyLayer='SmbFirewallOrRouting';Write-Fail (L 'Most likely layer: SMB/firewall/routing. Do not enable SMB1 unless the target is proven SMB1-only.' 'Lapisan yang paling mungkin bermasalah: SMB/firewall/routing. Jangan aktifkan SMB1 kecuali target benar-benar terbukti hanya mendukung SMB1.')}
    elseif(-not $rpc){$likelyLayer='RpcReachability';Write-Warn (L 'RPC reachability is suspicious. Check RPC/firewall before compatibility fallbacks.' 'Konektivitas RPC mencurigakan. Periksa RPC/firewall sebelum memakai fallback kompatibilitas.')}
    elseif(-not $installed -and (Get-WppState).Enabled){$likelyLayer='WppCompatibility';Write-Warn (L 'WPP is enabled. If this printer depends on a legacy third-party driver, WPP compatibility is a strong candidate.' 'WPP aktif. Jika printer ini bergantung pada driver pihak ketiga yang lama, kompatibilitas WPP menjadi kandidat kuat.')}
    elseif(-not $installed){$likelyLayer='DriverPointAndPrintCredentialsOrShare';Write-Info (L 'Basic transport is reachable. Driver installation, Point and Print policy, credentials, or the remote printer share are the next likely layers.' 'Transport dasar dapat dijangkau. Lapisan berikutnya yang paling mungkin adalah pemasangan driver, kebijakan Point and Print, kredensial, atau share printer remote.')}
    else{Write-Ok (L 'Basic prerequisites look healthy. Printing a test page is the final functional verification.' 'Prasyarat dasar terlihat sehat. Mencetak test page adalah verifikasi fungsi terakhir.')}
    $script:LastTargetPathDiagnostic=[pscustomobject]@{TestedAtUtc=$testedAt;DnsResolved=[bool]$dns;Smb445Reachable=[bool]$smb;Rpc135Reachable=[bool]$rpc;ShareNamespaceAccessible=[bool]$root;PrinterInstalled=[bool]$installed;LikelyLayer=$likelyLayer}
    Write-Log "Target test [identifier omitted] dns=$dns smb445=$smb rpc135=$rpc root=$root installed=$installed likely=$likelyLayer"
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

function New-RestoreSnapshot([string]$Reason,[string[]]$Scopes=@('Registry','Services','Network','Firewall','SMB1'),[object[]]$FirewallRules=$null) {
    try {
        $dir=Join-Path $script:BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6));New-Item -ItemType Directory -Path $dir -Force|Out-Null
        $registry=@();$services=@();$profiles=@();$fw=@();$features=@()
        if($Scopes -contains 'Registry'){$registry=@(Get-ManagedRegistryEntries)}
        if($Scopes -contains 'Services'){foreach($name in @('Spooler','fdPHost','FDResPub')){try{$s=Get-CimInstance Win32_Service -Filter "Name='$name'";$services+=[pscustomobject]@{Name=$name;State=$s.State;StartMode=$s.StartMode}}catch{}}}
        if($Scopes -contains 'Network'){$profiles=@(Get-NetworkProfilesSafe|ForEach-Object{[pscustomobject]@{InterfaceIndex=[int]$_.InterfaceIndex;NetworkCategory=[string]$_.NetworkCategory}})}
        if($Scopes -contains 'Firewall'){$sourceRules=if($PSBoundParameters.ContainsKey('FirewallRules')){@($FirewallRules)}else{@(Get-FirewallSharingRules)};$fw=@($sourceRules|ForEach-Object{[pscustomobject]@{Name=[string]$_.Name;Enabled=[string]$_.Enabled;Profile=[string]$_.Profile}})}
        if($Scopes -contains 'SMB1'){$features=@([pscustomobject]@{Name='SMB1Protocol-Client';State=(Get-WindowsFeatureState 'SMB1Protocol-Client')})}
        $state=[pscustomobject]@{Version=$script:Version;Created=(Get-Date).ToString('o');Reason=$Reason;Scopes=@($Scopes);Registry=$registry;Services=$services;NetworkProfiles=$profiles;FirewallRules=$fw;WindowsFeatures=$features}
        $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $dir 'managed-state.json') -Encoding UTF8;$dir|Set-Content -LiteralPath $script:LatestStateFile -Encoding UTF8;Write-Log "Snapshot: $dir reason=$Reason scopes=$($Scopes -join ',')";return $dir
    } catch {Write-Fail ((L 'Snapshot failed: {0}' 'Pembuatan snapshot gagal: {0}') -f $_.Exception.Message);Write-Log $_.Exception.Message 'ERROR';return $null}
}

function Restore-ServiceStartMode([string]$Name,[string]$Mode){$map=@{Auto='Automatic';Automatic='Automatic';Manual='Manual';Disabled='Disabled'};if($map.ContainsKey($Mode)){Set-Service -Name $Name -StartupType $map[$Mode] -ErrorAction SilentlyContinue}}

function Invoke-RestoreLatest {
    Write-Header (L 'RESTORE' 'KEMBALIKAN PERUBAHAN')
    Write-Warn (L 'Restore reverts only the states captured for the latest v4 action. Deleted print jobs and removed printer connections cannot be recreated automatically.' 'Restore hanya mengembalikan kondisi yang disimpan oleh tindakan v4 terakhir. Print job yang sudah dihapus dan koneksi printer yang sudah dilepas tidak dapat dibuat ulang otomatis.')
    if(-not(Test-Path -LiteralPath $script:LatestStateFile)){Write-Warn (L 'No v4 restore snapshot exists yet.' 'Belum ada snapshot restore v4.');Pause-Tui;return}
    $dir=(Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1).Trim()
    $file=Join-Path $dir 'managed-state.json'
    if(-not(Test-Path -LiteralPath $file)){Write-Fail (L 'Latest snapshot is missing or damaged.' 'Snapshot terakhir tidak ditemukan atau rusak.');Pause-Tui;return}
    if(-not(Read-YesNo ((L 'Restore state from {0}?' 'Kembalikan kondisi dari {0}?') -f $dir) $true)){return}
    try{
        $state=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
        foreach($r in @($state.Registry)){Restore-RegistryValue $r}
        foreach($f in @($state.FirewallRules)){if(Get-Command Set-NetFirewallRule -ErrorAction SilentlyContinue){Set-NetFirewallRule -Name $f.Name -Enabled ([string]$f.Enabled) -Profile ([string]$f.Profile) -ErrorAction SilentlyContinue}}
        foreach($n in @($state.NetworkProfiles)){if(Get-Command Set-NetConnectionProfile -ErrorAction SilentlyContinue){Set-NetConnectionProfile -InterfaceIndex ([int]$n.InterfaceIndex) -NetworkCategory ([string]$n.NetworkCategory) -ErrorAction SilentlyContinue}}
        foreach($feature in @($state.WindowsFeatures)){if($feature.Name -eq 'SMB1Protocol-Client' -and (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)){$current=Get-WindowsFeatureState $feature.Name;if([string]$feature.State -match '^Enabled' -and $current -notmatch '^Enabled'){Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue|Out-Null}elseif([string]$feature.State -match '^Disabled' -and $current -notmatch '^Disabled'){Disable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue|Out-Null}}}
        foreach($s in @($state.Services)){Restore-ServiceStartMode $s.Name $s.StartMode;if($s.State -eq 'Running'){Start-Service $s.Name -ErrorAction SilentlyContinue}else{Stop-Service $s.Name -Force -ErrorAction SilentlyContinue}}
        Write-Ok (L 'Managed state restored.' 'Kondisi yang dikelola aplikasi berhasil dikembalikan.')
        Write-Log "Restore completed from $dir"
    }catch{Write-Fail $_.Exception.Message;Write-Log $_.Exception.Message 'ERROR'}
    Pause-Tui
}

function Invoke-RestartSpooler {
    Stop-Service Spooler -Force
    Start-Service Spooler
    Write-Ok (L 'Print Spooler restarted.' 'Print Spooler berhasil direstart.')
}

function Invoke-ClearPrintQueue {
    Write-Warn (L 'This permanently removes pending print jobs and cannot be restored.' 'Ini menghapus print job yang masih menunggu secara permanen dan tidak dapat dikembalikan.')
    if(-not(Read-YesNo (L 'Continue?' 'Lanjutkan?') $true)){return}
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    $q="$env:SystemRoot\System32\spool\PRINTERS"
    if(Test-Path $q){Get-ChildItem $q -Force -ErrorAction SilentlyContinue|Remove-Item -Force -Recurse -ErrorAction SilentlyContinue}
    Start-Service Spooler -ErrorAction SilentlyContinue
    Write-Ok (L 'Pending queue files cleared.' 'File antrean yang tertunda berhasil dibersihkan.')
    Write-Log 'Queue cleared; irreversible.' 'WARN'
}

function Enable-PrivateFirewallSharing([object[]]$FirewallRules=$null) {
    if(-not(Get-Command Set-NetFirewallRule -ErrorAction SilentlyContinue)){Write-Warn (L 'Modern firewall cmdlets unavailable.' 'Cmdlet firewall modern tidak tersedia.');return}
    $rules=@(if($PSBoundParameters.ContainsKey('FirewallRules')){@($FirewallRules)}else{@(Get-FirewallSharingRules)})
    if(-not $rules.Count){Write-Warn (L 'File and Printer Sharing firewall group could not be identified.' 'Grup firewall File and Printer Sharing tidak dapat diidentifikasi.');return}
    $count=0
    foreach($r in $rules){if([string]$r.Profile -match 'Private|Domain|Any'){Set-NetFirewallRule -Name $r.Name -Enabled True -Profile Domain,Private -ErrorAction SilentlyContinue;$count++}}
    Write-Ok ((L 'Enabled/limited {0} sharing firewall rule(s) to Domain/Private.' '{0} aturan firewall sharing diaktifkan/dibatasi hanya untuk Domain/Private.') -f $count)
}

function Select-NetworkProfile {
    $p=@(Get-NetworkProfilesSafe|Where-Object{$_.IPv4Connectivity -ne 'Disconnected'})
    if(-not $p.Count){Write-Warn (L 'No active network profile found.' 'Tidak ditemukan profil jaringan aktif.');return $null}
    for($i=0;$i -lt $p.Count;$i++){Write-Host ('[{0}] {1} / {2} / {3}' -f ($i+1),$p[$i].InterfaceAlias,$p[$i].Name,(Localize-SystemValue ([string]$p[$i].NetworkCategory)))}
    $allowed=@(1..$p.Count|ForEach-Object{[string]$_})+'B'
    $c=Read-Choice (L 'Select interface, or B' 'Pilih interface, atau B untuk kembali') $allowed
    if($c -eq 'B'){return $null}
    return $p[[int]$c-1]
}

function Set-OneNetworkPrivate {
    if(-not(Get-Command Set-NetConnectionProfile -ErrorAction SilentlyContinue)){Write-Warn (L 'Set-NetConnectionProfile unavailable.' 'Set-NetConnectionProfile tidak tersedia.');return}
    $p=Select-NetworkProfile;if($null -eq $p){return}
    if($p.NetworkCategory -eq 'DomainAuthenticated'){Write-Warn (L 'DomainAuthenticated profiles should be controlled by domain policy.' 'Profil DomainAuthenticated sebaiknya dikendalikan oleh kebijakan domain.');return}
    Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private
    Write-Ok ((L 'Interface {0} is now Private.' 'Interface {0} sekarang berprofil Privat.') -f $p.InterfaceAlias)
}

function Start-NetworkDiscoveryServices {
    foreach($n in @('fdPHost','FDResPub')){if(Get-Service $n -ErrorAction SilentlyContinue){Start-Service $n -ErrorAction SilentlyContinue}}
    Write-Ok (L 'Network Discovery services requested.' 'Layanan Network Discovery diminta untuk berjalan.')
}

function Show-SafeRepairMenu {
    while($true){
        Write-Header (L 'SAFE REPAIR' 'PERBAIKAN AMAN')
        Write-Info (L 'Safe Repair never disables RPC privacy, Point and Print protection, SMB security, or blank-password restrictions.' 'Perbaikan Aman tidak pernah menonaktifkan privasi RPC, proteksi Point and Print, keamanan SMB, atau pembatasan akun tanpa password.')
        Write-Rule
        Write-Host (L '[1] Restart Print Spooler' '[1] Restart Print Spooler')
        Write-Host (L '[2] Clear stuck queue (removes pending jobs)' '[2] Bersihkan antrean macet (menghapus job yang menunggu)')
        Write-Host (L '[3] Enable File and Printer Sharing firewall rules for Private/Domain only' '[3] Aktifkan firewall File and Printer Sharing hanya untuk Private/Domain')
        Write-Host (L '[4] Change one selected active network to Private' '[4] Ubah satu jaringan aktif yang dipilih menjadi Privat')
        Write-Host (L '[5] Start Network Discovery services' '[5] Jalankan layanan Network Discovery')
        Write-Host (L '[6] Run all non-destructive safe repairs' '[6] Jalankan semua perbaikan aman yang tidak destruktif')
        Write-Host "[B] $(T 'Back')"
        $c=Read-Choice (T 'Select') @('1','2','3','4','5','6','B');if($c -eq 'B'){return}
        $snap=$null
        try{switch($c){
            '1'{$snap=New-RestoreSnapshot 'Restart Print Spooler' @('Services');if($snap){Invoke-RestartSpooler}}
            '2'{Invoke-ClearPrintQueue}
            '3'{$firewallRules=@(Get-FirewallSharingRules);$snap=New-RestoreSnapshot 'Enable sharing firewall rules' @('Firewall') -FirewallRules $firewallRules;if($snap){Enable-PrivateFirewallSharing -FirewallRules $firewallRules}}
            '4'{$snap=New-RestoreSnapshot 'Change selected network profile' @('Network');if($snap){Set-OneNetworkPrivate}}
            '5'{$snap=New-RestoreSnapshot 'Start Network Discovery services' @('Services');if($snap){Start-NetworkDiscoveryServices}}
            '6'{$firewallRules=@(Get-FirewallSharingRules);$snap=New-RestoreSnapshot 'Combined non-destructive Safe Repair' @('Services','Firewall') -FirewallRules $firewallRules;if($snap){Invoke-RestartSpooler;Enable-PrivateFirewallSharing -FirewallRules $firewallRules;Start-NetworkDiscoveryServices}}
        }}catch{Write-Fail $_.Exception.Message}
        if($snap){Write-Info ((L 'Restore snapshot: {0}' 'Snapshot restore: {0}') -f $snap)}
        Pause-Tui
    }
}

function Set-RpcNamedPipeFallback {
    $d=Invoke-Diagnosis -Quiet
    $snap=New-RestoreSnapshot 'RPC Named Pipes compatibility fallback' @('Registry');if(-not $snap){return}
    Write-Warn (L 'RPC over TCP is the Windows default. Named Pipes is a compatibility fallback.' 'RPC melalui TCP adalah default Windows. Named Pipes hanya fallback kompatibilitas.')
    if($d.Role -match 'Client' -or $d.Role -eq 'Unknown / local only'){Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol' 1;Write-Ok (L 'Client outgoing printer RPC set to Named Pipes fallback.' 'RPC printer keluar pada sisi klien diatur memakai fallback Named Pipes.')}
    if($d.Role -match 'Host' -or $d.Role -eq 'Unknown / local only'){Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcProtocols' 7;Write-Ok (L 'Print host RPC listener set to allow supported protocol families.' 'Listener RPC pada host printer diatur agar menerima keluarga protokol yang didukung.')}
    Write-Info ((L 'Restore snapshot: {0}' 'Snapshot restore: {0}') -f $snap)
}

function Connect-SharedPrinterTemporarilyRelaxed {
    $unc=(Read-Host (L 'Shared printer path, e.g. \\PRINT-PC\OfficePrinter' 'Path printer sharing, contoh \\PC-PRINT\PrinterKantor')).Trim()
    if($unc -notmatch '^\\\\[^\\]+\\[^\\]+$'){Write-Warn (L 'Invalid printer UNC path.' 'Path UNC printer tidak valid.');return}
    $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint';$original=Get-RegistryValueState $path 'RestrictDriverInstallationToAdministrators'
    Write-Warn (L 'This temporarily reduces Point and Print driver-installation protection. It will be restored immediately after the connection attempt.' 'Tindakan ini menurunkan proteksi pemasangan driver Point and Print hanya sementara. Nilai sebelumnya akan langsung dikembalikan setelah percobaan koneksi.')
    if((Read-Host (L 'Type RISK to continue' 'Ketik RISK untuk lanjut')).Trim().ToUpperInvariant() -ne 'RISK'){return}
    $snap=New-RestoreSnapshot 'Temporary Point and Print relaxation' @('Registry');if(-not $snap){return}
    try{
        Set-RegistryDword $path 'RestrictDriverInstallationToAdministrators' 0
        if(Get-Command Add-Printer -ErrorAction SilentlyContinue){Add-Printer -ConnectionName $unc}else{Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /in /n "{0}"' -f $unc) -Wait}
        Write-Ok ((L 'Connection attempt completed: {0}' 'Percobaan koneksi selesai: {0}') -f $unc)
    }catch{Write-Fail $_.Exception.Message}
    finally{Restore-RegistryValue ([pscustomobject]@{Path=$path;Name='RestrictDriverInstallationToAdministrators';Present=$original.Present;Value=$original.Value;Kind=$original.Kind});Write-Ok (L 'Point and Print protection returned to its previous state.' 'Proteksi Point and Print sudah dikembalikan ke kondisi sebelumnya.')}
}

function Set-RpcPrivacyCompatibility {
    Write-Header (L 'RPC PRIVACY COMPATIBILITY' 'KOMPATIBILITAS PRIVASI RPC')
    Write-Fail (L 'This disables RPC packet-level privacy enforcement for incoming printer connections.' 'Ini menonaktifkan penerapan privasi paket RPC untuk koneksi printer yang masuk.')
    Write-Warn (L 'Use only for proven legacy incompatibility and restore it after testing.' 'Gunakan hanya jika inkompatibilitas perangkat lama sudah terbukti, lalu restore setelah pengujian.')
    if((Read-Host (L 'Type RISK to continue' 'Ketik RISK untuk lanjut')).Trim().ToUpperInvariant() -ne 'RISK'){return}
    $snap=New-RestoreSnapshot 'High-risk RPC privacy workaround' @('Registry')
    if($snap){Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' 'RpcAuthnLevelPrivacyEnabled' 0;Write-Warn (L 'RPC packet privacy is now disabled.' 'Privasi paket RPC sekarang dinonaktifkan.');Write-Info ((L 'Restore snapshot: {0}' 'Snapshot restore: {0}') -f $snap)}
}

function Show-WppHelp {
    $w=Get-WppState
    if($w.Enabled){
        Write-Warn (L 'Windows Protected Print Mode appears enabled.' 'Windows Protected Print Mode tampak aktif.')
        Write-Info (L 'Legacy third-party-driver printers may be removed or blocked.' 'Printer dengan driver pihak ketiga yang lama mungkin dihapus atau diblokir.')
        if($w.GroupPolicy.Present -and [int]$w.GroupPolicy.Value -eq 1){Write-Warn (L 'WPP appears policy-enforced. This utility will not bypass organizational policy.' 'WPP tampak dipaksakan melalui policy. Utilitas ini tidak akan melewati kebijakan organisasi.')}
        else{Write-Info (L 'Manage WPP in Settings > Bluetooth & devices > Printers & scanners > Printer preferences.' 'Kelola WPP melalui Settings > Bluetooth & devices > Printers & scanners > Printer preferences.');if(Read-YesNo (L 'Open Settings now?' 'Buka Settings sekarang?') $false){Start-Process 'ms-settings:printers'}}
    }else{Write-Ok (L 'WPP is not detected as enabled.' 'WPP tidak terdeteksi aktif.')}
}

function Reset-ClientPrinterConnectionTargeted {
    $p=@(Get-PrinterInventory|Where-Object{$_.Name -like '\\*' -or $_.Type -eq 'Connection'})
    if(-not $p.Count){Write-Warn (L 'No network printer connection detected.' 'Tidak ada koneksi printer jaringan yang terdeteksi.');return}
    for($i=0;$i -lt $p.Count;$i++){Write-Host ('[{0}] {1}' -f ($i+1),$p[$i].Name)}
    $allowed=@(1..$p.Count|ForEach-Object{[string]$_})+'B'
    $c=Read-Choice (L 'Choose one connection to remove, or B' 'Pilih satu koneksi yang akan dilepas, atau B untuk kembali') $allowed;if($c -eq 'B'){return}
    $target=$p[[int]$c-1].Name
    Write-Warn (L 'Removing a printer connection is not recreated by generic Restore. You must reconnect the same UNC path manually if needed.' 'Koneksi printer yang dilepas tidak dapat dibuat ulang oleh Restore umum. Jika diperlukan, sambungkan kembali path UNC yang sama secara manual.')
    if(-not(Read-YesNo ((L 'Remove only {0}?' 'Lepas hanya {0}?') -f $target) $true)){return}
    if(Get-Command Remove-Printer -ErrorAction SilentlyContinue){Remove-Printer -Name $target}else{Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /dn /n "{0}"' -f $target) -Wait}
    Write-Ok ((L 'Removed targeted connection: {0}' 'Koneksi yang dipilih berhasil dilepas: {0}') -f $target)
    Write-Info (L 'Reconnect the same UNC path after restarting the spooler if needed.' 'Jika perlu, sambungkan kembali path UNC yang sama setelah restart Spooler.')
    Write-Log "Targeted printer connection removed: $target" 'WARN'
}

function Show-CompatibilityMenu {
    while($true){
        Write-Header (L 'COMPATIBILITY REPAIR' 'PERBAIKAN KOMPATIBILITAS')
        Write-Warn (L 'Use these only when diagnosis points to a specific compatibility problem.' 'Gunakan bagian ini hanya jika hasil diagnosis mengarah ke masalah kompatibilitas tertentu.')
        Write-Rule
        Write-Host (L '[1] RPC Named Pipes fallback (role-aware; keeps RPC privacy)' '[1] Fallback RPC Named Pipes (sesuai peran; privasi RPC tetap aktif)')
        Write-Host (L '[2] Connect shared printer with TEMPORARY Point and Print relaxation' '[2] Sambungkan printer sharing dengan relaksasi Point and Print SEMENTARA')
        Write-Host (L '[3] Check Windows Protected Print Mode (WPP)' '[3] Periksa Windows Protected Print Mode (WPP)')
        Write-Host (L '[4] Remove one targeted network-printer connection for clean reconnect' '[4] Lepas satu koneksi printer jaringan untuk reconnect bersih')
        Write-Host (L '[5] Disable RPC packet privacy [HIGH RISK]' '[5] Nonaktifkan privasi paket RPC [RISIKO TINGGI]') -ForegroundColor Yellow
        Write-Host "[B] $(T 'Back')"
        $c=Read-Choice (T 'Select') @('1','2','3','4','5','B');if($c -eq 'B'){return}
        try{switch($c){'1'{Set-RpcNamedPipeFallback};'2'{Connect-SharedPrinterTemporarilyRelaxed};'3'{Show-WppHelp};'4'{Reset-ClientPrinterConnectionTargeted};'5'{Set-RpcPrivacyCompatibility}}}catch{Write-Fail $_.Exception.Message}
        Pause-Tui
    }
}

function Enable-Smb1ClientLegacy {
    Write-Fail (L 'SMB1 is obsolete and unsafe. Use only when a specific old device is proven SMB1-only.' 'SMB1 sudah usang dan tidak aman. Gunakan hanya jika perangkat lama tertentu benar-benar terbukti hanya mendukung SMB1.')
    if((Read-Host (L 'Type LEGACY to continue' 'Ketik LEGACY untuk lanjut')).Trim().ToUpperInvariant() -ne 'LEGACY'){return}
    $snap=New-RestoreSnapshot 'Enable SMB1 client' @('SMB1')
    if($snap -and (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue)){Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart|Out-Null;Write-Warn (L 'SMB1 CLIENT enabled. SMB1 server was not enabled.' 'KLIEN SMB1 diaktifkan. Server SMB1 tidak diaktifkan.');Write-Info ((L 'Restore snapshot: {0}' 'Snapshot restore: {0}') -f $snap)}
}

function Enable-InsecureGuestLegacy {
    Write-Fail (L 'Insecure guest SMB authentication weakens credential protection.' 'Autentikasi guest SMB yang tidak aman melemahkan proteksi kredensial.')
    if((Read-Host (L 'Type LEGACY to continue' 'Ketik LEGACY untuk lanjut')).Trim().ToUpperInvariant() -ne 'LEGACY'){return}
    $snap=New-RestoreSnapshot 'Enable insecure SMB guest' @('Registry')
    if($snap){Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth' 1;Write-Warn (L 'Insecure SMB guest authentication enabled.' 'Autentikasi guest SMB yang tidak aman diaktifkan.');Write-Info ((L 'Restore snapshot: {0}' 'Snapshot restore: {0}') -f $snap)}
}

function Set-LegacyLmCompatibility {
    Write-Fail (L 'This lowers machine-wide LAN Manager/NTLM authentication compatibility.' 'Ini menurunkan keamanan kompatibilitas autentikasi LAN Manager/NTLM untuk seluruh mesin.')
    if((Read-Host (L 'Type LEGACY to continue' 'Ketik LEGACY untuk lanjut')).Trim().ToUpperInvariant() -ne 'LEGACY'){return}
    $snap=New-RestoreSnapshot 'Legacy LAN Manager level' @('Registry')
    if($snap){Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LmCompatibilityLevel' 1;Write-Warn (L 'LmCompatibilityLevel=1 applied. Restore after testing.' 'LmCompatibilityLevel=1 diterapkan. Restore setelah pengujian.');Write-Info ((L 'Restore snapshot: {0}' 'Snapshot restore: {0}') -f $snap)}
}

function Show-LegacyMenu {
    while($true){
        Write-Header (L 'LEGACY COMPATIBILITY' 'KOMPATIBILITAS LEGACY')
        Write-Fail (L 'There is intentionally no one-click insecure Full Fix anymore.' 'Tidak ada lagi Full Fix tidak aman sekali klik; ini disengaja.')
        Write-Rule
        Write-Host (L '[1] Enable SMB1 CLIENT only' '[1] Aktifkan KLIEN SMB1 saja')
        Write-Host (L '[2] Allow insecure SMB guest authentication' '[2] Izinkan autentikasi guest SMB yang tidak aman')
        Write-Host (L '[3] Set LAN Manager compatibility level 1 [VERY HIGH RISK]' '[3] Atur kompatibilitas LAN Manager level 1 [RISIKO SANGAT TINGGI]') -ForegroundColor Yellow
        Write-Host (L '[4] Blank-password remote logon: NOT AUTOMATED (use a password instead)' '[4] Login remote tanpa password: TIDAK DIOTOMATISKAN (gunakan password)')
        Write-Host "[B] $(T 'Back')"
        $c=Read-Choice (T 'Select') @('1','2','3','4','B');if($c -eq 'B'){return}
        try{switch($c){'1'{Enable-Smb1ClientLegacy};'2'{Enable-InsecureGuestLegacy};'3'{Set-LegacyLmCompatibility};'4'{Write-Warn (L 'This utility intentionally refuses to disable LimitBlankPasswordUse. Use password-protected credentials instead.' 'Utilitas ini sengaja menolak menonaktifkan LimitBlankPasswordUse. Gunakan akun yang dilindungi password.')}}}catch{Write-Fail $_.Exception.Message}
        Pause-Tui
    }
}

function ConvertTo-DiagnosticExportObject($D,[object]$TargetPath=$null) {
    if($null -eq $D){throw 'Diagnostic object is required.'}
    $state = { param($Value) if($null -eq $Value){return [pscustomobject]@{Present=$false;Value=$null;Kind=$null}}; return [pscustomobject]@{Present=[bool]$Value.Present;Value=$Value.Value;Kind=if($Value.Kind){[string]$Value.Kind}else{$null}} }
    $profiles=@($D.Profiles|ForEach-Object{[pscustomobject]@{NetworkCategory=[string]$_.NetworkCategory;IPv4Connectivity=[string]$_.IPv4Connectivity;IPv6Connectivity=[string]$_.IPv6Connectivity}})
    $events=@($D.PrintErrors|ForEach-Object{[pscustomobject]@{TimeCreatedUtc=if($_.TimeCreated){$_.TimeCreated.ToUniversalTime().ToString('o')}else{$null};Id=[int]$_.Id;Level=[string]$_.LevelDisplayName;Category=[string]$_.Category;Win32Code=if($null -ne $_.Win32Code){[int64]$_.Win32Code}else{$null};CodeClass=if($_.CodeClass){[string]$_.CodeClass}else{$null}}})
    $findings=@($D.Findings|ForEach-Object{[pscustomobject]@{Severity=[string]$_.Severity;Text=[string]$_.Text}})
    $target=$null
    if($null -ne $TargetPath){$target=[pscustomobject]@{TestedAtUtc=[string]$TargetPath.TestedAtUtc;DnsResolved=[bool]$TargetPath.DnsResolved;Smb445Reachable=[bool]$TargetPath.Smb445Reachable;Rpc135Reachable=[bool]$TargetPath.Rpc135Reachable;ShareNamespaceAccessible=[bool]$TargetPath.ShareNamespaceAccessible;PrinterInstalled=[bool]$TargetPath.PrinterInstalled;LikelyLayer=[string]$TargetPath.LikelyLayer}}
    return [ordered]@{
        Schema='windows-printer-sharing-fix/diagnosis'
        SchemaVersion=1
        ToolVersion=$script:Version
        CollectedAtUtc=[string]$D.CollectedAtUtc
        ExportedAtUtc=(Get-Date).ToUniversalTime().ToString('o')
        Language=$script:Language
        Sanitized=$true
        Privacy='Machine/user/network identifiers, printer/share names, IP addresses, and raw event messages are omitted.'
        Windows=[ordered]@{Name=[string]$D.OS.Name;DisplayVersion=[string]$D.OS.DisplayVersion;Build=[int]$D.OS.Build;InstallationType=[string]$D.OS.InstallationType;IsServer=[bool]$D.OS.IsServer;PowerShell=[string]$D.PowerShell}
        Role=[string]$D.Role
        Spooler=[ordered]@{Present=($null -ne $D.Spooler);Status=if($D.Spooler){[string]$D.Spooler.Status}else{'Missing'}}
        PrinterSummary=[ordered]@{Total=@($D.Printers).Count;Shared=@($D.SharedPrinters).Count;NetworkConnections=@($D.Connections).Count}
        NetworkProfiles=$profiles
        WPP=[ordered]@{Enabled=[bool]$D.WPP.Enabled;GroupPolicy=(& $state $D.WPP.GroupPolicy);Mode=(& $state $D.WPP.Mode);EnabledBy=(& $state $D.WPP.EnabledBy)}
        Policies=[ordered]@{RpcPrivacy=(& $state $D.RpcPrivacy);RpcUseNamedPipe=(& $state $D.RpcUseNamedPipe);RpcProtocols=(& $state $D.RpcProtocols);PointAndPrint=(& $state $D.PointAndPrint);GuestAuth=(& $state $D.GuestAuth);LmCompatibility=(& $state $D.LmCompatibility);BlankPassword=(& $state $D.BlankPassword)}
        SMB1Client=[string]$D.SMB1Client
        PrintServiceEvents=$events
        Findings=$findings
        TimingMs=$D.TimingMs
        TargetPath=$target
    }
}

function Export-DiagnosticJson([object]$Diagnostic=$null,[string]$OutputPath='') {
    if($null -eq $Diagnostic){$Diagnostic=$script:LastDiagnostic}
    if($null -eq $Diagnostic){Write-Info (L 'No diagnosis is cached yet; running one read-only diagnosis now.' 'Belum ada diagnosis tersimpan; menjalankan satu diagnosis read-only sekarang.');$Diagnostic=Invoke-Diagnosis -Quiet}
    if(-not $script:ExportRoot){throw 'Export workspace is not initialized.'}
    if(-not(Test-Path -LiteralPath $script:ExportRoot)){New-Item -ItemType Directory -Path $script:ExportRoot -Force|Out-Null}
    if(-not $OutputPath){$OutputPath=Join-Path $script:ExportRoot ('diagnostic-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))}
    $payload=ConvertTo-DiagnosticExportObject $Diagnostic $script:LastTargetPathDiagnostic
    $payload|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Ok ((L 'Structured diagnostic JSON exported: {0}' 'JSON diagnosis terstruktur diekspor: {0}') -f $OutputPath)
    Write-Log "Diagnostic JSON exported: $OutputPath"
    return $OutputPath
}

function Export-DiagnosticText {
    $d=Invoke-Diagnosis -Quiet
    $path=Join-Path $script:LogRoot ('diagnostic-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $lines=@(
        "Windows Printer Sharing Fix v$($script:Version) - $(L 'Diagnostic Report' 'Laporan Diagnosis')",
        "$(L 'Generated' 'Dibuat'): $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "OS: $($d.OS.Name) $($d.OS.DisplayVersion) build $($d.OS.Build)",
        "$(L 'Role' 'Peran'): $(Localize-SystemValue $d.Role)",
        "Spooler: $(if($d.Spooler){Localize-SystemValue ([string]$d.Spooler.Status)}else{Localize-SystemValue 'Missing'})",
        "WPP: $($d.WPP.Enabled)",
        "$(L 'SMB1 client' 'Klien SMB1'): $(Localize-SystemValue ([string]$d.SMB1Client))",'',(L 'Findings:' 'Temuan:')
    )
    foreach($f in $d.Findings){$lines+="[$($f.Severity)] $($f.Text)"}
    $lines+='';$lines+=(L 'Printers:' 'Printer:')
    foreach($p in $d.Printers){$lines+="- $($p.Name) | driver=$($p.DriverName) | share=$($p.ShareName)"}
    $lines|Set-Content -LiteralPath $path -Encoding UTF8
    Write-Ok ((L 'Diagnostic report exported: {0}' 'Laporan diagnosis diekspor: {0}') -f $path)
}

function Show-ToolsMenu {
    while($true){
        Write-Header (L 'TOOLS AND LOGS' 'ALAT DAN LOG')
        Write-Host (L '[1] Printers & scanners Settings' '[1] Settings Printers & scanners')
        Write-Host (L '[2] Print Management' '[2] Print Management')
        Write-Host (L '[3] Services' '[3] Services')
        Write-Host (L '[4] Network Connections' '[4] Koneksi Jaringan')
        Write-Host (L '[5] Open current log' '[5] Buka log saat ini')
        Write-Host (L '[6] Open backup folder' '[6] Buka folder backup')
        Write-Host (L '[7] Export fresh diagnostic report (.txt)' '[7] Ekspor laporan diagnosis baru (.txt)')
        Write-Host (L '[8] Export latest diagnosis as sanitized JSON' '[8] Ekspor diagnosis terakhir sebagai JSON sanitized')
        Write-Host (L '[9] Test a shared printer path' '[9] Tes path printer sharing')
        Write-Host "[B] $(T 'Back')"
        $c=Read-Choice (T 'Select') @('1','2','3','4','5','6','7','8','9','B');if($c -eq 'B'){return}
        switch($c){'1'{Start-Process 'ms-settings:printers' -ErrorAction SilentlyContinue};'2'{Start-Process 'printmanagement.msc' -ErrorAction SilentlyContinue};'3'{Start-Process 'services.msc'};'4'{Start-Process 'ncpa.cpl'};'5'{Start-Process notepad.exe -ArgumentList ('"{0}"' -f $script:CurrentLog)};'6'{Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:BackupRoot)};'7'{Export-DiagnosticText;Pause-Tui};'8'{[void](Export-DiagnosticJson);Pause-Tui};'9'{Invoke-SharedPrinterPathDiagnosis;Pause-Tui}}
    }
}

function Show-GuideMenu {
    Write-Header (T 'Guide')
    Write-Info (L 'Recommended flow: diagnose first, apply the smallest relevant repair, then verify printing.' 'Alur yang disarankan: diagnosis dulu, terapkan perbaikan sekecil mungkin, lalu verifikasi printer.')
    Write-Rule
    Write-Host (L '1. DIAGNOSE FIRST' '1. DIAGNOSIS DULU') -ForegroundColor Green
    Write-Host (L '   Read the detected role, Spooler state, network profile, WPP, SMB1, policies, and PrintService events.' '   Baca peran PC, kondisi Spooler, profil jaringan, WPP, SMB1, policy, dan event PrintService.')
    Write-Host ''
    Write-Host (L '2. SAFE REPAIR FOR COMMON PROBLEMS' '2. PERBAIKAN AMAN UNTUK MASALAH UMUM') -ForegroundColor Cyan
    Write-Host (L '   Use it for Spooler, stuck queues, sharing firewall rules, one network profile, or Network Discovery.' '   Gunakan untuk Spooler, antrean macet, firewall sharing, satu profil jaringan, atau Network Discovery.')
    Write-Host ''
    Write-Host (L '3. COMPATIBILITY ONLY WITH EVIDENCE' '3. KOMPATIBILITAS HANYA JIKA ADA BUKTI') -ForegroundColor Yellow
    Write-Host (L '   Named Pipes, temporary Point and Print relaxation, WPP checks, and RPC privacy are not first-line fixes.' '   Named Pipes, relaksasi Point and Print sementara, pemeriksaan WPP, dan privasi RPC bukan perbaikan pertama.')
    Write-Host ''
    Write-Host (L '4. LEGACY IS THE LAST RESORT' '4. LEGACY ADALAH PILIHAN TERAKHIR') -ForegroundColor Yellow
    Write-Host (L '   SMB1, insecure guest authentication, and LAN Manager level 1 reduce Windows security.' '   SMB1, autentikasi guest tidak aman, dan LAN Manager level 1 menurunkan keamanan Windows.')
    Write-Host ''
    Write-Host (L '5. VERIFY, THEN RESTORE IF IT DID NOT HELP' '5. VERIFIKASI, LALU RESTORE JIKA TIDAK MEMBANTU') -ForegroundColor Green
    Write-Host (L '   Print a real test page. Avoid stacking more tweaks when the previous change did not solve the problem.' '   Cetak test page nyata. Hindari menumpuk tweak jika perubahan sebelumnya tidak menyelesaikan masalah.')
    Write-Rule
    Write-Info (L 'Tip: Tools and Logs can test a \\HOST\Printer path without changing Windows settings.' 'Tip: Alat dan Log dapat mengetes path \\HOST\Printer tanpa mengubah pengaturan Windows.')
    Pause-Tui
}

function Show-LanguageMenu {
    Write-Header (T 'Language')
    Write-Host '[1] English (default)'
    Write-Host '[2] Bahasa Indonesia'
    Write-Host "[B] $(T 'Back')"
    $c=Read-Choice (T 'Select') @('1','2','B');if($c -eq 'B'){return}
    $script:Language=if($c -eq '2'){'ID'}else{'EN'}
    $script:Language|Set-Content -LiteralPath $script:LanguageFile -Encoding ASCII
}

function Write-MainMenuItem([string]$Number,[string]$Label,[ConsoleColor]$Color='Gray',[string]$Note='') {
    $text='[{0}] {1}' -f $Number,$Label
    if($Note){$text+='  <{0}>' -f $Note}
    Write-Host $text -ForegroundColor $Color
}

function Show-MainMenu {
    while($true){
        Write-Header (T 'Main')
        $os=Get-OsInfo
        $spool=Get-Service Spooler -ErrorAction SilentlyContinue
        $languageName=if($script:Language -eq 'ID'){'Indonesia'}else{'English'}
        $spoolState=if($spool){Localize-SystemValue ([string]$spool.Status)}else{Localize-SystemValue 'Missing'}
        Write-Host ((L '  OS: {0} build {1}    Language: {2}    Spooler: {3}' '  OS: {0} build {1}    Bahasa: {2}    Spooler: {3}') -f $os.Name,$os.Build,$languageName,$spoolState) -ForegroundColor DarkGray
        Write-Rule
        Write-Info (L 'Start with diagnosis. Repairs do nothing until you choose them.' 'Mulai dari diagnosis. Perbaikan tidak berjalan sampai kamu memilihnya.')
        Write-Rule
        Write-MainMenuItem '1' (T 'Diagnose') Green (T 'Recommended')
        Write-MainMenuItem '2' (T 'Safe') Cyan
        Write-MainMenuItem '3' (T 'Compat') Gray
        Write-MainMenuItem '4' (T 'Legacy') Yellow
        Write-Rule
        Write-MainMenuItem '5' (T 'Restore') Gray
        Write-MainMenuItem '6' (T 'Tools') Gray
        Write-MainMenuItem '7' (T 'Guide') Cyan
        Write-MainMenuItem '8' (T 'Language') Gray
        Write-MainMenuItem '9' (T 'Exit') DarkGray
        Write-Rule
        $c=Read-Choice (T 'Select') @('1','2','3','4','5','6','7','8','9')
        switch($c){'1'{[void](Invoke-Diagnosis)};'2'{Show-SafeRepairMenu};'3'{Show-CompatibilityMenu};'4'{Show-LegacyMenu};'5'{Invoke-RestoreLatest};'6'{Show-ToolsMenu};'7'{Show-GuideMenu};'8'{Show-LanguageMenu};'9'{return}}
    }
}
try {
    Initialize-Workspace
    if(-not(Ensure-Administrator)){if(-not(Test-IsAdministrator)){exit 0}}
    Show-MainMenu
} catch {
    Write-Host ((L 'Fatal error: {0}' 'Error fatal: {0}') -f $_.Exception.Message) -ForegroundColor Red
    Write-Log $_.Exception.ToString() 'FATAL'
    Pause-Tui
    exit 1
}
