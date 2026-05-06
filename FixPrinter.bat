@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0F
title Windows Printer Sharing Fix Utility
mode con: cols=100 lines=45

:: ==============================================================================
:: Repository: Windows-Printer-Sharing-Fix
:: Description: Automated fix for Windows 7/8/10/11 printer sharing errors
:: Author: Yasman
:: Version: 2.7.0
:: License: MIT
:: ==============================================================================

set "VERSION=2.7.0"
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%printer_fix_log.txt"
set "BACKUP_DIR=%SCRIPT_DIR%backups"
set "LANG_FILE=%SCRIPT_DIR%language.cfg"
set "LANG=EN"

:: Ensure we are in the script's directory
pushd "%SCRIPT_DIR%" >nul 2>&1

:: Load persistent language setting
if exist "%LANG_FILE%" (
    set /p LANG=<"%LANG_FILE%"
)
if /I not "!LANG!"=="ID" set "LANG=EN"

:: Create backup directory
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" >nul 2>&1

:initLang
if /I "!LANG!"=="ID" (
    set "STR_SUBTITLE=Solusi Otomatis untuk Error Sharing Printer (Universal: Win 7-11)"
    set "STR_ADMIN_ERR=ERROR: DIBUTUHKAN AKSES ADMINISTRATOR"
    set "STR_ADMIN_DESC=[!] Script ini harus dijalankan sebagai Administrator."
    set "STR_ADMIN_SOL=Solusi: Klik kanan file ini lalu pilih 'Run as administrator'."
    set "STR_PRESS_KEY=Tekan tombol apa saja untuk keluar..."
    set "STR_MENU_TITLE=UTILITAS PERBAIKAN PRINTER SHARING WINDOWS"
    set "STR_DIAG=DIAGNOSTIK SISTEM"
    set "STR_STATUS=Status Spooler"
    set "STR_RUNNING=BERJALAN"
    set "STR_STOPPED=BERHENTI"
    set "STR_UNKNOWN=TIDAK DIKETAHUI"
    set "STR_MAIN_MENU=MENU UTAMA"
    set "STR_OPT_1=[1] Perbaikan Cepat (Registry Standar ^& Reset Layanan)"
    set "STR_OPT_2=[2] Perbaikan Total (SMBv1 ^& Guest Auth - Hanya untuk Error Bandel)"
    set "STR_OPT_3=[3] Kembalikan Pengaturan dari Backup (Restore)"
    set "STR_OPT_4=[4] Akses Cepat (Services, Printers, Network, Print Management)"
    set "STR_OPT_5=[5] Panduan Pengguna"
    set "STR_OPT_6=[6] Pengaturan Bahasa (Ganti English / Indonesia)"
    set "STR_OPT_7=[7] Lihat Log Eksekusi"
    set "STR_OPT_8=[8] Keluar dari Program"
    set "STR_SELECT=Silakan pilih opsi [1-8]: "
    set "STR_ERR_INPUT=[!] Input tidak valid, silakan coba lagi..."
    set "STR_STARTING=MEMULAI PROSES PERBAIKAN"
    set "STR_BACKUP=Mencadangkan pengaturan registry saat ini..."
    set "STR_STOP_SVC=Menghentikan layanan Spooler dan Jaringan..."
    set "STR_CLEAR_CACHE=Membersihkan Cache Spooler dan Antrian Print..."
    set "STR_APPLY_REG=Menerapkan Perbaikan Registry RPC..."
    set "STR_UP_PERM=Memperbarui Izin Folder Spooler (SID-based)..."
    set "STR_RESTART_SVC=Memulai ulang layanan sistem..."
    set "STR_SUCCESS=EKSEKUSI SELESAI"
    set "STR_REBOOT_REQ=Restart PC dibutuhkan agar semua perubahan aktif."
    set "STR_REBOOT_NOW=Restart PC sekarang? (Y/N): "
    set "STR_BACK=Kembali"
) else (
    set "STR_SUBTITLE=Automated Solution for Printer Sharing Errors (Universal: Win 7-11)"
    set "STR_ADMIN_ERR=ERROR: ADMINISTRATOR PRIVILEGES REQUIRED"
    set "STR_ADMIN_DESC=[!] This script must be run as an Administrator."
    set "STR_ADMIN_SOL=Solution: Right-click this file and select 'Run as administrator'."
    set "STR_PRESS_KEY=Press any key to exit..."
    set "STR_MENU_TITLE=WINDOWS PRINTER SHARING FIX UTILITY"
    set "STR_DIAG=SYSTEM DIAGNOSTICS"
    set "STR_STATUS=Spooler Status"
    set "STR_RUNNING=RUNNING"
    set "STR_STOPPED=STOPPED"
    set "STR_UNKNOWN=UNKNOWN"
    set "STR_MAIN_MENU=MAIN MENU"
    set "STR_OPT_1=[1] Quick Fix (Standard Registry ^& Service Reset)"
    set "STR_OPT_2=[2] Full Fix (Advanced: SMBv1 ^& Guest Auth - For Persistent Errors)"
    set "STR_OPT_3=[3] Restore Settings from Backup"
    set "STR_OPT_4=[4] Quick Access (Services, Printers, Network, Print Management)"
    set "STR_OPT_5=[5] User Guide"
    set "STR_OPT_6=[6] Language Settings (Switch English / Indonesia)"
    set "STR_OPT_7=[7] View Execution Logs"
    set "STR_OPT_8=[8] Exit Utility"
    set "STR_SELECT=Select an option [1-8]: "
    set "STR_ERR_INPUT=[!] Invalid input, please try again..."
    set "STR_STARTING=STARTING REPAIR PROCESS"
    set "STR_BACKUP=Backing up current registry settings..."
    set "STR_STOP_SVC=Stopping Print Spooler and network services..."
    set "STR_CLEAR_CACHE=Clearing spooler cache and print queues..."
    set "STR_APPLY_REG=Applying RPC and printer registry fixes..."
    set "STR_UP_PERM=Updating spooler folder permissions (SID-based)..."
    set "STR_RESTART_SVC=Restarting system services..."
    set "STR_SUCCESS=EXECUTION COMPLETED"
    set "STR_REBOOT_REQ=A restart is recommended to apply all changes."
    set "STR_REBOOT_NOW=Restart PC now? (Y/N): "
    set "STR_BACK=Back"
)

