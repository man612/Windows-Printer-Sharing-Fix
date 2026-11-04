#requires -version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Host','Client')][string]$Role,
    [string]$ShareName = '',
    [string]$PrinterPath = '',
    [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'WindowsPrinterSharingFix-Evidence')
)
$ErrorActionPreference='Stop'
if($Role -eq 'Host'){
    if([string]::IsNullOrWhiteSpace($ShareName) -or $ShareName -notmatch '^[^\\/:"<>|?*]+$'){throw 'Host mode requires a valid -ShareName.'}
}elseif($PrinterPath -notmatch '^\\\\([^\\/:"<>|?*]+)\\([^\\/:"<>|?*]+)$'){
    throw 'Client mode requires -PrinterPath in the form \\HOST\PrinterShare.'
}
function Get-A1OperatingSystem {
    try{
        $os=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $build=[int]$os.CurrentBuild
        $revision=$null
        if($null -ne $os.PSObject.Properties['UBR']){$revision=[int]$os.UBR}
        $name=if([string]$os.InstallationType -match 'Server'){'Windows Server'}elseif($build -ge 22000){'Windows 11'}elseif($build -ge 10240){'Windows 10'}else{'Other'}
        $full=if($null -ne $revision){"$build.$revision"}else{[string]$build}
        return [pscustomobject]@{Family=$name;FullBuild=$full;DisplayVersion=[string]$os.DisplayVersion}
    }catch{return [pscustomobject]@{Family='Unknown';FullBuild='Unknown';DisplayVersion='Unknown'}}
}
function Get-A1PrinterInventory {
    if(Get-Command Get-Printer -ErrorAction SilentlyContinue){
        try{return [pscustomobject]@{Available=$true;Printers=@(Get-Printer -ErrorAction Stop)}}catch{Write-Verbose 'PrintManagement inventory unavailable; trying CIM fallback.'}
    }
    try{return [pscustomobject]@{Available=$true;Printers=@(Get-CimInstance Win32_Printer -ErrorAction Stop)}}catch{
        return [pscustomobject]@{Available=$false;Printers=@()}
    }
}
function Get-A1SpoolerStatus {
    try{return [string](Get-Service -Name Spooler -ErrorAction Stop).Status}catch{return 'Unknown'}
}
function Get-A1NetworkSummary {
    try{
        $profiles=@(Get-NetConnectionProfile -ErrorAction Stop)
        return [pscustomobject]@{
            Available=$true
            ActivePublicCount=@($profiles|Where-Object{
                $_.NetworkCategory -eq 'Public' -and
                ($_.IPv4Connectivity -ne 'Disconnected' -or $_.IPv6Connectivity -ne 'Disconnected')
            }).Count
            ActivePrivateOrDomainCount=@($profiles|Where-Object{
                $_.NetworkCategory -in @('Private','DomainAuthenticated') -and
                ($_.IPv4Connectivity -ne 'Disconnected' -or $_.IPv6Connectivity -ne 'Disconnected')
            }).Count
        }
    }catch{return [pscustomobject]@{Available=$false;ActivePublicCount=$null;ActivePrivateOrDomainCount=$null}}
}
function Get-A1WppRegistrySignal {
    $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP'
    try{
        $key=Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
        if($null -eq $key){return 'NotDetectedByRegistry'}
        foreach($name in @('WindowsProtectedPrintGroupPolicyState','WindowsProtectedPrintMode')){
            $value=$key.GetValue($name,$null)
            if($null -ne $value -and [string]$value -eq '1'){return 'DetectedByRegistry'}
        }
        return 'NotDetectedByRegistry'
    }catch{return 'Unknown'}
}
function Resolve-A1TargetAddresses([string]$Name,[int]$TimeoutMs=2000) {
    $request=$null
    try{
        $request=[Net.Dns]::BeginGetHostAddresses($Name,$null,$null)
        if(-not $request.AsyncWaitHandle.WaitOne($TimeoutMs,$false)){return @()}
        return @([Net.Dns]::EndGetHostAddresses($request))
    }catch{return @()}
    finally{if($request -and $request.AsyncWaitHandle){$request.AsyncWaitHandle.Close()}}
}
function Test-A1TcpPort([Net.IPAddress[]]$Addresses,[int]$Port,[int]$TimeoutMs=800) {
    $clock=[Diagnostics.Stopwatch]::StartNew()
    foreach($address in @($Addresses|Select-Object -First 8)){
        $remaining=4000-[int]$clock.ElapsedMilliseconds
        if($remaining -le 0){break}
        $client=New-Object System.Net.Sockets.TcpClient($address.AddressFamily)
        $request=$null
        try{
            $request=$client.BeginConnect($address,$Port,$null,$null)
            if($request.AsyncWaitHandle.WaitOne([Math]::Min($TimeoutMs,$remaining),$false)){
                $client.EndConnect($request)
                if($client.Connected){return $true}
            }
        }catch{Write-Verbose 'TCP preflight attempt did not complete successfully.'}
        finally{
            if($request -and $request.AsyncWaitHandle){$request.AsyncWaitHandle.Close()}
            $client.Close()
        }
    }
    return $false
}
$inventory=Get-A1PrinterInventory
if($Role -eq 'Host'){
    $found=$null
    $driverClass='Unknown'
    if($inventory.Available){
        $candidate=@($inventory.Printers|Where-Object{
            [bool]$_.Shared -and [string]::Equals([string]$_.ShareName,$ShareName,[StringComparison]::OrdinalIgnoreCase)
        })|Select-Object -First 1
        $found=($null -ne $candidate)
        if($found){
            if([string]$candidate.DriverName -eq 'Microsoft IPP Class Driver'){$driverClass='MicrosoftIppClassDriver'}
            elseif($candidate.DriverName){$driverClass='OtherOrUnverified'}
        }
    }
    $roleChecks=[pscustomobject]@{ExpectedShareFound=$found;DriverFamilyIndicator=$driverClass;ShareAccessFromClient='NotTestedFromHost'}
}else{
    $uncMatch=[regex]::Match($PrinterPath,'^\\\\([^\\/:"<>|?*]+)\\([^\\/:"<>|?*]+)$')
    $computer=$uncMatch.Groups[1].Value
    $addresses=@(Resolve-A1TargetAddresses $computer)
    $resolved=($addresses.Count -gt 0)
    $installed=$null
    if($inventory.Available){
        $installed=(@($inventory.Printers|Where-Object{
            [string]::Equals([string]$_.Name,$PrinterPath,[StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0)
    }
    $roleChecks=[pscustomobject]@{
        TargetResolved=$resolved
        Tcp445Reachable=if($resolved){Test-A1TcpPort $addresses 445}else{$null}
        Rpc135Reachable=if($resolved){Test-A1TcpPort $addresses 135}else{$null}
        ExactUncConnectionInInventory=$installed
        DriverInstallation='NotVerified'
        PrintServerCredentials='NotVerified'
    }
}
$report=[ordered]@{
    SchemaVersion=1;MatrixId='A1';Role=$Role
    CollectedAtUtc=(Get-Date).ToUniversalTime().ToString('o')
    MachineIdentifiers='Omitted'
    Privacy='Hostname, IP, share name, printer name, driver name and credentials never exported.'
    OS=Get-A1OperatingSystem
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    SpoolerStatus=Get-A1SpoolerStatus
    Network=Get-A1NetworkSummary
    WppRegistrySignal=Get-A1WppRegistrySignal
    PrinterInventoryAvailable=[bool]$inventory.Available
    Checks=$roleChecks
    RealTestPageObserved='NotRecorded'
    FunctionalResult='Unverified'
    CompatibilityMatrixStatus='Pending'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$name=('wpsf-a1-{0}-{1}-{2}.json' -f $Role.ToLowerInvariant(),$stamp,[guid]::NewGuid().ToString('N').Substring(0,6))
$path=Join-Path $OutputDirectory $name
$report|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop
Write-Host ('A1 read-only preflight saved: {0}' -f $name)
Write-Host 'No printer/security changes made. A real test page is still required.'
