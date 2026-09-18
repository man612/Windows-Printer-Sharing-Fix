$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$required = @(
    'LICENSE','SECURITY.md','CONTRIBUTING.md','CODE_OF_CONDUCT.md','README.md','CHANGELOG.md','ROADMAP.md',
    '.editorconfig','.gitattributes','.gitignore','PSScriptAnalyzerSettings.psd1',
    '.github\dependabot.yml','.github\ISSUE_TEMPLATE\bug_report.yml','.github\ISSUE_TEMPLATE\compatibility.yml',
    '.github\ISSUE_TEMPLATE\feature_request.yml','.github\ISSUE_TEMPLATE\config.yml'
)
foreach($relative in $required){
    if(-not(Test-Path -LiteralPath (Join-Path $repo $relative))){throw "Required repository/governance file is missing: $relative"}
}

$dependabot = Get-Content -LiteralPath (Join-Path $repo '.github\dependabot.yml') -Raw
foreach($pattern in @(
    'version:\s*2',
    'package-ecosystem:\s*["'']?github-actions["'']?',
    'directory:\s*["'']?/["'']?',
    'interval:\s*["'']?weekly["'']?'
)){
    if($dependabot -notmatch $pattern){throw "Dependabot GitHub Actions configuration is missing expected pattern: $pattern"}
}
$workflowFiles = @(Get-ChildItem -LiteralPath (Join-Path $repo '.github\workflows') -Filter '*.yml' -File)
if(-not $workflowFiles.Count){throw 'No GitHub Actions workflows were found.'}
foreach($workflow in $workflowFiles){
    $text = Get-Content -LiteralPath $workflow.FullName -Raw
    if($text -notmatch '(?m)^permissions:\s*$'){throw "Workflow must declare explicit permissions: $($workflow.Name)"}
    foreach($line in @(Get-Content -LiteralPath $workflow.FullName)){
        $refMatch = [regex]::Match($line,'^\s*uses:\s*([^\s#]+)')
        if(-not $refMatch.Success){continue}
        $reference = $refMatch.Groups[1].Value
        if($reference.StartsWith('./')){continue}
        if($reference -notmatch '@[0-9a-fA-F]{40}$'){throw "GitHub Action reference is not pinned to a full commit SHA in $($workflow.Name): $reference"}
    }
}

Push-Location $repo
try {
    $tracked = @(git ls-files)
    if($LASTEXITCODE -ne 0){throw 'git ls-files failed during repository hygiene validation.'}
} finally { Pop-Location }

$forbidden = @(
    '^dist/','^backups/','^logs/','^\.runtime/','(^|/)language\.cfg$','\.log$','\.zip$','(^|/)SHA256SUMS\.txt$',
    '(^|/)(patch|fix|tmp)[-_].*\.py$'
)
foreach($entry in $tracked){
    foreach($pattern in $forbidden){
        if($entry -match $pattern){throw "Tracked development/runtime artifact violates repository hygiene: $entry"}
    }
}

if($tracked -notcontains '.github/workflows/validate.yml' -or $tracked -notcontains '.github/workflows/release.yml'){
    throw 'Expected validation/release workflows are not tracked.'
}

Write-Host 'Repository hygiene smoke passed: governance files, Dependabot, workflow permissions/SHA pinning, and tracked-artifact guards are stable.' -ForegroundColor Green
