@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0F
title Windows Printer Sharing Fix Utility
mode con: cols=105 lines=45 >nul 2>&1

:: ==============================================================================
:: Repository: Windows-Printer-Sharing-Fix
:: Description: Professional Audited Fix for Windows 7/8/10/11 Printer Sharing
:: Author: Yasman
:: Version: 2.8.0
:: License: MIT
:: ==============================================================================

set "VERSION=2.8.0"
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%printer_fix_log.txt"
set "BACKUP_ROOT=%SCRIPT_DIR%backups"
set "LATEST_FILE=%BACKUP_ROOT%\latest_backup.txt"
set "LANG_FILE=%SCRIPT_DIR%language.cfg"
set "LANG=ID"
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
set "FIX_MODE="

:: Ensure we are in the script's directory
pushd "%SCRIPT_DIR%" >nul 2>&1

:: Create backup root if not exist
if not exist "%BACKUP_ROOT%" mkdir "%BACKUP_ROOT%" >nul 2>&1

:: Load persistent language setting
if exist "%LANG_FILE%" (
    set /p LANG=<"%LANG_FILE%"
)
if /I not "!LANG!"=="EN" set "LANG=ID"

call :initLang
call :requireAdmin
call :detectOS
goto mainMenu

:initLang
if /I "!LANG!"=="EN" (
    set "STR_TITLE=WINDOWS PRINTER SHARING FIX UTILITY"
    set "STR_SUBTITLE=Audited safer rebuild for Windows 7/8/10/11"
    set "STR_ADMIN_ERR=ERROR: ADMINISTRATOR PRIVILEGES REQUIRED"
    set "STR_ADMIN_DESC=[!] This script must be run as Administrator."
    set "STR_ADMIN_SOL=Right-click this file and choose Run as administrator."
    set "STR_PRESS_KEY=Press any key to exit..."
    set "STR_STATUS=Spooler Status"
    set "STR_RUNNING=RUNNING"
    set "STR_STOPPED=STOPPED"
    set "STR_UNKNOWN=UNKNOWN"
    set "STR_SELECT=Select option [1-8]: "
    set "STR_BAD_INPUT=[!] Invalid input."
    set "STR_DIAG=DIAGNOSTICS"
    set "STR_MENU=MENU"
) else (
    set "STR_TITLE=UTILITAS PERBAIKAN SHARING PRINTER WINDOWS"
    set "STR_SUBTITLE=Versi audit lebih aman untuk Windows 7/8/10/11"
    set "STR_ADMIN_ERR=ERROR: BUTUH AKSES ADMINISTRATOR"
    set "STR_ADMIN_DESC=[!] Script ini harus dijalankan sebagai Administrator."
    set "STR_ADMIN_SOL=Klik kanan file ini lalu pilih Run as administrator."
    set "STR_PRESS_KEY=Tekan tombol apa saja untuk keluar..."
    set "STR_STATUS=Status Spooler"
    set "STR_RUNNING=BERJALAN"
    set "STR_STOPPED=BERHENTI"
    set "STR_UNKNOWN=TIDAK DIKETAHUI"
    set "STR_SELECT=Pilih opsi [1-8]: "
    set "STR_BAD_INPUT=[!] Input tidak valid."
    set "STR_DIAG=DIAGNOSTIK"
    set "STR_MENU=MENU"
)
exit /b 0

:requireAdmin
fltmc >nul 2>&1
if errorlevel 1 (
    color 0C & cls & echo.
    echo ###############################################################################
    echo #                                                                             #
    echo #                    !STR_ADMIN_ERR!
    echo #                                                                             #
    echo ###############################################################################
    echo. & echo !STR_ADMIN_DESC! & echo !STR_ADMIN_SOL! & echo.
    echo !STR_PRESS_KEY! & pause >nul & exit /b 1
)
exit /b 0

