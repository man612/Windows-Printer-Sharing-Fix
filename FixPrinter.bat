@echo off
setlocal EnableDelayedExpansion
color 0F
title Windows Printer Sharing Fix Utility
mode con: cols=100 lines=45

:: ==============================================================================
:: Repository: Windows-Printer-Sharing-Fix
:: Description: Automated fix for Windows 7/8/10/11 printer sharing errors
:: Author: Yasman
:: Version: 2.5.0
:: License: MIT
:: ==============================================================================

set "VERSION=2.5.0"
set "LOG_FILE=printer_fix_log.txt"
set "BACKUP_DIR=backups"
set "LANG=EN"

:: Create backup directory if it doesn't exist
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:initLang
if "%LANG%"=="ID" (
    set "STR_SUBTITLE=Solusi Otomatis untuk Error Sharing Printer (Universal: Win 7-11)"
    set "STR_ADMIN_ERR=ERROR: DIBUTUHKAN AKSES ADMINISTRATOR"
    set "STR_ADMIN_DESC=[!] Script ini harus dijalankan sebagai Administrator."
    set "STR_ADMIN_SOL=Solusi: Klik kanan file ini dan pilih 'Run as administrator'."
    set "STR_PRESS_KEY=Tekan tombol apa saja untuk keluar..."
    set "STR_MENU_TITLE=UTILITAS PERBAIKAN PRINTER SHARING WINDOWS"
    set "STR_DIAG=DIAGNOSTIK SISTEM"
    set "STR_STATUS=Status Spooler"
    set "STR_RUNNING=BERJALAN"
    set "STR_STOPPED=BERHENTI"
    set "STR_MAIN_MENU=MENU UTAMA"
    set "STR_OPT_1=[1] Perbaikan Cepat (Standar Registry ^& Reset Layanan) - Disarankan"
    set "STR_OPT_2=[2] Perbaikan Total (Lengkap: SMBv1 ^& Guest Auth) - Untuk Error Bandel"
    set "STR_OPT_3=[3] Kembalikan Pengaturan (Undo Semua Perubahan dari Backup)"
    set "STR_OPT_4=[4] Akses Cepat (Buka Services, Control Printers, dll)"
    set "STR_OPT_5=[5] Panduan Pengguna (Instruksi Penggunaan Detil)"
    set "STR_OPT_6=[6] Pengaturan Bahasa (Ganti English / Indonesia)"
    set "STR_OPT_7=[7] Lihat Log Eksekusi (Riwayat Perbaikan)"
    set "STR_OPT_8=[8] Keluar dari Program"
    set "STR_SELECT=Silakan pilih opsi [1-8]: "
    set "STR_ERR_INPUT=[!] Input tidak valid, silakan coba lagi..."
    set "STR_STARTING=MEMULAI PROSES PERBAIKAN"
    set "STR_BACKUP=Mencadangkan pengaturan registry saat ini..."
    set "STR_STOP_SVC=Menghentikan layanan Spooler dan Jaringan..."
    set "STR_CLEAR_CACHE=Membersihkan Cache Spooler dan Antrian Print..."
    set "STR_APPLY_REG=Menerapkan Perbaikan Registry (RPC ^& Named Pipes)..."
    set "STR_UP_PERM=Memperbarui Izin Folder Spooler..."
    set "STR_RESTART_SVC=Memulai ulang layanan sistem..."
    set "STR_SUCCESS=EKSEKUSI SELESAI DENGAN SUKSES"
    set "STR_REBOOT_REQ=Restart PC dibutuhkan agar semua perubahan aktif."
    set "STR_REBOOT_NOW=Restart PC sekarang? (Y/N): "
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
    set "STR_MAIN_MENU=MAIN MENU"
    set "STR_OPT_1=[1] Quick Fix (Standard Registry ^& Service Reset) - Recommended"
    set "STR_OPT_2=[2] Full Fix (Advanced: SMBv1 ^& Guest Auth) - For Persistent Errors"
    set "STR_OPT_3=[3] Restore Settings (Undo All Changes from Backup)"
    set "STR_OPT_4=[4] Quick Access (Open Services, Printers, or Network)"
    set "STR_OPT_5=[5] User Guide (Detailed Instructions ^& Troubleshooting)"
    set "STR_OPT_6=[6] Language Settings (Switch English / Indonesia)"
    set "STR_OPT_7=[7] View Execution Logs (History)"
    set "STR_OPT_8=[8] Exit Utility"
    set "STR_SELECT=Select an option [1-8]: "
    set "STR_ERR_INPUT=[!] Invalid input, please try again..."
    set "STR_STARTING=STARTING REPAIR PROCESS"
    set "STR_BACKUP=Backing up current registry settings..."
    set "STR_STOP_SVC=Stopping Print Spooler and Network Services..."
    set "STR_CLEAR_CACHE=Clearing Spooler Cache and Print Queues..."
    set "STR_APPLY_REG=Applying Registry Fixes (RPC ^& Named Pipes)..."
    set "STR_UP_PERM=Updating Spooler Folder Permissions..."
    set "STR_RESTART_SVC=Restarting system services..."
    set "STR_SUCCESS=EXECUTION COMPLETED SUCCESSFULLY"
    set "STR_REBOOT_REQ=A system restart is required to apply all changes."
    set "STR_REBOOT_NOW=Restart PC now? (Y/N): "
)

