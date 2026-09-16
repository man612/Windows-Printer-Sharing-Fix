$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$examples = Join-Path $repo 'docs\examples'
$expected = @(
    'README.md',
    'healthy-windows11.md',
    'dns-name-resolution-failure.md',
    'smb-445-unreachable.md',
    'wpp-legacy-driver-warning.md',
    'legacy-security-warning.md'
)

foreach($name in $expected){
    $path = Join-Path $examples $name
    if(-not(Test-Path -LiteralPath $path)){throw "Example documentation is missing: $name"}
}

$scenarioFiles = $expected | Where-Object { $_ -ne 'README.md' }
foreach($name in $scenarioFiles){
    $path = Join-Path $examples $name
    $text = Get-Content -LiteralPath $path -Raw
    if($text -notmatch '(?i)Synthetic sanitized example'){throw "$name must be explicitly marked synthetic."}
    if($text -notmatch '## Earliest useful signal'){throw "$name is missing its earliest-useful-signal explanation."}
    if($text -notmatch '## What this does not prove'){throw "$name is missing its interpretation boundary."}
    $match = [regex]::Match($text,'(?s)```json\s*(.*?)\s*```')
    if(-not $match.Success){throw "$name is missing a JSON example block."}
    try{$null = $match.Groups[1].Value | ConvertFrom-Json}catch{throw "$name contains invalid JSON: $($_.Exception.Message)"}

    foreach($pattern in @(
        '\\\\[A-Za-z0-9._-]+\\[A-Za-z0-9$._ -]+',
        '(?i)C:\\Users\\[^\\\s]+',
        '(?<!\d)10\.\d{1,3}\.\d{1,3}\.\d{1,3}(?!\d)',
        '(?<!\d)192\.168\.\d{1,3}\.\d{1,3}(?!\d)',
        '(?<!\d)172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}(?!\d)',
        '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
    )){
        if($text -match $pattern){throw "$name contains a privacy-sensitive example pattern: $($Matches[0])"}
    }
}

$index = Get-Content -LiteralPath (Join-Path $examples 'README.md') -Raw
foreach($name in $scenarioFiles){if($index -notmatch [regex]::Escape($name)){throw "Examples index does not link $name"}}
if($index -notmatch 'direct-hosting-of-smb-over-tcpip'){throw 'Examples index is missing the Microsoft SMB reference.'}
if($index -notmatch 'windows-protected-print-mode'){throw 'Examples index is missing the Microsoft WPP reference.'}

Write-Host ('Examples smoke passed: {0} synthetic sanitized scenarios are present, valid JSON, indexed, and privacy-guarded.' -f $scenarioFiles.Count) -ForegroundColor Green