:detectOS
set "OS_NAME=Windows"
set "OS_VER=Unknown"
set "BUILD_NUM=0"
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul ^| find /I "ProductName"') do set "OS_NAME=%%B"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| find /I "CurrentBuild"') do set "BUILD=%%A"
if defined BUILD (
    set "OS_VER=!BUILD!"
    set /a BUILD_NUM=!BUILD! >nul 2>&1
) else (
    for /f "tokens=4-5 delims=. " %%i in ('ver') do set "OS_VER=%%i.%%j"
)
if !BUILD_NUM! GEQ 22000 ( set "OS_NAME=Windows 11" ) else if !BUILD_NUM! GEQ 10240 ( set "OS_NAME=Windows 10" )
exit /b 0

:mainMenu
color 0F & cls
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
echo - User      : %USERNAME%
echo - OS        : !OS_NAME! ^(!OS_VER!^)
echo - Build     : !BUILD_NUM!
echo - Bahasa    : !LANG!
echo - Waktu     : %DATE% %TIME%
echo - !STR_STATUS!: !SPOOLER_STATUS!
echo.
echo -------------------------------------------------------------------------------
echo [!STR_MENU!]
echo -------------------------------------------------------------------------------
echo [1] Quick Fix Aman - reset spooler, cache, RPC printer, firewall sharing
echo [2] Legacy/Full Fix - SMBv1 + Guest Auth + blank-password compatibility [BERISIKO]
echo [3] Restore Registry dari backup terakhir
echo [4] Akses Cepat - Services, Printers, Network, Print Management
echo [5] Panduan dan catatan risiko
echo [6] Ganti Bahasa / Language
echo [7] Lihat Log
echo [8] Keluar
echo.

set "MENU_CHOICE="
set /p MENU_CHOICE="!STR_SELECT!"

if "!MENU_CHOICE!"=="1" set "FIX_MODE=QUICK" & goto runFix
if "!MENU_CHOICE!"=="2" set "FIX_MODE=LEGACY" & goto confirmLegacy
if "!MENU_CHOICE!"=="3" goto restoreSettings
if "!MENU_CHOICE!"=="4" goto quickAccess
if "!MENU_CHOICE!"=="5" goto userGuide
if "!MENU_CHOICE!"=="6" goto langSettings
if "!MENU_CHOICE!"=="7" goto viewLog
if "!MENU_CHOICE!"=="8" exit /b 0

echo. & echo !STR_BAD_INPUT! & timeout /t 2 >nul & goto mainMenu

:getServiceStatus
set "%~2=!STR_UNKNOWN!"
sc query "%~1" | find /I "RUNNING" >nul 2>&1 && set "%~2=!STR_RUNNING!"
sc query "%~1" | find /I "STOPPED" >nul 2>&1 && set "%~2=!STR_STOPPED!"
exit /b 0

:confirmLegacy
cls & color 0C & echo.
echo ###############################################################################
echo #                          PERINGATAN LEGACY/FULL FIX                         #
echo ###############################################################################
echo.
echo Opsi ini BUKAN untuk dicoba pertama kali.
echo Opsi ini bisa menurunkan keamanan karena dapat mengaktifkan:
echo - SMBv1 pada Windows modern. ^| - SMB insecure guest auth.
echo - LAN Manager compatibility. ^| - Pemakaian akun tanpa password.
echo.
echo Pakai hanya di jaringan rumah yang kamu percaya dan jika Quick Fix gagal.
echo.
set "CONFIRM="
set /p CONFIRM="Ketik YES untuk lanjut, selain itu batal: "
if /I not "!CONFIRM!"=="YES" goto mainMenu
goto runFix

:runFix
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
cls & color 0E & echo ==============================================================================
echo                  MEMULAI PROSES [!FIX_MODE!]
echo ==============================================================================
echo.
call :log "--- Started Printer Fix [!FIX_MODE!] ---"
call :createBackup
if errorlevel 1 (
    echo [!] Backup gagal dibuat. Proses dibatalkan agar aman.
    call :log "[FATAL] Backup creation failed. Aborting."
    pause & goto mainMenu
)