:: --- Check for Administrator Privileges ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    color 0C & cls & echo.
    echo  ##############################################################################
    echo  #                                                                            #
    echo  #             %STR_ADMIN_ERR%                     #
    echo  #                                                                            #
    echo  ##############################################################################
    echo. & echo  %STR_ADMIN_DESC% & echo  %STR_ADMIN_SOL% & echo.
    echo  %STR_PRESS_KEY% & pause >nul & exit /b
)

:: --- OS Detection ---
set "OS_NAME=Windows"
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "OS_VER=%%i.%%j"
if "%OS_VER%"=="10.0" set "OS_NAME=Windows 10/11"
if "%OS_VER%"=="6.3" set "OS_NAME=Windows 8.1"
if "%OS_VER%"=="6.2" set "OS_NAME=Windows 8"
if "%OS_VER%"=="6.1" set "OS_NAME=Windows 7"

:mainMenu
color 0F & cls & echo.
echo  ##############################################################################
echo  #                                                                            #
echo  #             %STR_MENU_TITLE% v%VERSION%               #
echo  #             %STR_SUBTITLE%               #
echo  #                                                                            #
echo  ##############################################################################
echo.
echo  [%STR_DIAG%]
echo  - User: %USERNAME% ^| Lang: %LANG% ^| OS: %OS_NAME% (%OS_VER%)
echo  - Time: %DATE% %TIME%
net start | find "Print Spooler" >nul && (echo  - %STR_STATUS%: %STR_RUNNING%) || (echo  - %STR_STATUS%: %STR_STOPPED%)
echo.
echo  ------------------------------------------------------------------------------
echo  [%STR_MAIN_MENU%]
echo  ------------------------------------------------------------------------------
echo  %STR_OPT_1% & echo  %STR_OPT_2% & echo  %STR_OPT_3% & echo  %STR_OPT_4%
echo  %STR_OPT_5% & echo  %STR_OPT_6% & echo  %STR_OPT_7% & echo  %STR_OPT_8%
echo.

set "MENU_CHOICE="
set /p MENU_CHOICE="%STR_SELECT%"

if "%MENU_CHOICE%"=="1" set "FIX_MODE=QUICK" & goto runFix
if "%MENU_CHOICE%"=="2" set "FIX_MODE=FULL" & goto runFix
if "%MENU_CHOICE%"=="3" goto restoreSettings
if "%MENU_CHOICE%"=="4" goto quickAccess
if "%MENU_CHOICE%"=="5" goto userGuide
if "%MENU_CHOICE%"=="6" goto langSettings
if "%MENU_CHOICE%"=="7" goto viewLog
if "%MENU_CHOICE%"=="8" exit /b

echo. & echo %STR_ERR_INPUT% & timeout /t 2 >nul & goto mainMenu

:viewLog
if exist "%LOG_FILE%" ( start notepad.exe "%LOG_FILE%" ) else ( echo. & echo [!] Log file not found yet. & pause )
goto mainMenu

:langSettings
cls & echo.
echo  [LANGUAGE SETTINGS / PENGATURAN BAHASA]
echo  [1] English (Current: %LANG%) ^| [2] Bahasa Indonesia ^| [3] Back
set "LANG_CHOICE="
set /p LANG_CHOICE="Select / Pilih: "
if "%LANG_CHOICE%"=="1" set "LANG=EN" & goto initLang
if "%LANG_CHOICE%"=="2" set "LANG=ID" & goto initLang
if "%LANG_CHOICE%"=="3" goto mainMenu
goto langSettings

:userGuide
cls
if "%LANG%"=="ID" (
    echo. & echo  ==============================================================================
    echo                            PANDUAN PENGGUNA (DETIL)
    echo  ==============================================================================
    echo. & echo  1. QUICK FIX ^| 2. FULL FIX ^| 3. RESTORE ^| 4. RESTART
) else (
    echo. & echo  ==============================================================================
    echo                            USER GUIDE (DETAILED)
    echo  ==============================================================================
    echo. & echo  1. QUICK FIX ^| 2. FULL FIX ^| 3. RESTORE ^| 4. RESTART
)
echo  Press any key to return to menu... & pause >nul & goto mainMenu

