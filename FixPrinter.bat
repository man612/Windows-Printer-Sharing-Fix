@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0F
title Windows Printer Sharing Fix Utility
mode con: cols=108 lines=46 >nul 2>&1

:: ==============================================================================
:: Repository : Windows-Printer-Sharing-Fix
:: Description: Final verified repair utility for Windows 7/8/8.1/10/11
:: Author     : Yasman
:: Version    : 3.1.0
:: License    : MIT
:: ==============================================================================

set "VERSION=3.1.0"
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%printer_fix_log.txt"
set "BACKUP_ROOT=%SCRIPT_DIR%backups"
set "LATEST_FILE=%BACKUP_ROOT%\latest_backup.txt"
set "LANG_FILE=%SCRIPT_DIR%language.cfg"
set "LANG=ID"
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
set "FIX_MODE="
set "BACKUP_RUN_DIR="
set "OS_NAME=Windows"
set "OS_VER=Unknown"
set "BUILD_NUM=0"

pushd "%SCRIPT_DIR%" >nul 2>&1 || (
    echo [FATAL] Gagal masuk ke folder script.
    pause
    exit /b 1
)

if not exist "%BACKUP_ROOT%" (
    mkdir "%BACKUP_ROOT%" >nul 2>&1 || (
        echo [FATAL] Gagal membuat folder backup: "%BACKUP_ROOT%"
        pause
        exit /b 1
    )
)

>> "%LOG_FILE%" echo. 2>nul || (
    echo [FATAL] Gagal menulis log di folder script.
    echo Pindahkan file .bat ke Desktop lalu jalankan lagi sebagai Administrator.
    pause
    exit /b 1
)

if exist "%LANG_FILE%" (
    set /p LANG=<"%LANG_FILE%"
)
if /I not "!LANG!"=="EN" set "LANG=ID"

call :initLang
call :requireAdmin
if errorlevel 1 exit /b 1
call :detectOS
goto :mainMenu

:initLang
if /I "!LANG!"=="EN" (
    set "STR_TITLE=WINDOWS PRINTER SHARING FIX UTILITY"
    set "STR_SUBTITLE=Final audited build for Windows 7/8/8.1/10/11"
    set "STR_ADMIN_ERR=ERROR: ADMINISTRATOR PRIVILEGES REQUIRED"
    set "STR_ADMIN_DESC=[!] This script must be run as Administrator."
    set "STR_ADMIN_SOL=Right-click this file and choose Run as administrator."
    set "STR_PRESS_KEY=Press any key to exit..."
    set "STR_STATUS=Spooler Status"
    set "STR_RUNNING=RUNNING"
    set "STR_STOPPED=STOPPED"
    set "STR_UNKNOWN=UNKNOWN"
    set "STR_NOT_FOUND=NOT FOUND"
    set "STR_SELECT=Select option [1-8]: "
    set "STR_BAD_INPUT=[!] Invalid input."
    set "STR_DIAG=DIAGNOSTICS"
    set "STR_MENU=MENU"
) else (
    set "STR_TITLE=UTILITAS PERBAIKAN SHARING PRINTER WINDOWS"
    set "STR_SUBTITLE=Build audit final untuk Windows 7/8/8.1/10/11"
    set "STR_ADMIN_ERR=ERROR: BUTUH AKSES ADMINISTRATOR"
    set "STR_ADMIN_DESC=[!] Script ini harus dijalankan sebagai Administrator."
    set "STR_ADMIN_SOL=Klik kanan file ini lalu pilih Run as administrator."
    set "STR_PRESS_KEY=Tekan tombol apa saja untuk keluar..."
    set "STR_STATUS=Status Spooler"
    set "STR_RUNNING=BERJALAN"
    set "STR_STOPPED=BERHENTI"
    set "STR_UNKNOWN=TIDAK DIKETAHUI"
    set "STR_NOT_FOUND=TIDAK ADA"
    set "STR_SELECT=Pilih opsi [1-8]: "
    set "STR_BAD_INPUT=[!] Input tidak valid."
    set "STR_DIAG=DIAGNOSTIK"
    set "STR_MENU=MENU"
)
exit /b 0