echo [+] Menyiapkan service printer dan sharing...
call :runCmd "Set Spooler startup auto" "sc config Spooler start= auto"
call :runCmd "Set Server startup auto" "sc config LanmanServer start= auto"
call :runCmd "Set Workstation startup auto" "sc config LanmanWorkstation start= auto"
call :safeStart LanmanServer
call :safeStart LanmanWorkstation
call :safeStop Spooler

echo. & echo [+] Membersihkan cache/antrian printer...
call :ensureSpoolFolders
call :runCmd "Clear PRINTERS queue" "del /Q /F /S ^"%SystemRoot%\System32\spool\PRINTERS\*.*^""
call :runCmd "Clear SERVERS cache" "del /Q /F /S ^"%SystemRoot%\System32\spool\SERVERS\*.*^""

echo. & echo [+] Menerapkan registry printer RPC compatibility...
call :runCmd "Set RpcAuthnLevelPrivacyEnabled=0" "reg add ^"HKLM\System\CurrentControlSet\Control\Print^" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f"
call :runCmd "Set RpcUseNamedPipeProtocol=1" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f"
call :runCmd "Set RpcProtocols=7" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcProtocols /t REG_DWORD /d 7 /f"
call :runCmd "Remove Client Side Rendering key" "reg delete ^"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider^" /f"

echo. & echo [+] Memperbaiki izin folder spooler (SID-based)...
call :runCmd "Grant SYSTEM/Admins on PRINTERS" "icacls ^"%SystemRoot%\System32\spool\PRINTERS^" /grant *S-1-5-18:^(OI^)^(CI^)F *S-1-5-32-544:^(OI^)^(CI^)F /T /C /Q"
call :runCmd "Grant Everyone access" "icacls ^"%SystemRoot%\System32\spool\drivers^" /grant *S-1-1-0:^(OI^)^(CI^)M /T /C /Q"

echo. & echo [+] Mengaktifkan firewall rule File and Printer Sharing...
call :runCmd "Enable Firewall Rule Group" "netsh advfirewall firewall set rule group=^"@FirewallAPI.dll,-28502^" new enable=Yes"

echo.
call :offerNetworkPrivate

if /I "!FIX_MODE!"=="LEGACY" (
    echo. & echo [+] Menerapkan LEGACY/FULL compatibility fix...
    if !BUILD_NUM! GEQ 9200 (
        call :runCmd "Enable SMBv1 feature" "dism /online /Enable-Feature /FeatureName:SMB1Protocol -All /NoRestart /quiet"
    )
    call :runCmd "Allow insecure guest auth" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters^" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f"
    call :runCmd "Set LmCompatibilityLevel=1" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f"
    call :runCmd "Set limitblankpassworduse=0" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v limitblankpassworduse /t REG_DWORD /d 0 /f"
)

echo. & echo [+] Menyalakan ulang service...
call :safeStart Spooler
call :runCmd "Set fdPHost auto" "sc config fdPHost start= auto"
call :runCmd "Set FDResPub auto" "sc config FDResPub start= auto"
call :safeStart fdPHost
call :safeStart FDResPub

echo.
if !WARN_COUNT! GTR 0 (
    color 0E & echo ==============================================================================
    echo SELESAI, TAPI ADA !WARN_COUNT! WARNING. Buka log untuk detail.
    echo ==============================================================================
) else (
    color 0A & echo ==============================================================================
    echo SELESAI TANPA WARNING YANG TERDETEKSI OLEH SCRIPT.
    echo ==============================================================================
)
echo Log    : %LOG_FILE% ^| Backup : !BACKUP_RUN_DIR!
echo. & echo Sangat disarankan restart PC.
choice /C YN /N /M "Restart sekarang? [Y/N]: "
if errorlevel 2 ( echo Silakan restart manual. & pause & goto mainMenu )
shutdown /r /t 10 /c "Printer fix applied by Yasman."
exit /b 0

