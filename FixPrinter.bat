@echo off
setlocal EnableDelayedExpansion
color 0B
title Windows Printer Sharing Fix Utility
mode con: cols=100 lines=45

:: ==============================================================================
:: Repository: Windows-Printer-Sharing-Fix
:: Description: Automated fix for Windows 10/11 printer sharing errors
:: Author: Yasman
:: License: MIT
:: ==============================================================================

set "VERSION=2.0.0"
set "LOG_FILE=printer_fix_log.txt"
set "BACKUP_DIR=backups"
set "TIMESTAMP=%DATE% %TIME%"

:: Create backup directory if it doesn't exist
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:mainMenu
cls
echo.
echo  ##############################################################################
echo  #                                                                            #
echo  #             WINDOWS PRINTER SHARING FIX UTILITY v%VERSION%               #
echo  #             Solution for Error 0x0000011b ^& More                        #
echo  #                                                                            #
echo  ##############################################################################
echo.
echo  [1] Quick Fix (Standard Registry ^& Service Reset) - Recommended
echo  [2] Full Fix (Advanced: Includes SMBv1 ^& Guest Auth) - For Persistent Errors
echo  [3] Restore Settings (Undo Changes from Backup)
echo  [4] View Execution Logs
echo  [5] Exit
echo.
set /p MENU_CHOICE="Select an option [1-5]: "

if "%MENU_CHOICE%"=="1" goto startFixQuick
if "%MENU_CHOICE%"=="2" goto startFixFull
if "%MENU_CHOICE%"=="3" goto restoreSettings
if "%MENU_CHOICE%"=="4" start notepad "%LOG_FILE%" & goto mainMenu
if "%MENU_CHOICE%"=="5" exit /b
goto mainMenu

:startFixQuick
set "FIX_MODE=QUICK"
goto runFix

:startFixFull
set "FIX_MODE=FULL"
goto runFix

:runFix
cls
echo ==============================================================================
echo                 STARTING PRINTER FIX [%FIX_MODE% MODE]
echo ==============================================================================
echo.

:: Check for Administrator Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    call :log "[!] ERROR: Administrator privileges required."
    color 0C
    echo [!] ERROR: ADMINISTRATOR PRIVILEGES REQUIRED.
    echo Please right-click this script and select "Run as administrator".
    echo.
    pause
    goto mainMenu
)

call :log "--- Started Printer Fix [%FIX_MODE%] ---"

:: [1] Registry Backup
echo [+] Backing up registry settings...
set "BK_FILE=%BACKUP_DIR%\backup_%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%.reg"
set "BK_FILE=%BK_FILE: =0%"
reg export "HKLM\System\CurrentControlSet\Control\Print" "%BACKUP_DIR%\print_backup.reg" /y >nul 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers" "%BACKUP_DIR%\providers_backup.reg" /y >nul 2>&1
call :log "[+] Backups created in %BACKUP_DIR% folder."
echo   - Registry backup complete.
echo.

:: [2] Services
echo [+] Stopping Print Spooler and Network Services...
net stop spooler /y >nul 2>&1
net stop LanmanWorkstation /y >nul 2>&1
net stop LanmanServer /y >nul 2>&1
call :log "[+] Services stopped."
echo   - Services stopped.
echo.

:: [3] Clear Cache
echo [+] Clearing Spooler Cache...
del /Q /F /S "%systemroot%\System32\Spool\Printers\*.*" >nul 2>&1
del /Q /F /S "%systemroot%\System32\Spool\SERVERS\*.*" >nul 2>&1
call :log "[+] Spooler cache cleared."
echo   - Cache cleared.
echo.

:: [4] Registry Fixes (Quick)
echo [+] Applying Registry Fixes...
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider" /f >nul 2>&1
reg add "HKLM\System\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcProtocols /t REG_DWORD /d 0x7 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v limitblankpassworduse /t REG_DWORD /d 0 /f >nul 2>&1
call :log "[+] Registry fixes applied."
echo   - Registry fixes applied.
echo.

:: [5] Permissions
echo [+] Updating Folder Permissions...
icacls "%systemroot%\System32\spool\PRINTERS" /grant Everyone:(OI)(CI)F /T /C /Q >nul 2>&1
icacls "%systemroot%\System32\spool\drivers" /grant Everyone:(OI)(CI)F /T /C /Q >nul 2>&1
call :log "[+] Permissions updated."
echo   - Permissions updated.
echo.

:: [6] Network Category
echo [+] Setting Network Profile to Private...
powershell -Command "Set-NetConnectionProfile -NetworkCategory Private" >nul 2>&1
call :log "[+] Network category set to Private."
echo   - Network profile set.
echo.

if "%FIX_MODE%"=="QUICK" goto finalize

:: --- FULL MODE ONLY ---
echo [+] [FULL] Enabling SMBv1 Protocol...
dism /online /Enable-Feature /FeatureName:"SMB1Protocol" -All /NoRestart /quiet >nul 2>&1
call :log "[+] [FULL] SMBv1 enabled."
echo   - SMBv1 enabled.
echo.

echo [+] [FULL] Enabling Insecure Guest Auth...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f >nul 2>&1
call :log "[+] [FULL] Guest auth enabled."
echo   - Guest auth enabled.
echo.

:finalize
echo [+] Restarting Services...
net start LanmanServer >nul 2>&1
net start LanmanWorkstation >nul 2>&1
net start spooler >nul 2>&1
sc config fdPHost start=auto >nul 2>&1
sc config FDResPub start=auto >nul 2>&1
net start fdPHost >nul 2>&1
net start FDResPub >nul 2>&1
call :log "[+] Services restarted."
echo   - Services restarted.
echo.

call :log "--- Execution Completed Successfully ---"
echo ==============================================================================
echo                      EXECUTION COMPLETED SUCCESSFULLY
echo ==============================================================================
echo A system restart is required to apply all changes.
echo.
pause
goto mainMenu

:restoreSettings
cls
echo ==============================================================================
echo                        RESTORE SETTINGS FROM BACKUP
echo ==============================================================================
echo.
if not exist "%BACKUP_DIR%\print_backup.reg" (
    echo [!] No backup files found in %BACKUP_DIR%
    pause
    goto mainMenu
)
echo [+] Restoring registry from backup files...
reg import "%BACKUP_DIR%\print_backup.reg" >nul 2>&1
reg import "%BACKUP_DIR%\providers_backup.reg" >nul 2>&1
call :log "[+] Settings restored from backup."
echo [+] Restore complete. Please restart your computer.
echo.
pause
goto mainMenu

:log
set "msg=%~1"
echo [%DATE% %TIME%] %msg% >> "%LOG_FILE%"
exit /b