:requireAdmin
fltmc >nul 2>&1
if errorlevel 1 (
    color 0C
    cls
    echo.
    echo ###############################################################################
    echo #                                                                             #
    echo #                    !STR_ADMIN_ERR!
    echo #                                                                             #
    echo ###############################################################################
    echo.
    echo !STR_ADMIN_DESC!
    echo !STR_ADMIN_SOL!
    echo.
    echo !STR_PRESS_KEY!
    pause >nul
    exit /b 1
)
exit /b 0

:detectOS
set "OS_NAME=Windows"
set "OS_VER=Unknown"
set "BUILD_NUM=0"
set "BUILD="
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul ^| find /I "ProductName"') do set "OS_NAME=%%B"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| find /I "CurrentBuild"') do set "BUILD=%%A"
if defined BUILD (
    set "OS_VER=!BUILD!"
    set /a BUILD_NUM=!BUILD! >nul 2>&1
) else (
    for /f "tokens=4-5 delims=. " %%i in ('ver') do set "OS_VER=%%i.%%j"
)
if !BUILD_NUM! GEQ 22000 (
    set "OS_NAME=Windows 11"
) else if !BUILD_NUM! GEQ 10240 (
    set "OS_NAME=Windows 10"
) else if !BUILD_NUM! GEQ 9600 (
    set "OS_NAME=Windows 8.1"
) else if !BUILD_NUM! GEQ 9200 (
    set "OS_NAME=Windows 8"
) else if !BUILD_NUM! GEQ 7600 (
    set "OS_NAME=Windows 7"
)
exit /b 0

:mainMenu
color 0F
cls
call :getServiceStatus Spooler SPOOLER_STATUS
echo.
echo ###############################################################################
echo #                                                                             #
echo #        !STR_TITLE! v!VERSION!
echo #        !STR_SUBTITLE!
echo #                                                                             #
echo ###############################################################################
echo.
echo [!STR_DIAG!]
echo - User           : %USERNAME%
echo - OS             : !OS_NAME! ^(!OS_VER!^)
echo - Build          : !BUILD_NUM!
echo - Bahasa         : !LANG!
echo - Waktu          : %DATE% %TIME%
echo - !STR_STATUS!  : !SPOOLER_STATUS!
echo.
echo -------------------------------------------------------------------------------
echo [!STR_MENU!]
echo -------------------------------------------------------------------------------
echo [1] Quick Fix Aman - spooler, cache, RPC printer, permission, firewall sharing
echo [2] Legacy/Full Fix - SMBv1 + Guest Auth + blank-password compatibility [RISIKO]
echo [3] Restore Registry dari backup terakhir
echo [4] Akses Cepat - Services, Printers, Network, Print Management
echo [5] Panduan dan catatan risiko
echo [6] Ganti Bahasa / Language
echo [7] Lihat Log
echo [8] Keluar
echo.

set "MENU_CHOICE="
set /p MENU_CHOICE="!STR_SELECT!"

if "!MENU_CHOICE!"=="1" (
    set "FIX_MODE=QUICK"
    goto :runFix
)
if "!MENU_CHOICE!"=="2" (
    set "FIX_MODE=LEGACY"
    goto :confirmLegacy
)
if "!MENU_CHOICE!"=="3" goto :restoreSettings
if "!MENU_CHOICE!"=="4" goto :quickAccess
if "!MENU_CHOICE!"=="5" goto :userGuide
if "!MENU_CHOICE!"=="6" goto :langSettings
if "!MENU_CHOICE!"=="7" goto :viewLog
if "!MENU_CHOICE!"=="8" exit /b 0

echo.
echo !STR_BAD_INPUT!
timeout /t 2 >nul
goto :mainMenu

:confirmLegacy
cls
color 0C
echo.
echo ###############################################################################
echo #                          PERINGATAN LEGACY/FULL FIX                         #
echo ###############################################################################
echo.
echo Opsi ini BUKAN untuk dicoba pertama kali.
echo Opsi ini dapat menurunkan keamanan karena mengaktifkan kompatibilitas lama:
echo - SMBv1 pada Windows modern.
echo - SMB insecure guest auth.
echo - LAN Manager compatibility.
echo - Pemakaian akun tanpa password.
echo.
echo Pakai hanya di jaringan rumah/kantor kecil yang dipercaya dan jika Quick Fix gagal.
echo.
set "CONFIRM="
set /p CONFIRM="Ketik YES untuk lanjut, selain itu batal: "
if /I not "!CONFIRM!"=="YES" goto :mainMenu
goto :runFix

