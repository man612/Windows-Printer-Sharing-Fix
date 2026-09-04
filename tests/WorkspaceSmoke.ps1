$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'FixPrinter.ps1 must parse before workspace smoke.' }
$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
. ([scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join "`r`n`r`n"))

$base = Join-Path $env:TEMP ('wpsf-workspace-' + [Guid]::NewGuid().ToString('N'))
$legacyRoot = Join-Path $base 'legacy'
$dataRoot = Join-Path $base 'data'
$legacyBackups = Join-Path $legacyRoot 'backups'
$snapshotName = '20260904-120000-abcdef'
$snapshotDir = Join-Path $legacyBackups $snapshotName
New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
'{}' | Set-Content -LiteralPath (Join-Path $snapshotDir 'managed-state.json') -Encoding UTF8
$snapshotDir | Set-Content -LiteralPath (Join-Path $legacyBackups 'latest_backup.txt') -Encoding UTF8
'ID' | Set-Content -LiteralPath (Join-Path $legacyRoot 'language.cfg') -Encoding ASCII
$script:Version = '4.0.2-smoke'
$script:Root = $legacyRoot
$script:LegacyBackupRoot = $legacyBackups
$script:LegacyLanguageFile = Join-Path $legacyRoot 'language.cfg'
$script:Language = 'EN'
$script:Text = @{ EN=@{}; ID=@{} }
$script:CurrentLog = $null
$script:LastDiagnostic = $null
Set-WorkspacePaths $dataRoot
Initialize-Workspace

if ($script:Language -ne 'ID') { throw 'Legacy language preference was not migrated.' }
if (-not (Test-Path -LiteralPath $script:LanguageFile)) { throw 'Migrated language.cfg is missing.' }
if (-not (Test-Path -LiteralPath $script:LatestStateFile)) { throw 'Migrated restore pointer is missing.' }
$migrated = ([string](Get-Content -LiteralPath $script:LatestStateFile | Select-Object -First 1)).Trim()
$expected = Join-Path $script:BackupRoot $snapshotName
if ($migrated -ne $expected) { throw "Restore pointer was not rewritten. Expected $expected but got $migrated" }
if (-not (Test-Path -LiteralPath (Join-Path $expected 'managed-state.json'))) { throw 'Legacy managed-state.json was not migrated.' }

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'Workspace smoke passed: legacy language and restore state migrate outside the repo.' -ForegroundColor Green