:: --- Check for Administrator Privileges ---
fltmc >nul 2>&1
if errorlevel 1 (
    color 0C & cls & echo.
    echo  ##############################################################################
    echo  #                                                                            #
    echo  #             !STR_ADMIN_ERR!
    echo  #                                                                            #
    echo  ##############################################################################
    echo. & echo  !STR_ADMIN_DESC! & echo  !STR_ADMIN_SOL! & echo.
    echo  !STR_PRESS_KEY! & pause >nul & exit /b 1
)

:: --- Advanced OS Detection ---
set "OS_NAME=Windows"
set "OS_VER=Unknown"
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "OS_VER=%%i.%%j"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| find /I "CurrentBuild"') do set "BUILD=%%A"
if defined BUILD (
    set /a BUILD_NUM=!BUILD! >nul 2>&1
    if !BUILD_NUM! GEQ 22000 ( set "OS_NAME=Windows 11" ) else if !BUILD_NUM! GEQ 10240 ( set "OS_NAME=Windows 10" )
) else (
    if "!OS_VER!"=="6.3" set "OS_NAME=Windows 8.1"
    if "!OS_VER!"=="6.2" set "OS_NAME=Windows 8"
    if "!OS_VER!"=="6.1" set "OS_NAME=Windows 7"
)

:mainMenu
color 0F & cls & echo.
echo  ##############################################################################
echo  #                                                                            #
echo  #             !STR_MENU_TITLE! v!VERSION!
echo  #             !STR_SUBTITLE!
echo  #                                                                            #
echo  ##############################################################################
echo.
echo  [!STR_DIAG!]
echo  - User: %USERNAME%  ^| Lang: !LANG!  ^| OS: !OS_NAME! ^(!OS_VER!^)
echo  - Time: %DATE% %TIME%
call :getServiceStatus Spooler SPOOLER_STATUS
echo  - !STR_STATUS!: !SPOOLER_STATUS!
echo.
echo  ------------------------------------------------------------------------------
echo  [!STR_MAIN_MENU!]
echo  ------------------------------------------------------------------------------
echo  !STR_OPT_1!
echo  !STR_OPT_2!
echo  !STR_OPT_3!
echo  !STR_OPT_4!
echo  !STR_OPT_5!
echo  !STR_OPT_6!
echo  !STR_OPT_7!
echo  !STR_OPT_8!
echo.

set "MENU_CHOICE="
set /p MENU_CHOICE="!STR_SELECT!"

if "!MENU_CHOICE!"=="1" set "FIX_MODE=QUICK" & goto runFix
if "!MENU_CHOICE!"=="2" set "FIX_MODE=FULL" & goto runFix
if "!MENU_CHOICE!"=="3" goto restoreSettings
if "!MENU_CHOICE!"=="4" goto quickAccess
if "!MENU_CHOICE!"=="5" goto userGuide
if "!MENU_CHOICE!"=="6" goto langSettings
if "!MENU_CHOICE!"=="7" goto viewLog
if "!MENU_CHOICE!"=="8" exit /b 0

