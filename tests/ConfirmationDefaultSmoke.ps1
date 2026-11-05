$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$main=Join-Path (Split-Path -Parent $PSScriptRoot) 'FixPrinter.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($main,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Main source does not parse.'}
$fn=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Read-YesNo'})|Select-Object -First 1
if(-not $fn){throw 'Read-YesNo was not found.'}
. ([scriptblock]::Create($fn.Extent.Text))
$script:Response=''
$script:Prompt=''
function Read-Host([string]$Prompt){$script:Prompt=$Prompt;return $script:Response}
$script:Response=''
if(Read-YesNo 'Delete queue?' $true){throw 'Empty input was treated as Yes with DefaultNo=True.'}
if($script:Prompt -notmatch '\[y/N\]'){throw 'Default-No did not display y/N to the user.'}
$script:Response=''
if(-not(Read-YesNo 'Open Settings?' $false)){throw 'Default-Yes behavior was incorrectly changed.'}
if($script:Prompt -notmatch '\[Y/n\]'){throw 'Default-Yes did not display Y/n to the user.'}
$script:Response='y'
if(-not(Read-YesNo 'Continue?' $true)){throw 'Explicit Yes rejected.'}
$script:Response='n'
if(Read-YesNo 'Continue?' $false){throw 'Explicit No rejected.'}
$source=Get-Content -LiteralPath $main -Raw
$patterns=@(
  "Read-YesNo (L 'Permanently delete these queued files?' 'Hapus file antrean tersebut secara permanen?') "+'$true',
  "Read-YesNo ((L 'Remove only {0}?' 'Lepas hanya {0}?') -f "+'$target) $true',
  "Read-YesNo (L 'Send one Windows test page now?' 'Kirim satu test page Windows sekarang?') "+'$true'
)
foreach($pattern in $patterns){
  if(-not $source.Contains($pattern)){throw "Risky action default-No guard changed: $pattern"}
}
Write-Host 'Confirmation defaults smoke passed: Enter cannot approve destructive actions.' -ForegroundColor Green
