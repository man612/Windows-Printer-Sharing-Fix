$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repo 'FixPrinter.ps1'
$launcher = Join-Path $repo 'FixPrinter.bat'

if (-not (Test-Path $scriptFile)) { throw 'FixPrinter.ps1 is missing.' }
if (-not (Test-Path $launcher)) { throw 'FixPrinter.bat is missing.' }

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    $parseErrors | ForEach-Object { Write-Error ("PowerShell parse error at {0}: {1}" -f $_.Extent.StartLineNumber,$_.Message) }
    throw "FixPrinter.ps1 has $($parseErrors.Count) parse error(s)."
}

$source = Get-Content $scriptFile -Raw
$bat = Get-Content $launcher -Raw

function Get-FunctionText([string]$Name) {
    $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
    if (-not $node) { throw "Expected function missing: $Name" }
    return $node.Extent.Text
}

# English must remain the first/default language.
if ($source -notmatch [regex]::Escape("`$script:Language = 'EN'")) { throw 'English is not configured as the default language.' }

# The batch file should only launch the PowerShell implementation.
if ($bat -notmatch 'FixPrinter\.ps1') { throw 'FixPrinter.bat does not launch FixPrinter.ps1.' }
if ($bat -match 'RpcAuthnLevelPrivacyEnabled|RestrictDriverInstallationToAdministrators|SMB1Protocol') { throw 'Security/repair logic leaked back into the batch launcher.' }

# Safe Repair must not contain any security downgrades.
$safeFunctions = @('Show-SafeRepairMenu','Invoke-RestartSpooler','Invoke-ClearPrintQueue','Enable-PrivateFirewallSharing','Set-OneNetworkPrivate','Start-NetworkDiscoveryServices')
$forbiddenInSafe = @('RpcAuthnLevelPrivacyEnabled','RestrictDriverInstallationToAdministrators','SMB1Protocol','AllowInsecureGuestAuth','LmCompatibilityLevel','LimitBlankPasswordUse')
foreach ($fn in $safeFunctions) {
    $text = Get-FunctionText $fn
    foreach ($needle in $forbiddenInSafe) {
        if ($text -match [regex]::Escape($needle)) { throw "Safe Repair function $fn contains forbidden security setting: $needle" }
    }
}

# Dangerous v3 patterns must not return.
if ($source -match 'BypassUpdateRoleIndicator') { throw 'Unsupported BypassUpdateRoleIndicator tweak must not be present.' }
if ($source -match 'Client Side Rendering Print Provider') { throw 'Whole-provider registry deletion must not be present.' }
if ($source -match 'Set-RegistryDword[^\r\n]+LimitBlankPasswordUse[^\r\n]+\s0(?:\s|;|$)') { throw 'The utility must never automate disabling LimitBlankPasswordUse.' }
if ($source -match 'SMB1Protocol\s+-All') { throw 'The utility must never enable the entire SMB1 feature tree.' }

# Point and Print relaxation must be restored in a finally block.
$point = Get-FunctionText 'Connect-SharedPrinterTemporarilyRelaxed'
if ($point -notmatch 'finally') { throw 'Temporary Point and Print relaxation has no finally block.' }
if ($point -notmatch 'Restore-RegistryValue') { throw 'Temporary Point and Print relaxation does not restore its original state.' }

# High-risk compatibility changes must require explicit typed confirmation.
$rpcRisk = Get-FunctionText 'Set-RpcPrivacyCompatibility'
if ($rpcRisk -notmatch 'Type RISK') { throw 'RPC privacy downgrade lacks explicit RISK confirmation.' }
$legacy = Get-FunctionText 'Show-LegacyMenu'
if ($legacy -match '\[[0-9]+\].*Full Fix') { throw 'One-click legacy Full Fix must not return.' }

# Stable UX release guards.
if ($source -notmatch [regex]::Escape("`$script:Version = '4.0.1'")) { throw 'Stable script version is not 4.0.1.' }
if ($source -notmatch "Guide='Guide'" -or $source -notmatch "Guide='Panduan'") { throw 'Guide label is not localized in both languages.' }
$guide = Get-FunctionText 'Show-GuideMenu'
if ($guide -notmatch 'DIAGNOSIS DULU' -or $guide -notmatch 'LEGACY ADALAH PILIHAN TERAKHIR') { throw 'Indonesian in-app guide content is incomplete.' }
$main = Get-FunctionText 'Show-MainMenu'
if ($main -notmatch 'Show-GuideMenu') { throw 'Main menu does not expose the in-app guide.' }
foreach ($fn in @('Show-DiagnosticReport','Invoke-SharedPrinterPathDiagnosis','Show-SafeRepairMenu','Show-CompatibilityMenu','Show-LegacyMenu','Show-ToolsMenu')) {
    if ((Get-FunctionText $fn) -notmatch '\bL\s') { throw "Localized UI helper is not used by $fn." }
}

# Windows Server must not be relabeled as Windows 11 just because it shares a modern build number.
Invoke-Expression (Get-FunctionText 'Resolve-WindowsProductName')
if ((Resolve-WindowsProductName 'Windows Server 2025 Standard' 'Server' 26100) -ne 'Windows Server 2025 Standard') { throw 'Windows Server 2025 is misclassified as a desktop Windows release.' }
if ((Resolve-WindowsProductName 'Windows 10 Pro' 'Client' 26100) -ne 'Windows 11') { throw 'Desktop build 26100 should be classified as Windows 11.' }
Write-Host 'Validation passed: syntax, launcher separation, and v4 safety guards are intact.' -ForegroundColor Green