echo. & echo !STR_ERR_INPUT! & timeout /t 2 >nul & goto mainMenu

:getServiceStatus
set "%~2=!STR_UNKNOWN!"
sc query "%~1" | find /I "RUNNING" >nul 2>&1 && set "%~2=!STR_RUNNING!"
sc query "%~1" | find /I "STOPPED" >nul 2>&1 && set "%~2=!STR_STOPPED!"
exit /b 0

:viewLog
if exist "%LOG_FILE%" ( start "" notepad.exe "%LOG_FILE%" ) else ( echo. & echo [!] Log file not found. & pause )
goto mainMenu

:langSettings
cls & echo.
echo  [LANGUAGE SETTINGS / PENGATURAN BAHASA]
echo  [1] English ^| [2] Bahasa Indonesia ^| [3] !STR_BACK!
set "LANG_CHOICE="
set /p LANG_CHOICE="Select / Pilih: "
if "!LANG_CHOICE!"=="1" ( set "LANG=EN" & echo EN>"%LANG_FILE%" & goto initLang )
if "!LANG_CHOICE!"=="2" ( set "LANG=ID" & echo ID>"%LANG_FILE%" & goto initLang )
if "!LANG_CHOICE!"=="3" goto mainMenu
goto langSettings

:userGuide
cls
if /I "!LANG!"=="ID" (
    echo. & echo  ==============================================================================
    echo                            PANDUAN PENGGUNA (DETIL)
    echo  ==============================================================================
    echo. & echo  1. Klik kanan ^& 'Run as administrator'.
    echo  2. Coba Quick Fix dulu, lalu restart PC.
    echo  3. Pakai Full Fix jika printer model lama/masalah tetap ada.
) else (
    echo. & echo  ==============================================================================
    echo                            USER GUIDE (DETAILED)
    echo  ==============================================================================
    echo. & echo  1. Right-click ^& 'Run as administrator'.
    echo  2. Try Quick Fix first, then restart PC.
    echo  3. Use Full Fix only for legacy printers or persistent issues.
)
echo. & echo  Press any key to return... & pause >nul & goto mainMenu

:quickAccess
cls & echo  [QUICK ACCESS TOOLS]
echo  [1] Services ^| [2] Printers ^| [3] Network ^| [4] Print Mgmt ^| [5] !STR_BACK!
set "QA_CHOICE="
set /p QA_CHOICE="Select: "
if "!QA_CHOICE!"=="1" start "" services.msc & goto quickAccess
if "!QA_CHOICE!"=="2" start "" control.exe printers & goto quickAccess
if "!QA_CHOICE!"=="3" start "" control.exe /name Microsoft.NetworkAndSharingCenter & goto quickAccess
if "!QA_CHOICE!"=="4" start "" printmanagement.msc & goto quickAccess
if "!QA_CHOICE!"=="5" goto mainMenu
goto quickAccess

:runFix
cls & color 0E & echo ==============================================================================
echo                 !STR_STARTING! [!FIX_MODE!]
echo ==============================================================================
echo.
call :log "--- Started Printer Fix [!FIX_MODE!] by Yasman ---"

echo [+] !STR_BACKUP!
call :runCmd "Backup Print registry" "reg export ^"HKLM\System\CurrentControlSet\Control\Print^" ^"%BACKUP_DIR%\print_backup.reg^" /y"
call :runCmd "Backup Providers registry" "reg export ^"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers^" ^"%BACKUP_DIR%\providers_backup.reg^" /y"

echo. & echo [+] !STR_STOP_SVC!
call :safeStop Spooler
call :safeStop LanmanWorkstation
call :safeStop LanmanServer

echo. & echo [+] !STR_CLEAR_CACHE!
call :runCmd "Clear printer queue" "del /Q /F /S ^"%SystemRoot%\System32\spool\PRINTERS\*.*^""
call :runCmd "Clear server cache" "del /Q /F /S ^"%SystemRoot%\System32\spool\SERVERS\*.*^""

echo. & echo [+] !STR_APPLY_REG!
call :runCmd "Remove Client Side Rendering" "reg delete ^"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider^" /f"
call :runCmd "Disable RPC Privacy" "reg add ^"HKLM\System\CurrentControlSet\Control\Print^" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f"
call :runCmd "Use Named Pipe for RPC" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f"
call :runCmd "Allow all RPC protocols" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcProtocols /t REG_DWORD /d 7 /f"

