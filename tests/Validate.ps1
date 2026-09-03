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
if ($source -match "Set-RegistryDword\s+['\"]HKLM:.*LimitBlankPasswordUse['\"]\s+0") { throw 'The utility must never automate disabling LimitBlankPasswordUse.' }
if ($source -match 'SMB1Protocol\s+-All') { throw 'The utility must never enable the entire SMB1 feature tree.' }

# Point and Print relaxation must be restored in a finally block.
$point = Get-FunctionText 'Connect-SharedPrinterTemporarilyRelaxed'
if ($point -notmatch 'finally') { throw 'Temporary Point and Print relaxation has no finally block.' }
if ($point -notmatch 'Restore-RegistryValue') { throw 'Temporary Point and Print relaxation does not restore its original state.' }

# High-risk compatibility changes must require explicit typed confirmation.
$rpcRisk = Get-FunctionText 'Set-RpcPrivacyCompatibility'
if ($rpcRisk -notmatch "Type RISK") { throw 'RPC privacy downgrade lacks explicit RISK confirmation.' }
$legacy = Get-FunctionText 'Show-LegacyMenu'
if ($legacy -match 'Full Fix') {
    # Text may explain that Full Fix no longer exists; only reject a callable menu item pattern.
    if ($legacy -match '\[[0-9]+\].*Full Fix') { throw 'One-click legacy Full Fix must not return.' }
}

Write-Host 'Validation passed: syntax, launcher separation, and v4 safety guards are intact.' -ForegroundColor Green