:runFix
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
set "BACKUP_RUN_DIR="
cls
color 0E
echo ==============================================================================
echo                  MEMULAI PROSES [!FIX_MODE!]
echo ==============================================================================
echo.
call :log "--- Started Printer Fix [!FIX_MODE!] ---"

call :createBackup
if errorlevel 1 (
    echo [FATAL] Backup gagal dibuat. Proses dibatalkan agar aman.
    call :log "[FATAL] Backup creation failed. Aborting fix."
    pause
    goto :mainMenu
)

echo [+] Menyiapkan service printer dan sharing...
call :runCritical "Set Spooler startup auto" "sc config Spooler start= auto"
call :runWarn "Set Server startup auto" "sc config LanmanServer start= auto"
call :runWarn "Set Workstation startup auto" "sc config LanmanWorkstation start= auto"
call :safeStart LanmanServer WARN
call :safeStart LanmanWorkstation WARN
call :safeStop Spooler WARN

echo.
echo [+] Membersihkan cache/antrian printer...
call :ensureSpoolFolders
call :clearFolder "%SystemRoot%\System32\spool\PRINTERS" "Clear PRINTERS queue"
call :clearFolder "%SystemRoot%\System32\spool\SERVERS" "Clear SERVERS cache"

echo.
echo [+] Menerapkan registry printer RPC compatibility...
call :runCritical "Set RpcAuthnLevelPrivacyEnabled=0" "reg add ^"HKLM\System\CurrentControlSet\Control\Print^" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f"
call :runCritical "Set RpcUseNamedPipeProtocol=1" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f"
call :runCritical "Set RpcProtocols=7" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcProtocols /t REG_DWORD /d 7 /f"
call :deleteKeyOptional "Client Side Rendering Print Provider" "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider"

echo.
echo [+] Memperbaiki izin folder spooler secara konservatif...
call :runWarn "Grant SYSTEM/Admins on PRINTERS" "icacls ^"%SystemRoot%\System32\spool\PRINTERS^" /grant *S-1-5-18:^(OI^)^(CI^)F *S-1-5-32-544:^(OI^)^(CI^)F /T /C /Q"
call :runWarn "Grant SYSTEM/Admins on spool drivers" "icacls ^"%SystemRoot%\System32\spool\drivers^" /grant *S-1-5-18:^(OI^)^(CI^)F *S-1-5-32-544:^(OI^)^(CI^)F /T /C /Q"

echo.
echo [+] Mengaktifkan firewall rule File and Printer Sharing...
call :enableFirewallSharing

echo.
call :offerNetworkPrivate

if /I "!FIX_MODE!"=="LEGACY" (
    echo.
    echo [+] Menerapkan LEGACY/FULL compatibility fix...
    if !BUILD_NUM! GEQ 9200 (
        call :runWarn "Enable SMBv1 feature" "dism /online /Enable-Feature /FeatureName:SMB1Protocol -All /NoRestart /quiet"
    ) else (
        echo     - Enable SMBv1 feature: dilewati untuk Windows 7/legacy
        call :log "[SKIP] SMBv1 DISM feature skipped for pre-Windows 8 build."
    )
    call :runCritical "Allow insecure guest auth" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters^" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f"
    call :runWarn "Set LmCompatibilityLevel=1" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f"
    call :runWarn "Set limitblankpassworduse=0" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v limitblankpassworduse /t REG_DWORD /d 0 /f"
)

echo.
echo [+] Menyalakan ulang service...
call :safeStart Spooler FAIL
call :runWarn "Set fdPHost auto" "sc config fdPHost start= auto"
call :runWarn "Set FDResPub auto" "sc config FDResPub start= auto"
call :safeStart fdPHost WARN
call :safeStart FDResPub WARN

echo.
echo [+] Verifikasi akhir...
call :verifyFinal

