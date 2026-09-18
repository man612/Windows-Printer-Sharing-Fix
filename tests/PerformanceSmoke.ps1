$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'FixPrinter.ps1 must parse before performance smoke testing.' }

$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"))

function Get-FunctionText([string]$Name) {
    $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
    if (-not $node) { throw "Expected function missing: $Name" }
    return $node.Extent.Text
}

$tcpSource = Get-FunctionText 'Test-TcpPort'
if ($tcpSource -match 'Test-NetConnection') { throw 'TCP probe regressed to Test-NetConnection with an uncontrolled timeout.' }
if ($tcpSource -notmatch 'TimeoutMs' -or $tcpSource -notmatch 'WaitOne') { throw 'TCP probe has no explicit bounded timeout.' }

$dnsSource = Get-FunctionText 'Resolve-HostAddresses'
if ($dnsSource -notmatch 'TimeoutMs' -or $dnsSource -notmatch 'BeginGetHostAddresses') { throw 'DNS resolution is not explicitly timeout-bounded.' }

$firewallSource = Get-FunctionText 'Get-FirewallSharingRules'
if ($firewallSource -notmatch "-Group '@FirewallAPI\.dll,-28502'") { throw 'Firewall discovery is not using the targeted Windows sharing-rule group.' }
$script:Version = '4.2.0-smoke'
$script:Language = 'EN'
$script:Text = @{ EN=@{}; ID=@{} }
$script:CurrentLog = Join-Path $env:TEMP ('wpsf-performance-smoke-' + [Guid]::NewGuid().ToString('N') + '.log')
$script:LastDiagnostic = $null

$dnsWatch = [System.Diagnostics.Stopwatch]::StartNew()
$missing = @(Resolve-HostAddresses 'host-that-must-not-exist.invalid' 300)
$dnsWatch.Stop()
if ($missing.Count) { throw 'Reserved .invalid hostname unexpectedly resolved.' }
if ($dnsWatch.ElapsedMilliseconds -gt 1500) { throw "DNS timeout exceeded regression budget: $($dnsWatch.ElapsedMilliseconds) ms" }

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
$listener.Start()
try {
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    if (-not (Test-TcpPort '127.0.0.1' $port 500)) { throw 'Bounded TCP probe failed against a local listening socket.' }
}
finally {
    $listener.Stop()
}

$tcpWatch = [System.Diagnostics.Stopwatch]::StartNew()
[void](Test-TcpPort '192.0.2.1' 65000 300)
$tcpWatch.Stop()
if ($tcpWatch.ElapsedMilliseconds -gt 1500) { throw "TCP timeout exceeded regression budget: $($tcpWatch.ElapsedMilliseconds) ms" }
$firewallMs = $null
if (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue) {
    $measure = Measure-Command { [void](Get-FirewallSharingRules) }
    $firewallMs = [math]::Round($measure.TotalMilliseconds)
    if ($measure.TotalSeconds -gt 8) { throw "Targeted firewall query exceeded regression budget: $firewallMs ms" }
}

$temp = Join-Path $env:TEMP ('wpsf-performance-snapshot-' + [Guid]::NewGuid().ToString('N'))
$script:BackupRoot = Join-Path $temp 'backups'
$script:LatestStateFile = Join-Path $script:BackupRoot 'latest_backup.txt'
New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
$script:FirewallQueryCount = 0
$script:FirewallSetCount = 0
function Get-FirewallSharingRules { $script:FirewallQueryCount++; return @() }
function Set-NetFirewallRule { $script:FirewallSetCount++ }

$fakeRules = @([pscustomobject]@{
    Name='WPSF-Performance-Smoke'; DisplayName='Smoke'; DisplayGroup='File and Printer Sharing';
    Enabled='False'; Profile='Private'; Direction='Inbound'; Action='Allow'
})
$snapshot = New-RestoreSnapshot 'Enable sharing firewall rules' @('Firewall') -FirewallRules $fakeRules
if (-not $snapshot) { throw 'Preloaded firewall snapshot failed.' }
if ($script:FirewallQueryCount -ne 0) { throw 'Snapshot re-queried firewall despite receiving preloaded rules.' }
Enable-PrivateFirewallSharing -FirewallRules $fakeRules
if ($script:FirewallQueryCount -ne 0) { throw 'Safe firewall repair re-queried firewall despite receiving preloaded rules.' }
if ($script:FirewallSetCount -ne 1) { throw "Expected one stubbed firewall update, got $($script:FirewallSetCount)." }

$emptySnapshot = New-RestoreSnapshot 'Enable sharing firewall rules' @('Firewall') -FirewallRules @()
if (-not $emptySnapshot) { throw 'Empty preloaded firewall snapshot failed.' }
Enable-PrivateFirewallSharing -FirewallRules @()
if ($script:FirewallQueryCount -ne 0) { throw 'Empty preloaded firewall inventory triggered an unexpected re-query.' }
if ($script:FirewallSetCount -ne 1) { throw 'Empty preloaded firewall inventory attempted an update.' }

Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $script:CurrentLog -Force -ErrorAction SilentlyContinue

$firewallText = if ($null -eq $firewallMs) { 'unavailable' } else { "$firewallMs ms" }
Write-Host ('Performance smoke passed. DNS miss: {0} ms; bounded TCP miss: {1} ms; firewall query: {2}.' -f $dnsWatch.ElapsedMilliseconds,$tcpWatch.ElapsedMilliseconds,$firewallText) -ForegroundColor Green
Write-Host 'Firewall snapshot/repair reused the same rule inventory without a second query.' -ForegroundColor Green
