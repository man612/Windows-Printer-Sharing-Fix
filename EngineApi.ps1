Set-StrictMode -Version 2.0

function New-EngineResult([bool]$Ok,[string]$Message,[string]$Snapshot='',[bool]$RestartRequired=$false) {
    [pscustomobject]@{ok=$Ok;message=$Message;snapshot=$Snapshot;restartRequired=$RestartRequired}
}

function Assert-EngineConfirmed([bool]$Confirmed,[string]$Action) {
    if(-not $Confirmed){throw "Action '$Action' requires explicit confirmation."}
}

function Invoke-EngineRestoreLatest {
    if(-not(Test-Path -LiteralPath $script:LatestStateFile)){throw 'No managed restore snapshot exists.'}
    $dir=(Get-Content -LiteralPath $script:LatestStateFile|Select-Object -First 1).Trim()
    $file=Join-Path $dir 'managed-state.json'
    if(-not(Test-Path -LiteralPath $file)){throw 'Latest restore snapshot is missing or damaged.'}
    $state=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
    foreach($r in @($state.Registry)){Restore-RegistryValue $r}
    foreach($f in @($state.FirewallRules)){
        if(Get-Command Set-NetFirewallRule -ErrorAction SilentlyContinue){
            Set-NetFirewallRule -Name $f.Name -Enabled ([string]$f.Enabled) -Profile ([string]$f.Profile) -ErrorAction SilentlyContinue
        }
    }
    foreach($n in @($state.NetworkProfiles)){
        if(Get-Command Set-NetConnectionProfile -ErrorAction SilentlyContinue){
            Set-NetConnectionProfile -InterfaceIndex ([int]$n.InterfaceIndex) -NetworkCategory ([string]$n.NetworkCategory) -ErrorAction SilentlyContinue
        }
    }
    foreach($feature in @($state.WindowsFeatures)){
        if($feature.Name -eq 'SMB1Protocol-Client' -and (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)){
            $current=Get-WindowsFeatureState $feature.Name
            if([string]$feature.State -match '^Enabled' -and $current -notmatch '^Enabled'){
                Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue|Out-Null
            }elseif([string]$feature.State -match '^Disabled' -and $current -notmatch '^Disabled'){
                Disable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue|Out-Null
            }
        }
    }
    foreach($s in @($state.Services)){
        Restore-ServiceStartMode $s.Name $s.StartMode
        if($s.State -eq 'Running'){Start-Service $s.Name -ErrorAction SilentlyContinue}
        else{Stop-Service $s.Name -Force -ErrorAction SilentlyContinue}
    }
    Write-Log "Engine restore completed from $dir"
    return $dir
}

