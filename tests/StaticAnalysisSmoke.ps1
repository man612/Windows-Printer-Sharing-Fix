$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$expectedVersion = [version]'1.25.0'
$module = Get-Module -ListAvailable PSScriptAnalyzer | Where-Object {$_.Version -eq $expectedVersion} | Select-Object -First 1
if($null -eq $module){throw "PSScriptAnalyzer $expectedVersion is required for static-analysis smoke."}
Import-Module $module.Path -Force
if((Get-Module PSScriptAnalyzer).Version -ne $expectedVersion){throw 'Unexpected PSScriptAnalyzer version loaded.'}

$settingsPath = Join-Path $repo 'PSScriptAnalyzerSettings.psd1'
if(-not(Test-Path -LiteralPath $settingsPath)){throw 'PSScriptAnalyzerSettings.psd1 is missing.'}
$baseSettings = Import-PowerShellDataFile -LiteralPath $settingsPath
$expectedExclusions = @(
    'PSAvoidUsingWriteHost',
    'PSUseShouldProcessForStateChangingFunctions',
    'PSUseSingularNouns',
    'PSUseApprovedVerbs'
)
foreach($rule in $expectedExclusions){
    if($rule -notin @($baseSettings.ExcludeRules)){throw "Static-analysis profile is missing documented exclusion: $rule"}
}
$productionResults = @()
$productionResults += @(Invoke-ScriptAnalyzer -Path (Join-Path $repo 'FixPrinter.ps1') -Settings $settingsPath)
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $repo 'tools') -Filter '*.ps1' -File)){
    $productionResults += @(Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath)
}

$testSettings = @{
    Severity = @($baseSettings.Severity)
    ExcludeRules = @($baseSettings.ExcludeRules) + @('PSAvoidOverwritingBuiltInCmdlets')
}
$testResults = @()
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $repo 'tests') -Filter '*.ps1' -File)){
    $testResults += @(Invoke-ScriptAnalyzer -Path $file.FullName -Settings $testSettings)
}

$violations = @($productionResults + $testResults)
if($violations.Count){
    $details = $violations | Sort-Object ScriptName,Line,RuleName | ForEach-Object {
        '{0}:{1} [{2}] {3}' -f $_.ScriptName,$_.Line,$_.RuleName,$_.Message
    }
    throw ("PSScriptAnalyzer reported {0} actionable diagnostic(s):`n{1}" -f $violations.Count,($details -join "`n"))
}

Write-Host ('Static-analysis smoke passed with PSScriptAnalyzer {0}: production and tests have no actionable Error/Warning diagnostics.' -f $expectedVersion) -ForegroundColor Green