:createBackup
set "DT="
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul ^| find "="') do set "DT=%%I"
if defined DT ( set "STAMP=!DT:~0,8!_!DT:~8,6!" ) else ( set "STAMP=%DATE%_%TIME%" & set "STAMP=!STAMP:/=-!" & set "STAMP=!STAMP::=-!" & set "STAMP=!STAMP: =_!" )
set "BACKUP_RUN_DIR=%BACKUP_ROOT%\!STAMP!"
mkdir "!BACKUP_RUN_DIR!" >nul 2>&1 || exit /b 1
echo !BACKUP_RUN_DIR!>"%LATEST_FILE%"
echo @echo off>"!BACKUP_RUN_DIR!\reg_state.cmd"
call :log "[BACKUP] Created: !BACKUP_RUN_DIR!"
call :runCmd "Backup Print key" "reg export ^"HKLM\System\CurrentControlSet\Control\Print^" ^"!BACKUP_RUN_DIR!\print_key.reg^" /y"
call :runCmd "Backup Providers key" "reg export ^"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers^" ^"!BACKUP_RUN_DIR!\providers_key.reg^" /y"
call :saveDwordState "RpcAuthnLevelPrivacyEnabled" "HKLM\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled"
call :saveDwordState "RpcUseNamedPipeProtocol" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcUseNamedPipeProtocol"
call :saveDwordState "RpcProtocols" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcProtocols"
call :saveDwordState "AllowInsecureGuestAuth" "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth"
call :saveDwordState "LmCompatibilityLevel" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel"
call :saveDwordState "limitblankpassworduse" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "limitblankpassworduse"
exit /b 0

:saveDwordState
set "SNAME=%~1" & set "SKEY=%~2" & set "SVALUE=%~3"
set "FOUND=0" & set "DATA="
for /f "tokens=3" %%C in ('reg query "%SKEY%" /v "%SVALUE%" 2^>nul ^| findstr /I /C:"%SVALUE%"') do ( set "FOUND=1" & set "DATA=%%C" )
if "!FOUND!"=="1" ( echo set "STATE_%SNAME%=PRESENT">>"!BACKUP_RUN_DIR!\reg_state.cmd" & echo set "DATA_%SNAME%=!DATA!">>"!BACKUP_RUN_DIR!\reg_state.cmd" ) else ( echo set "STATE_%SNAME%=ABSENT">>"!BACKUP_RUN_DIR!\reg_state.cmd" )
exit /b 0

:offerNetworkPrivate
if !BUILD_NUM! LSS 9200 ( echo [i] Win 7: Set-NetConnectionProfile skip. & exit /b 0 )
choice /C YN /N /M "Ubah network aktif ke Private? [Y/N]: "
if errorlevel 2 exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetConnectionProfile ^| Where-Object {$_.NetworkCategory -ne 'DomainAuthenticated'} ^| Set-NetConnectionProfile -NetworkCategory Private" >> "%LOG_FILE%" 2>&1
exit /b 0

:restoreSettings
cls & color 0E & echo ==============================================================================
echo                  RESTORE REGISTRY DARI BACKUP TERAKHIR
echo ==============================================================================
echo.
if not exist "%LATEST_FILE%" ( echo [!] Belum ada backup. & pause & goto mainMenu )
set /p RESTORE_DIR=<"%LATEST_FILE%"
if not exist "!RESTORE_DIR!\reg_state.cmd" ( echo [!] Backup rusak. & pause & goto mainMenu )
call :log "--- Restore started from !RESTORE_DIR! ---"
call "!RESTORE_DIR!\reg_state.cmd"
call :safeStop Spooler
call :restoreDword "RpcAuthnLevelPrivacyEnabled" "HKLM\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled"
call :restoreDword "RpcUseNamedPipeProtocol" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcUseNamedPipeProtocol"
call :restoreDword "RpcProtocols" "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcProtocols"
call :restoreDword "AllowInsecureGuestAuth" "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth"
call :restoreDword "LmCompatibilityLevel" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel"
call :restoreDword "limitblankpassworduse" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "limitblankpassworduse"
call :safeStart Spooler
echo. & echo [+] Restore selesai. & pause & goto mainMenu

