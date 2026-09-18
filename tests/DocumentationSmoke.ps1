$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$markdown = @()
$markdown += @(Get-ChildItem -LiteralPath $repo -Filter '*.md' -File)
$markdown += @(Get-ChildItem -LiteralPath (Join-Path $repo 'docs') -Filter '*.md' -File -Recurse)
if(-not $markdown.Count){throw 'No Markdown documentation files were found.'}

$missing = New-Object System.Collections.Generic.List[string]
$linkPattern = [regex]'!?(?:\[[^\]]*\])\(([^)]+)\)'
foreach($file in $markdown){
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach($linkMatch in $linkPattern.Matches($text)){
        $destination = $linkMatch.Groups[1].Value.Trim()
        if(-not $destination){continue}
        if($destination.StartsWith('<') -and $destination.EndsWith('>')){$destination=$destination.Substring(1,$destination.Length-2)}
        if($destination -match '^[A-Za-z][A-Za-z0-9+.-]*:'){continue}
        if($destination.StartsWith('#')){continue}

        $pathPart = ($destination -split '#',2)[0]
        if(-not $pathPart){continue}
        if($pathPart -match '\s+["'']'){ $pathPart = ($pathPart -split '\s+',2)[0] }
        $pathPart = [Uri]::UnescapeDataString($pathPart)
        $candidate = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName ($pathPart -replace '/','\')))
        if(-not(Test-Path -LiteralPath $candidate)){
            $relative = $file.FullName.Substring($repo.Length).TrimStart('\')
            $missing.Add(('{0} -> {1}' -f $relative,$destination))
        }
    }
}
if($missing.Count){
    throw ("Broken relative Markdown link(s):`n{0}" -f ($missing -join "`n"))
}

$readme = Get-Content -LiteralPath (Join-Path $repo 'README.md') -Raw
foreach($requiredDoc in @(
    'docs/ARCHITECTURE.md','docs/DIAGNOSTIC-JSON.md','docs/WPP-READINESS.md',
    'docs/RELEASE-INTEGRITY.md','docs/TEST-MATRIX.md','docs/REAL-WORLD-RESULTS.md'
)){
    if($readme -notmatch [regex]::Escape($requiredDoc)){throw "README documentation index is missing: $requiredDoc"}
}

Write-Host ('Documentation smoke passed: {0} Markdown file(s) have valid relative links and core docs stay indexed.' -f $markdown.Count) -ForegroundColor Green