echo.
if !FAIL_COUNT! GTR 0 (
    color 0C
    echo ==============================================================================
    echo SELESAI, TAPI ADA !FAIL_COUNT! MASALAH PENTING DAN !WARN_COUNT! WARNING.
    echo Buka log untuk detail. Jangan anggap fix sukses sebelum FAIL diselesaikan.
    echo ==============================================================================
) else if !WARN_COUNT! GTR 0 (
    color 0E
    echo ==============================================================================
    echo SELESAI, TAPI ADA !WARN_COUNT! WARNING. Buka log untuk detail.
    echo ==============================================================================
) else (
    color 0A
    echo ==============================================================================
    echo SELESAI TANPA WARNING/FAIL YANG TERDETEKSI OLEH SCRIPT.
    echo ==============================================================================
)
echo Log    : %LOG_FILE%
echo Backup : !BACKUP_RUN_DIR!
echo.
echo Sangat disarankan restart PC agar registry, sharing, dan service reload penuh.
choice /C YN /N /M "Restart sekarang? [Y/N]: "
if errorlevel 2 (
    echo Silakan restart manual.
    pause
    goto :mainMenu
)
shutdown /r /t 10 /c "Printer fix applied by Yasman."
exit /b 0

:createBackup
set "DT="
set "STAMP="
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul ^| find "="') do set "DT=%%I"
if defined DT (
    set "STAMP=!DT:~0,8!_!DT:~8,6!"
) else (
    for /f %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul') do set "STAMP=%%I"
)
if not defined STAMP (
    set "STAMP=%DATE%_%TIME%"
    set "STAMP=!STAMP:/=-!"
    set "STAMP=!STAMP:\=-!"
    set "STAMP=!STAMP::=-!"
    set "STAMP=!STAMP:,=-!"
    set "STAMP=!STAMP: =_!"
)
set "BACKUP_RUN_DIR=%BACKUP_ROOT%\!STAMP!_!RANDOM!"
mkdir "!BACKUP_RUN_DIR!" >nul 2>&1 || exit /b 1
echo @echo off>"!BACKUP_RUN_DIR!\reg_state.cmd" || exit /b 1
call :log "[BACKUP] Created: !BACKUP_RUN_DIR!"

reg export "HKLM\System\CurrentControlSet\Control\Print" "!BACKUP_RUN_DIR!\print_key.reg" /y >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "[FATAL] Backup Print key failed."
    exit /b 1
)

reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers" "!BACKUP_RUN_DIR!\providers_key.reg" /y >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "[WARN] Backup Providers key failed or key not found. Restore will skip provider-tree import."
)

call :saveValueState "RpcAuthnLevelPrivacyEnabled" "HKLM\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled"
call :saveValueState "RpcUseNamedPipeProtocol" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcUseNamedPipeProtocol"
call :saveValueState "RpcProtocols" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcProtocols"
call :saveValueState "AllowInsecureGuestAuth" "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth"
call :saveValueState "LmCompatibilityLevel" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel"
call :saveValueState "limitblankpassworduse" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "limitblankpassworduse"

echo !BACKUP_RUN_DIR!>"%LATEST_FILE%" || exit /b 1
exit /b 0

:saveValueState
set "SNAME=%~1"
set "SKEY=%~2"
set "SVALUE=%~3"
set "FOUND=0"
set "VTYPE="
set "VDATA="
for /f "tokens=2,3" %%B in ('reg query "%SKEY%" /v "%SVALUE%" 2^>nul ^| findstr /I /C:"%SVALUE%"') do (
    set "FOUND=1"
    set "VTYPE=%%B"
    set "VDATA=%%C"
)
if "!FOUND!"=="1" (
    echo set "STATE_%SNAME%=PRESENT">>"!BACKUP_RUN_DIR!\reg_state.cmd"
    echo set "TYPE_%SNAME%=!VTYPE!">>"!BACKUP_RUN_DIR!\reg_state.cmd"
    echo set "DATA_%SNAME%=!VDATA!">>"!BACKUP_RUN_DIR!\reg_state.cmd"
) else (
    echo set "STATE_%SNAME%=ABSENT">>"!BACKUP_RUN_DIR!\reg_state.cmd"
)
exit /b 0

:restoreSettings
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
cls
color 0E
echo ==============================================================================
echo                  RESTORE REGISTRY DARI BACKUP TERAKHIR
echo ==============================================================================
echo.
if not exist "%LATEST_FILE%" (
    echo [!] Belum ada backup.
    pause
    goto :mainMenu
)
set "RESTORE_DIR="
set /p RESTORE_DIR=<"%LATEST_FILE%"
if not exist "!RESTORE_DIR!\reg_state.cmd" (
    echo [!] Backup rusak atau tidak lengkap.
    pause
    goto :mainMenu
)
call :log "--- Restore started from !RESTORE_DIR! ---"
call "!RESTORE_DIR!\reg_state.cmd"
call :safeStop Spooler WARN