:restoreDword
set "STATE=" & call set "STATE=%%STATE_%~1%%"
set "DATA=" & call set "DATA=%%DATA_%~1%%"
if /I "!STATE!"=="PRESENT" ( call :runCmd "Restore %~3=!DATA!" "reg add ^"%~2^" /v %~3 /t REG_DWORD /d !DATA! /f" ) else ( call :runCmd "Delete %~3" "reg delete ^"%~2^" /v %~3 /f" )
exit /b 0

:ensureSpoolFolders
if not exist "%SystemRoot%\System32\spool\PRINTERS" mkdir "%SystemRoot%\System32\spool\PRINTERS" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\SERVERS" mkdir "%SystemRoot%\System32\spool\SERVERS" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\drivers" mkdir "%SystemRoot%\System32\spool\drivers" >nul 2>&1
exit /b 0

:safeStop
sc query "%~1" >nul 2>&1 || exit /b 0
net stop "%~1" /y >> "%LOG_FILE%" 2>&1 && ( call :log "[OK] Stopped %~1" ) || ( set /a WARN_COUNT+=1 & call :log "[WARN] Stop %~1 failed" )
exit /b 0

:safeStart
sc query "%~1" >nul 2>&1 || exit /b 0
net start "%~1" >> "%LOG_FILE%" 2>&1 && ( call :log "[OK] Started %~1" ) || ( set /a WARN_COUNT+=1 & call :log "[WARN] Start %~1 failed" )
exit /b 0

:runCmd
echo     - %~1
call :log "[CMD] %~1"
%~2 >> "%LOG_FILE%" 2>&1
if not !ERRORLEVEL! equ 0 ( set /a WARN_COUNT+=1 & call :log "[WARN] %~1 failed. Code: !ERRORLEVEL!" ) else ( call :log "[OK] %~1" )
exit /b 0

:viewLog
if exist "%LOG_FILE%" ( start "" notepad.exe "%LOG_FILE%" ) else ( echo [!] Log tidak ada. & pause )
goto mainMenu

:quickAccess
cls & echo [QUICK ACCESS]
echo [1] Services ^| [2] Printers ^| [3] Network ^| [4] Print Mgmt ^| [5] Back
set "QA_CHOICE=" & set /p QA_CHOICE="Pilih: "
if "!QA_CHOICE!"=="1" start "" services.msc & goto quickAccess
if "!QA_CHOICE!"=="2" start "" control.exe printers & goto quickAccess
if "!QA_CHOICE!"=="3" start "" control.exe /name Microsoft.NetworkAndSharingCenter & goto quickAccess
if "!QA_CHOICE!"=="4" start "" printmanagement.msc & goto quickAccess
if "!QA_CHOICE!"=="5" goto mainMenu
goto quickAccess

:userGuide
cls & echo [PANDUAN ^& RISIKO]
echo 1. Gunakan Quick Fix dulu. ^| 2. Legacy Fix berisiko turunkan keamanan.
echo 3. Backup dibuat per eksekusi (Timestamped). ^| 4. Win 7 didukung terbatas.
pause & goto mainMenu

:langSettings
cls & echo [LANGUAGE / BAHASA]
echo [1] ID ^| [2] EN ^| [3] Kembali
set "LC=" & set /p LC="Pilih: "
if "!LC!"=="1" ( set "LANG=ID" & echo ID>"%LANG_FILE%" & goto initLang )
if "!LC!"=="2" ( set "LANG=EN" & echo EN>"%LANG_FILE%" & goto initLang )
goto mainMenu

:log
>> "%LOG_FILE%" echo [%DATE% %TIME%] %~1
exit /b 0