echo. & echo [+] !STR_UP_PERM!
:: Using Well-known SIDs: S-1-5-18 (SYSTEM), S-1-5-32-544 (Administrators), S-1-1-0 (Everyone)
call :runCmd "Grant SYSTEM access" "icacls ^"%SystemRoot%\System32\spool\PRINTERS^" /grant *S-1-5-18:^(OI^)^(CI^)F /T /C /Q"
call :runCmd "Grant Administrators access" "icacls ^"%SystemRoot%\System32\spool\PRINTERS^" /grant *S-1-5-32-544:^(OI^)^(CI^)F /T /C /Q"
call :runCmd "Grant Everyone access" "icacls ^"%SystemRoot%\System32\spool\drivers^" /grant *S-1-1-0:^(OI^)^(CI^)M /T /C /Q"

echo.
if "!OS_VER!"=="6.1" ( echo [i] Skipping network profile on Win 7. ) else (
    echo [+] Setting Network Profile to Private...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetConnectionProfile ^| Where-Object {$_.NetworkCategory -ne 'DomainAuthenticated'} ^| Set-NetConnectionProfile -NetworkCategory Private" >> "%LOG_FILE%" 2>&1
)

if /I "!FIX_MODE!"=="FULL" (
    echo. & echo [+] [FULL] Enabling SMBv1 ^& Guest Auth...
    call :runCmd "Enable SMBv1" "dism /online /Enable-Feature /FeatureName:SMB1Protocol -All /NoRestart /quiet"
    call :runCmd "Allow Guest Auth" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters^" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f"
    call :runCmd "Set LSA Compatibility" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f"
    call :runCmd "Allow Blank Passwords" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v limitblankpassworduse /t REG_DWORD /d 0 /f"
)

:finalize
echo. & echo [+] !STR_RESTART_SVC!
call :safeStart LanmanServer
call :safeStart LanmanWorkstation
call :safeStart Spooler
call :runCmd "Set fdPHost auto" "sc config fdPHost start= auto"
call :runCmd "Set FDResPub auto" "sc config FDResPub start= auto"
call :safeStart fdPHost
call :safeStart FDResPub

echo. & color 0A & echo ==============================================================================
echo                      !STR_SUCCESS!
echo ==============================================================================
echo !STR_REBOOT_REQ! & echo.
set "REBOOT=" & set /p REBOOT="!STR_REBOOT_NOW!"
if /I "!REBOOT!"=="Y" (
    echo. & echo Restarting in 10 seconds... & shutdown /r /t 10 /c "Printer Fix Applied by Yasman." & exit /b 0
) else ( echo. & echo [!] Please restart manually later. & pause >nul & goto mainMenu )

:safeStop
sc query "%~1" >nul 2>&1 || ( call :log "[SKIP] Service %~1 not found" & exit /b 0 )
net stop "%~1" /y >> "%LOG_FILE%" 2>&1 && ( call :log "[OK] Stopped %~1" ) || ( call :log "[WARN] Stop %~1 failed" )
exit /b 0

:safeStart
sc query "%~1" >nul 2>&1 || ( call :log "[SKIP] Service %~1 not found" & exit /b 0 )
net start "%~1" >> "%LOG_FILE%" 2>&1 && ( call :log "[OK] Started %~1" ) || ( call :log "[WARN] Start %~1 failed" )
exit /b 0

:restoreSettings
cls & echo ==============================================================================
echo                        RESTORE SETTINGS FROM BACKUP
echo ==============================================================================
echo.
if not exist "%BACKUP_DIR%\print_backup.reg" ( echo [!] Backup not found. & pause & goto mainMenu )
call :runCmd "Restore Print" "reg import ^"%BACKUP_DIR%\print_backup.reg^""
call :runCmd "Restore Providers" "reg import ^"%BACKUP_DIR%\providers_backup.reg^""
echo. & echo [+] Restore complete. Please restart. & pause & goto mainMenu

:runCmd
set "DESC=%~1" & set "CMDLINE=%~2"
echo     - !DESC!
call :log "[CMD] !DESC!"
!CMDLINE! >> "%LOG_FILE%" 2>&1
if not !ERRORLEVEL! equ 0 (
    echo       [!] Failed/skipped. Code: !ERRORLEVEL!
    call :log "[WARN] !DESC! failed. Code: !ERRORLEVEL!"
) else ( call :log "[OK] !DESC!" )
exit /b 0

:log
set "MSG=%~1"
>> "%LOG_FILE%" echo [%DATE% %TIME%] !MSG!
exit /b 0