if exist "!RESTORE_DIR!\print_key.reg" (
    call :runCritical "Import Print key backup" "reg import ^"!RESTORE_DIR!\print_key.reg^""
) else (
    call :addIssue FAIL "print_key.reg missing during restore."
)

if exist "!RESTORE_DIR!\providers_key.reg" (
    call :runWarn "Import Providers key backup" "reg import ^"!RESTORE_DIR!\providers_key.reg^""
) else (
    call :addIssue WARN "providers_key.reg missing during restore."
)

call :restoreValue "RpcAuthnLevelPrivacyEnabled" "HKLM\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled"
call :restoreValue "RpcUseNamedPipeProtocol" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcUseNamedPipeProtocol"
call :restoreValue "RpcProtocols" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcProtocols"
call :restoreValue "AllowInsecureGuestAuth" "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth"
call :restoreValue "LmCompatibilityLevel" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel"
call :restoreValue "limitblankpassworduse" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "limitblankpassworduse"

call :safeStart Spooler FAIL
echo.
if !FAIL_COUNT! GTR 0 (
    color 0C
    echo [!] Restore selesai, tetapi ada !FAIL_COUNT! masalah penting dan !WARN_COUNT! warning. Cek log.
) else if !WARN_COUNT! GTR 0 (
    color 0E
    echo [!] Restore selesai dengan !WARN_COUNT! warning. Cek log.
) else (
    color 0A
    echo [+] Restore selesai tanpa warning yang terdeteksi.
)
echo Log: %LOG_FILE%
echo Disarankan restart PC.
pause
goto :mainMenu

:restoreValue
set "RNAME=%~1"
set "RKEY=%~2"
set "RVALUE=%~3"
set "RSTATE="
set "RTYPE="
set "RDATA="
call set "RSTATE=%%STATE_%RNAME%%%"
call set "RTYPE=%%TYPE_%RNAME%%%"
call set "RDATA=%%DATA_%RNAME%%%"
if /I "!RSTATE!"=="PRESENT" (
    if not defined RTYPE set "RTYPE=REG_DWORD"
    call :runWarn "Restore %RVALUE%=!RDATA!" "reg add ^"%RKEY%^" /v %RVALUE% /t !RTYPE! /d !RDATA! /f"
) else if /I "!RSTATE!"=="ABSENT" (
    call :deleteValueOptional "%RVALUE%" "%RKEY%" "%RVALUE%"
) else (
    call :addIssue WARN "Missing saved state for %RNAME%; restore skipped."
)
exit /b 0

:getServiceStateCode
set "%~2=0"
for /f "tokens=3" %%S in ('sc query "%~1" 2^>nul ^| findstr /I /C:"STATE"') do set "%~2=%%S"
exit /b 0

:getServiceStatus
set "%~2=!STR_UNKNOWN!"
sc query "%~1" >nul 2>&1 || (
    set "%~2=!STR_NOT_FOUND!"
    exit /b 1
)
call :getServiceStateCode "%~1" _SVC_CODE
if "!_SVC_CODE!"=="4" (
    set "%~2=!STR_RUNNING!"
    exit /b 0
)
if "!_SVC_CODE!"=="1" (
    set "%~2=!STR_STOPPED!"
    exit /b 0
)
set "%~2=!STR_UNKNOWN! ^(STATE !_SVC_CODE!^)"
exit /b 0

:isServiceRunning
call :getServiceStateCode "%~1" _RUN_CODE
if "!_RUN_CODE!"=="4" exit /b 0
exit /b 1

:safeStop
set "SVC=%~1"
set "SEV=%~2"
if not defined SEV set "SEV=WARN"
sc query "%SVC%" >nul 2>&1 || (
    call :log "[SKIP] Service %SVC% not found."
    exit /b 0
)
call :isServiceRunning "%SVC%"
if errorlevel 1 (
    call :log "[OK] Service %SVC% already stopped/not running."
    exit /b 0
)
net stop "%SVC%" /y >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :addIssue %SEV% "Stop %SVC% failed."
    exit /b 1
)
call :log "[OK] Stopped %SVC%."
exit /b 0

