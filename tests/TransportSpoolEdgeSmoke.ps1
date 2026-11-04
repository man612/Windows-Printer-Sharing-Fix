$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$root=Split-Path -Parent $PSScriptRoot
$scriptFile=Join-Path $root 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Main script parse failed.'}
$functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join ([Environment]::NewLine+[Environment]::NewLine)))
function Write-Log([string]$Message,[string]$Level='INFO'){}
$script:Language='EN'
$d=[pscustomobject]@{Spooler=[pscustomobject]@{Status='Running'};WPP=[pscustomobject]@{Enabled=$false};Profiles=@();Printers=@();PrintErrors=@()}
$t=[pscustomobject]@{DnsResolved=$true;Smb445Reachable=$true;Rpc135Reachable=$false;RpcTransport='NamedPipes';ShareNamespaceAccessible=$true;PrinterInstalled=$false;MatchedPrintEventCategories=@()}
if((Get-NextInvestigation $d $t).Layer -eq 'RpcReachability'){throw 'Named Pipes incorrectly requires TCP 135.'}
$t.RpcTransport='Tcp'
if((Get-NextInvestigation $d $t).Layer -ne 'RpcReachability'){throw 'TCP failure was ignored.'}
$t.Rpc135Reachable=$true
$t|Add-Member NoteProperty RpcConfiguredPort 55000
$t|Add-Member NoteProperty RpcConfiguredPortReachable $false
$t|Add-Member NoteProperty RpcConfiguredPortSource 'LocalOnly'
if((Get-NextInvestigation $d $t).Layer -eq 'RpcReachability'){throw 'Local print-RPC port mistaken for remote host port.'}
$t.RpcConfiguredPortSource='ConfirmedRemote'
if((Get-NextInvestigation $d $t).Reason -ne 'TargetConfiguredRpcPortFailed'){throw 'Confirmed remote port failure ignored.'}
if(-not(Test-SafePrinterUncPath '\\HOST\Office Printer')){throw 'Valid UNC rejected.'}
foreach($bad in @('\\HOST\Bad" /x','\\HOST','\\HOST\foo\bar')){if(Test-SafePrinterUncPath $bad){throw 'Unsafe UNC accepted.'}}
$fixture=[pscustomobject]@{PrintErrors=@([pscustomobject]@{Category='DriverOrPackage'})}
$t.MatchedPrintEventCategories=@()
if(Test-NextInvestigationEventCategory $fixture 'DriverOrPackage' $t){throw 'Unrelated printer event was correlated.'}
$t.MatchedPrintEventCategories=@('DriverOrPackage')
if(-not(Test-NextInvestigationEventCategory $fixture 'DriverOrPackage' $t)){throw 'Matched printer event ignored.'}
$temp=Join-Path $env:TEMP ('wpsf-spool-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force|Out-Null
try{
    function Get-RegistryValueStateStrict([string]$Path,[string]$Name){[pscustomobject]@{Present=$true;Value=$temp;Kind='String'}}
    if((Get-EffectiveSpoolDirectory) -ne $temp){throw 'Customized spool path ignored.'}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
$listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
$listener.Start()
try{
    $port=([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $addresses=@([System.Net.IPAddress]::Parse('192.0.2.1'),[System.Net.IPAddress]::Loopback)
    if(-not(Test-TcpPort 'example.invalid' $port 350 $addresses)){throw 'Reachable fallback address masked by first failure.'}
}finally{$listener.Stop()}
Write-Host 'Transport/spool edge smoke passed.' -ForegroundColor Green