:quickAccess
cls & echo  [QUICK ACCESS TOOLS]
echo  [1] Services ^| [2] Printers ^| [3] Network ^| [4] Print Mgmt ^| [5] Back
set "QA_CHOICE="
set /p QA_CHOICE="Select: "
if "%QA_CHOICE%"=="1" start services.msc & goto quickAccess
if "%QA_CHOICE%"=="2" start control.exe printers & goto quickAccess
if "%QA_CHOICE%"=="3" start control.exe /name Microsoft.NetworkAndSharingCenter & goto quickAccess
if "%QA_CHOICE%"=="4" start printmanagement.msc & goto quickAccess
if "%QA_CHOICE%"=="5" goto mainMenu
goto quickAccess

:runFix
cls & color 0E & echo ==============================================================================
echo                 %STR_STARTING% [%FIX_MODE%]
echo ==============================================================================
echo.
call :log "--- Started Printer Fix [%FIX_MODE%] by Yasman ---"
echo [+] %STR_BACKUP%
reg export "HKLM\System\CurrentControlSet\Control\Print" "%BACKUP_DIR%\print_backup.reg" /y >nul 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers" "%BACKUP_DIR%\providers_backup.reg" /y >nul 2>&1
echo. & echo [+] %STR_STOP_SVC%
net stop spooler /y >nul 2>&1 & net stop LanmanWorkstation /y >nul 2>&1 & net stop LanmanServer /y >nul 2>&1
echo. & echo [+] %STR_CLEAR_CACHE%
del /Q /F /S "%systemroot%\System32\Spool\Printers\*.*" >nul 2>&1
del /Q /F /S "%systemroot%\System32\Spool\SERVERS\*.*" >nul 2>&1
echo. & echo [+] %STR_APPLY_REG%
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider" /f >nul 2>&1
reg add "HKLM\System\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcProtocols /t REG_DWORD /d 0x7 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v limitblankpassworduse /t REG_DWORD /d 0 /f >nul 2>&1
echo. & echo [+] %STR_UP_PERM%
icacls "%systemroot%\System32\spool\PRINTERS" /grant Everyone:(OI)(CI)F /T /C /Q >nul 2>&1
icacls "%systemroot%\System32\spool\drivers" /grant Everyone:(OI)(CI)F /T /C /Q >nul 2>&1
echo.
if "%OS_VER%"=="6.1" ( echo [i] Skipping Windows 10 specific network commands... ) else (
    echo [+] Setting Network Category to Private...
    powershell -Command "Set-NetConnectionProfile -NetworkCategory Private" >nul 2>&1
)
if "%FIX_MODE%"=="FULL" (
    echo. & echo [+] [FULL] Enabling SMBv1 ^& Guest Auth...
    dism /online /Enable-Feature /FeatureName:"SMB1Protocol" -All /NoRestart /quiet >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f >nul 2>&1
)
:finalize
echo. & echo [+] %STR_RESTART_SVC%
net start LanmanServer >nul 2>&1 & net start LanmanWorkstation >nul 2>&1 & net start spooler >nul 2>&1
sc config fdPHost start=auto >nul 2>&1 & sc config FDResPub start=auto >nul 2>&1
net start fdPHost >nul 2>&1 & net start FDResPub >nul 2>&1
echo. & color 0A & echo ==============================================================================
echo                      %STR_SUCCESS%
echo ==============================================================================
echo %STR_REBOOT_REQ% & echo.
set "REBOOT=" & set /p REBOOT="%STR_REBOOT_NOW%"
if /i "%REBOOT%"=="Y" (
    echo. & echo Restarting in 10 seconds. Press CTRL+C to abort... & shutdown /r /t 10 /c "Printer Fix Applied by Yasman." & exit /b
) else ( echo. & echo [!] Please restart manually later. & pause >nul & goto mainMenu )

:restoreSettings
cls & echo ==============================================================================
echo                        RESTORE SETTINGS FROM BACKUP
echo ==============================================================================
echo.
if not exist "%BACKUP_DIR%\print_backup.reg" ( echo [!] Backup not found. & pause & goto mainMenu )
if not exist "%BACKUP_DIR%\providers_backup.reg" ( echo [!] Backup not found. & pause & goto mainMenu )
reg import "%BACKUP_DIR%\print_backup.reg" >nul 2>&1 & reg import "%BACKUP_DIR%\providers_backup.reg" >nul 2>&1
echo [+] Restore complete. Please restart. & pause & goto mainMenu

:log
set "msg=%~1" & echo [%DATE% %TIME%] %msg% >> "%LOG_FILE%" & exit /b