:safeStart
set "SVC=%~1"
set "SEV=%~2"
if not defined SEV set "SEV=WARN"
sc query "%SVC%" >nul 2>&1 || (
    call :log "[SKIP] Service %SVC% not found."
    exit /b 0
)
call :isServiceRunning "%SVC%"
if not errorlevel 1 (
    call :log "[OK] Service %SVC% already running."
    exit /b 0
)
net start "%SVC%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :addIssue %SEV% "Start %SVC% failed."
    exit /b 1
)
call :log "[OK] Started %SVC%."
exit /b 0

:runWarn
call :runCommand "%~1" "%~2" WARN
exit /b %ERRORLEVEL%

:runCritical
call :runCommand "%~1" "%~2" FAIL
exit /b %ERRORLEVEL%

:runCommand
set "DESC=%~1"
set "CMD=%~2"
set "SEV=%~3"
echo     - !DESC!
call :log "[CMD] !DESC!"
%CMD% >> "%LOG_FILE%" 2>&1
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" (
    call :addIssue !SEV! "!DESC! failed. Code: !RC!"
    exit /b !RC!
)
call :log "[OK] !DESC!"
exit /b 0

:addIssue
set "SEV=%~1"
set "MSG=%~2"
if /I "!SEV!"=="FAIL" (
    set /a FAIL_COUNT+=1
    call :log "[FAIL] !MSG!"
) else (
    set /a WARN_COUNT+=1
    call :log "[WARN] !MSG!"
)
exit /b 0

:deleteValueOptional
reg query "%~2" /v "%~3" >nul 2>&1
if errorlevel 1 (
    call :log "[OK] %~1 already absent."
    exit /b 0
)
call :runWarn "Delete %~3" "reg delete ^"%~2^" /v %~3 /f"
exit /b 0

:deleteKeyOptional
reg query "%~2" >nul 2>&1
if errorlevel 1 (
    echo     - %~1 sudah tidak ada
    call :log "[OK] %~1 already absent."
    exit /b 0
)
call :runWarn "Delete %~1" "reg delete ^"%~2^" /f"
exit /b 0

:ensureSpoolFolders
if not exist "%SystemRoot%\System32\spool\PRINTERS" mkdir "%SystemRoot%\System32\spool\PRINTERS" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\SERVERS" mkdir "%SystemRoot%\System32\spool\SERVERS" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\drivers" mkdir "%SystemRoot%\System32\spool\drivers" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\PRINTERS" call :addIssue FAIL "Folder spool PRINTERS tidak bisa dibuat."
exit /b 0

:clearFolder
set "TARGET=%~1"
set "DESC=%~2"
echo     - !DESC!
call :log "[CMD] !DESC!"
if not exist "!TARGET!" mkdir "!TARGET!" >nul 2>&1
if not exist "!TARGET!" (
    call :addIssue FAIL "!DESC! failed because folder is missing: !TARGET!"
    exit /b 1
)
del /Q /F "!TARGET!\*" >> "%LOG_FILE%" 2>&1
for /d %%D in ("!TARGET!\*") do rd /S /Q "%%~fD" >> "%LOG_FILE%" 2>&1
call :log "[OK] !DESC! completed."
exit /b 0

:enableFirewallSharing
netsh advfirewall firewall set rule group="@FirewallAPI.dll,-28502" new enable=Yes >> "%LOG_FILE%" 2>&1
if not errorlevel 1 (
    echo     - Firewall File and Printer Sharing enabled
    call :log "[OK] Firewall File and Printer Sharing enabled by resource id."
    exit /b 0
)
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >> "%LOG_FILE%" 2>&1
if not errorlevel 1 (
    echo     - Firewall File and Printer Sharing enabled
    call :log "[OK] Firewall File and Printer Sharing enabled by English fallback."
    exit /b 0
)
netsh firewall set service type=FILEANDPRINT mode=ENABLE >> "%LOG_FILE%" 2>&1
if not errorlevel 1 (
    echo     - Firewall File and Printer Sharing enabled
    call :log "[OK] Firewall File and Printer Sharing enabled by legacy netsh fallback."
    exit /b 0
)
echo     - Firewall File and Printer Sharing gagal
call :addIssue WARN "Enable Firewall File and Printer Sharing failed."
exit /b 1