function Invoke-PrinterFixEngineAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Action,
        [string]$Argument='',
        [int]$InterfaceIndex=-1,
        [switch]$Confirmed
    )
    $InformationPreference='SilentlyContinue'
    try{
        switch($Action){
            'safe.restart-spooler' {
                $snap=New-RestoreSnapshot 'Restart Print Spooler' @('Services')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                Stop-Service Spooler -Force;Start-Service Spooler
                return New-EngineResult $true 'Print Spooler restarted.' $snap
            }
            'safe.firewall' {
                $snap=New-RestoreSnapshot 'Repair sharing firewall' @('Firewall')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                $rules=@(Get-FirewallSharingRules)
                if(-not $rules.Count){throw 'File and Printer Sharing firewall rules could not be identified.'}
                $count=0
                foreach($r in $rules){
                    if([string]$r.Profile -match 'Private|Domain|Any'){
                        Set-NetFirewallRule -Name $r.Name -Enabled True -Profile Domain,Private -ErrorAction Stop
                        $count++
                    }
                }
                return New-EngineResult $true "Updated $count sharing firewall rule(s)." $snap
            }
            'safe.discovery' {
                $snap=New-RestoreSnapshot 'Start Network Discovery services' @('Services')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                foreach($name in @('fdPHost','FDResPub')){if(Get-Service $name -ErrorAction SilentlyContinue){Start-Service $name -ErrorAction Stop}}
                return New-EngineResult $true 'Network Discovery services started.' $snap
            }
            'safe.clear-queue' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                Stop-Service Spooler -Force -ErrorAction SilentlyContinue
                $queue="$env:SystemRoot\System32\spool\PRINTERS"
                if(Test-Path $queue){Get-ChildItem $queue -Force -ErrorAction SilentlyContinue|Remove-Item -Force -Recurse -ErrorAction Stop}
                Start-Service Spooler -ErrorAction Stop
                Write-Log 'Queue cleared through Engine API; irreversible.' 'WARN'
                return New-EngineResult $true 'Pending print jobs were cleared.'
            }
            'safe.network-private' {
                if($InterfaceIndex -lt 0){throw 'A network InterfaceIndex is required.'}
                $profile=@(Get-NetworkProfilesSafe|Where-Object{[int]$_.InterfaceIndex -eq $InterfaceIndex})|Select-Object -First 1
                if(-not $profile){throw 'Selected network interface was not found.'}
                if($profile.NetworkCategory -eq 'DomainAuthenticated'){throw 'DomainAuthenticated profiles must be controlled by domain policy.'}
                $snap=New-RestoreSnapshot 'Change selected network profile' @('Network')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                Set-NetConnectionProfile -InterfaceIndex $InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                return New-EngineResult $true "Network interface $InterfaceIndex is now Private." $snap
            }
            'compat.rpc-pipe' {
                $d=Invoke-Diagnosis -Quiet
                $snap=New-RestoreSnapshot 'RPC Named Pipes compatibility fallback' @('Registry')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                if($d.Role -match 'Client' -or $d.Role -eq 'Unknown / local only'){
                    Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcUseNamedPipeProtocol' 1
                }
                if($d.Role -match 'Host' -or $d.Role -eq 'Unknown / local only'){
                    Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC' 'RpcProtocols' 7
                }
                return New-EngineResult $true 'RPC Named Pipes fallback applied for the detected role.' $snap
            }
            'compat.point-print-connect' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                if($Argument -notmatch '^\\\\[^\\]+\\[^\\]+$'){throw 'A valid shared-printer UNC path is required.'}
                $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
                $original=Get-RegistryValueState $path 'RestrictDriverInstallationToAdministrators'
                $snap=New-RestoreSnapshot 'Temporary Point and Print relaxation' @('Registry')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                try{
                    Set-RegistryDword $path 'RestrictDriverInstallationToAdministrators' 0
                    if(Get-Command Add-Printer -ErrorAction SilentlyContinue){Add-Printer -ConnectionName $Argument -ErrorAction Stop}
                    else{Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /in /n "{0}"' -f $Argument) -Wait}
                }finally{
                    Restore-RegistryValue ([pscustomobject]@{Path=$path;Name='RestrictDriverInstallationToAdministrators';Present=$original.Present;Value=$original.Value;Kind=$original.Kind})
                }
                return New-EngineResult $true 'Printer connection attempt completed and Point and Print protection was restored.' $snap
            }
            'compat.remove-connection' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                if(-not $Argument){throw 'A printer connection name is required.'}
                $match=@(Get-PrinterInventory|Where-Object{$_.Name -eq $Argument -and ($_.Name -like '\\*' -or $_.Type -eq 'Connection')})
                if(-not $match.Count){throw 'The selected network-printer connection was not found.'}
                if(Get-Command Remove-Printer -ErrorAction SilentlyContinue){Remove-Printer -Name $Argument -ErrorAction Stop}
                else{Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /dn /n "{0}"' -f $Argument) -Wait}
                Write-Log "Targeted printer connection removed through Engine API: $Argument" 'WARN'
                return New-EngineResult $true 'Selected network-printer connection was removed.'
            }
            'compat.rpc-privacy-off' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                $snap=New-RestoreSnapshot 'High-risk RPC privacy workaround' @('Registry')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' 'RpcAuthnLevelPrivacyEnabled' 0
                return New-EngineResult $true 'RPC packet privacy was disabled. Restore after compatibility testing.' $snap
            }
            'legacy.smb1-client' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                $snap=New-RestoreSnapshot 'Enable SMB1 client' @('SMB1')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart -ErrorAction Stop|Out-Null
                return New-EngineResult $true 'SMB1 client was enabled. SMB1 server was not enabled.' $snap $true
            }
            'legacy.guest' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                $snap=New-RestoreSnapshot 'Enable insecure SMB guest' @('Registry')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth' 1
                return New-EngineResult $true 'Insecure SMB guest authentication was enabled.' $snap
            }
            'legacy.lm1' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                $snap=New-RestoreSnapshot 'Legacy LAN Manager level' @('Registry')
                if(-not $snap){throw 'Could not create a restore snapshot.'}
                Set-RegistryDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LmCompatibilityLevel' 1
                return New-EngineResult $true 'LAN Manager compatibility level 1 was applied.' $snap
            }
            'restore.latest' {
                Assert-EngineConfirmed ([bool]$Confirmed) $Action
                $dir=Invoke-EngineRestoreLatest
                return New-EngineResult $true 'Latest managed change was restored.' $dir
            }
            default { throw "Unknown Engine API action: $Action" }
        }
    }catch{
        Write-Log ("Engine API action {0} failed: {1}" -f $Action,$_.Exception.Message) 'ERROR'
        return New-EngineResult $false $_.Exception.Message
    }
}