:offerNetworkPrivate
if !BUILD_NUM! LSS 9200 (
    echo [i] Windows 7/legacy: Set-NetConnectionProfile dilewati.
    call :log "[SKIP] Set-NetConnectionProfile skipped for pre-Windows 8 build."
    exit /b 0
)
choice /C YN /N /M "Ubah network aktif ke Private? [Y/N]: "
if errorlevel 2 exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -ne 'DomainAuthenticated'} | Set-NetConnectionProfile -NetworkCategory Private" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :addIssue WARN "Set network private failed."
) else (
    call :log "[OK] Network profile set to Private where applicable."
)
exit /b 0

:verifyFinal
call :getServiceStatus Spooler VERIFY_SPOOLER
echo     - Spooler: !VERIFY_SPOOLER!
if /I not "!VERIFY_SPOOLER!"=="!STR_RUNNING!" (
    call :addIssue FAIL "Spooler is not running after fix."
)
call :verifyDword "HKLM\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled" "0x0"
call :verifyDword "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcUseNamedPipeProtocol" "0x1"
call :verifyDword "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcProtocols" "0x7"
if /I "!FIX_MODE!"=="LEGACY" (
    call :verifyDword "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth" "0x1"
)
exit /b 0

:verifyDword
set "VKEY=%~1"
set "VNAME=%~2"
set "EXPECTED=%~3"
set "ACTUAL="
for /f "tokens=3" %%V in ('reg query "%VKEY%" /v "%VNAME%" 2^>nul ^| findstr /I /C:"%VNAME%"') do set "ACTUAL=%%V"
if /I not "!ACTUAL!"=="!EXPECTED!" (
    echo     - %VNAME%: tidak sesuai ^(aktual=!ACTUAL!, target=%EXPECTED%^) 
    call :addIssue FAIL "%VNAME% verification failed. Actual=!ACTUAL!, Expected=%EXPECTED%."
) else (
    echo     - %VNAME%: OK
    call :log "[OK] %VNAME% verified as %EXPECTED%."
)
exit /b 0

:viewLog
if exist "%LOG_FILE%" (
    start "" notepad.exe "%LOG_FILE%"
) else (
    echo [!] Log tidak ada.
    pause
)
goto :mainMenu

:quickAccess
cls
echo [QUICK ACCESS]
echo [1] Services
echo [2] Printers
echo [3] Network and Sharing Center
echo [4] Print Management
echo [5] Back
echo.
set "QA_CHOICE="
set /p QA_CHOICE="Pilih: "
if "!QA_CHOICE!"=="1" (
    start "" services.msc
    goto :quickAccess
)
if "!QA_CHOICE!"=="2" (
    start "" control.exe printers
    goto :quickAccess
)
if "!QA_CHOICE!"=="3" (
    start "" control.exe /name Microsoft.NetworkAndSharingCenter
    goto :quickAccess
)
if "!QA_CHOICE!"=="4" (
    start "" printmanagement.msc
    goto :quickAccess
)
if "!QA_CHOICE!"=="5" goto :mainMenu
goto :quickAccess

:userGuide
cls
echo [PANDUAN ^& RISIKO]
echo.
echo 1. Jalankan sebagai Administrator.
echo 2. Gunakan Quick Fix dulu.
echo 3. Legacy/Full Fix hanya untuk kasus lama/bandel karena menurunkan keamanan.
echo 4. Backup registry dibuat per eksekusi dan tidak ditimpa.
echo 5. Restore menu hanya mengembalikan registry yang dibackup, bukan driver printer.
echo 6. Windows 7 didukung sebatas kompatibilitas command; hasil tetap tergantung driver/update/SMB.
echo 7. Jika muncul FAIL, jangan anggap sukses. Buka log dan perbaiki penyebabnya.
echo.
pause
goto :mainMenu

:langSettings
cls
echo [LANGUAGE / BAHASA]
echo [1] ID
echo [2] EN
echo [3] Kembali
echo.
set "LC="
set /p LC="Pilih: "
if "!LC!"=="1" (
    set "LANG=ID"
    echo ID>"%LANG_FILE%"
    call :initLang
    goto :mainMenu
)
if "!LC!"=="2" (
    set "LANG=EN"
    echo EN>"%LANG_FILE%"
    call :initLang
    goto :mainMenu
)
goto :mainMenu

:log
>> "%LOG_FILE%" echo [%DATE% %TIME%] %~1
exit /b 0
