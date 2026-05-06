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
set "LANG=EN"
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
set "FIX_MODE="
set "BACKUP_RUN_DIR="
set "OS_NAME=Windows"
set "OS_VER=Unknown"
set "BUILD_NUM=0"

pushd "%SCRIPT_DIR%" >nul 2>&1 || (
    echo [FATAL] Failed to enter the script folder.
    pause
    exit /b 1
)

if not exist "%BACKUP_ROOT%" (
    mkdir "%BACKUP_ROOT%" >nul 2>&1 || (
        echo [FATAL] Failed to create backup folder: "%BACKUP_ROOT%"
        pause
        exit /b 1
    )
)

>> "%LOG_FILE%" echo. 2>nul || (
    echo [FATAL] Failed to write the log file in the script folder.
    echo Move this .bat file to Desktop, then run it again as Administrator.
    pause
    exit /b 1
)

call :loadLanguage
call :initLang
call :requireAdmin
if errorlevel 1 exit /b 1
goto :detectOS

:loadLanguage
set "LANG=EN"
if exist "%LANG_FILE%" (
    for /f "usebackq tokens=1 delims= " %%L in ("%LANG_FILE%") do set "LANG=%%~L"
)
call :normalizeLanguage
exit /b 0

:normalizeLanguage
if /I "!LANG!"=="ID" exit /b 0
set "LANG=EN"
exit /b 0

:saveLanguage
set "LANG=%~1"
call :normalizeLanguage
> "%LANG_FILE%" echo !LANG!
if errorlevel 1 (
    echo [WARN] Failed to save language setting: "%LANG_FILE%"
    echo [WARN] The language was changed for this session only.
    pause
)
call :initLang
exit /b 0

:initLang
if /I "!LANG!"=="EN" (
    set "STR_TITLE=WINDOWS PRINTER SHARING FIX UTILITY"
    set "STR_SUBTITLE=Final audited build for Windows 7/8/8.1/10/11"
    set "STR_ADMIN_ERR=ERROR: ADMINISTRATOR PRIVILEGES REQUIRED"
    set "STR_ADMIN_DESC=This script is not running as Administrator."
    set "STR_ADMIN_SOL=Requesting Windows UAC elevation automatically..."
    set "STR_PRESS_KEY=Press any key to exit..."
    set "STR_STATUS=Spooler Status"
    set "STR_RUNNING=RUNNING"
    set "STR_STOPPED=STOPPED"
    set "STR_UNKNOWN=UNKNOWN"
    set "STR_NOT_FOUND=NOT FOUND"
    set "STR_SELECT=Select option [1-8]: "
    set "STR_BAD_INPUT=[WARN] Invalid input."
    set "STR_DIAG=DIAGNOSTICS"
    set "STR_MENU=MENU"
    set "STR_LANGUAGE_LABEL=Language"
    set "STR_TIME_LABEL=Time"
    set "STR_MENU_1=[1] Quick Fix - spooler, cache, printer RPC, Point and Print, firewall sharing"
    set "STR_MENU_2=[2] Classic/Full Fix - Quick Fix + SMBv1 + Guest Auth + blank-password [RISK]"
    set "STR_MENU_3=[3] Restore registry from latest backup"
    set "STR_MENU_4=[4] Quick Access - Services, Printers, Network, Print Management"
    set "STR_MENU_5=[5] Guide and risk notes"
    set "STR_MENU_6=[6] Change Language"
    set "STR_MENU_7=[7] View Log"
    set "STR_MENU_8=[8] Exit"
    set "STR_LANG_TITLE=LANGUAGE"
    set "STR_LANG_1=[1] English (EN)"
    set "STR_LANG_2=[2] Indonesian (ID)"
    set "STR_LANG_3=[3] Back"
    set "STR_LANG_SELECT=Select language [1-3]: "
    set "STR_LOG_TITLE=LOG VIEWER"
    set "STR_LOG_FILE=Log file"
    set "STR_LOG_MISSING=[WARN] Log file does not exist yet."
    set "STR_LOG_EMPTY=[INFO] Log has no entries yet."
    set "STR_BACK=Back"
    set "STR_SELECT_SHORT=Select"
    set "STR_ELEVATE_FAIL=[FATAL] Failed to request Administrator access automatically."
    set "STR_ELEVATE_SOL=Right-click this file and choose Run as administrator."
    set "STR_PROCESS_START=STARTING PROCESS"
    set "STR_BACKUP_FATAL=[FATAL] Backup creation failed. The process was aborted for safety."
    set "STR_PREP_SERVICES=[+] Preparing printer and sharing services..."
    set "STR_CLEAR_CACHE=[+] Clearing printer cache/queue..."
    set "STR_APPLY_RPC=[+] Applying printer RPC compatibility registry settings..."
    set "STR_APPLY_POINT=[+] Opening Point and Print restrictions from the early version..."
    set "STR_FIX_PERMS=[+] Repairing spooler folder permissions conservatively..."
    set "STR_ENABLE_FW=[+] Enabling Windows Firewall File and Printer Sharing rules..."
    set "STR_APPLY_LEGACY=[+] Applying CLASSIC/FULL compatibility fix..."
    set "STR_SMB_SKIP=    - Enable SMBv1 feature: skipped for Windows 7/legacy"
    set "STR_RESTART_SERVICES=[+] Restarting services..."
    set "STR_VERIFY_FINAL=[+] Final verification..."
    set "STR_DONE_FAIL_A=COMPLETED, BUT THERE ARE"
    set "STR_DONE_FAIL_B=CRITICAL ISSUE(S) AND"
    set "STR_DONE_FAIL_C=WARNING(S)."
    set "STR_DONE_FAIL_HINT=Open the log for details. Do not treat the fix as successful until FAIL items are resolved."
    set "STR_DONE_WARN_A=COMPLETED, BUT THERE ARE"
    set "STR_DONE_WARN_B=WARNING(S). Open the log for details."
    set "STR_DONE_OK=COMPLETED WITH NO WARNING/FAIL DETECTED BY THIS SCRIPT."
    set "STR_RESTART_ADVICE=Restarting the PC is strongly recommended so registry, sharing, and services reload fully."
    set "STR_RESTART_PROMPT=Restart now? [Y/N]: "
    set "STR_RESTART_MANUAL=Please restart manually."
    set "STR_RESTORE_TITLE=RESTORE REGISTRY FROM LATEST BACKUP"
    set "STR_NO_BACKUP=[WARN] No backup exists yet."
    set "STR_BACKUP_BROKEN=[WARN] Backup is damaged or incomplete."
    set "STR_RESTORE_DONE_FAIL_A=[WARN] Restore completed, but there are"
    set "STR_RESTORE_DONE_FAIL_B=critical issue(s) and"
    set "STR_RESTORE_DONE_FAIL_C=warning(s). Check the log."
    set "STR_RESTORE_DONE_WARN_A=[WARN] Restore completed with"
    set "STR_RESTORE_DONE_WARN_B=warning(s). Check the log."
    set "STR_RESTORE_DONE_OK=[+] Restore completed with no detected warnings."
    set "STR_RESTART_RECOMMENDED=PC restart is recommended."
    set "STR_ALREADY_ABSENT=already absent"
    set "STR_SPOOL_CREATE_FAIL=Spool PRINTERS folder could not be created."
    set "STR_FIREWALL_ENABLED=    - Firewall File and Printer Sharing enabled"
    set "STR_FIREWALL_FAILED=    - Firewall File and Printer Sharing failed"
    set "STR_NET_PRIVATE_SKIP=[i] Windows 7/legacy: Set-NetConnectionProfile skipped."
    set "STR_NET_PRIVATE_PROMPT=Set active network profile to Private? [Y/N]: "
    set "STR_VERIFY_MISMATCH=not matched"
    set "STR_ACTUAL=actual"
    set "STR_TARGET=target"
    set "STR_QUICK_ACCESS_TITLE=QUICK ACCESS"
) else (
    set "STR_TITLE=UTILITAS PERBAIKAN SHARING PRINTER WINDOWS"
    set "STR_SUBTITLE=Build audit final untuk Windows 7/8/8.1/10/11"
    set "STR_ADMIN_ERR=ERROR: BUTUH AKSES ADMINISTRATOR"
    set "STR_ADMIN_DESC=Script ini belum berjalan sebagai Administrator."
    set "STR_ADMIN_SOL=Mencoba meminta akses Administrator lewat UAC otomatis..."
    set "STR_PRESS_KEY=Tekan tombol apa saja untuk keluar..."
    set "STR_STATUS=Status Spooler"
    set "STR_RUNNING=BERJALAN"
    set "STR_STOPPED=BERHENTI"
    set "STR_UNKNOWN=TIDAK DIKETAHUI"
    set "STR_NOT_FOUND=TIDAK ADA"
    set "STR_SELECT=Pilih opsi [1-8]: "
    set "STR_BAD_INPUT=[WARN] Input tidak valid."
    set "STR_DIAG=DIAGNOSTIK"
    set "STR_MENU=MENU"
    set "STR_LANGUAGE_LABEL=Bahasa"
    set "STR_TIME_LABEL=Waktu"
    set "STR_MENU_1=[1] Quick Fix - spooler, cache, RPC printer, Point and Print, firewall sharing"
    set "STR_MENU_2=[2] Classic/Full Fix - Quick Fix + SMBv1 + Guest Auth + blank-password [RISIKO]"
    set "STR_MENU_3=[3] Restore Registry dari backup terakhir"
    set "STR_MENU_4=[4] Akses Cepat - Services, Printers, Network, Print Management"
    set "STR_MENU_5=[5] Panduan dan catatan risiko"
    set "STR_MENU_6=[6] Ganti Bahasa / Language"
    set "STR_MENU_7=[7] Lihat Log"
    set "STR_MENU_8=[8] Keluar"
    set "STR_LANG_TITLE=LANGUAGE / BAHASA"
    set "STR_LANG_1=[1] English (EN)"
    set "STR_LANG_2=[2] Indonesian (ID)"
    set "STR_LANG_3=[3] Kembali"
    set "STR_LANG_SELECT=Pilih bahasa [1-3]: "
    set "STR_LOG_TITLE=LIHAT LOG"
    set "STR_LOG_FILE=File log"
    set "STR_LOG_MISSING=[WARN] Log belum ada."
    set "STR_LOG_EMPTY=[INFO] Log belum berisi catatan."
    set "STR_BACK=Kembali"
    set "STR_SELECT_SHORT=Pilih"
    set "STR_ELEVATE_FAIL=[FATAL] Gagal meminta akses Administrator otomatis."
    set "STR_ELEVATE_SOL=Klik kanan file ini lalu pilih Run as administrator."
    set "STR_PROCESS_START=MEMULAI PROSES"
    set "STR_BACKUP_FATAL=[FATAL] Backup gagal dibuat. Proses dibatalkan agar aman."
    set "STR_PREP_SERVICES=[+] Menyiapkan service printer dan sharing..."
    set "STR_CLEAR_CACHE=[+] Membersihkan cache/antrian printer..."
    set "STR_APPLY_RPC=[+] Menerapkan registry printer RPC compatibility..."
    set "STR_APPLY_POINT=[+] Membuka batasan Point and Print seperti versi awal..."
    set "STR_FIX_PERMS=[+] Memperbaiki izin folder spooler secara konservatif..."
    set "STR_ENABLE_FW=[+] Mengaktifkan firewall rule File and Printer Sharing..."
    set "STR_APPLY_LEGACY=[+] Menerapkan LEGACY/FULL compatibility fix..."
    set "STR_SMB_SKIP=    - Enable SMBv1 feature: dilewati untuk Windows 7/legacy"
    set "STR_RESTART_SERVICES=[+] Menyalakan ulang service..."
    set "STR_VERIFY_FINAL=[+] Verifikasi akhir..."
    set "STR_DONE_FAIL_A=SELESAI, TAPI ADA"
    set "STR_DONE_FAIL_B=MASALAH PENTING DAN"
    set "STR_DONE_FAIL_C=WARNING."
    set "STR_DONE_FAIL_HINT=Buka log untuk detail. Jangan anggap fix sukses sebelum FAIL diselesaikan."
    set "STR_DONE_WARN_A=SELESAI, TAPI ADA"
    set "STR_DONE_WARN_B=WARNING. Buka log untuk detail."
    set "STR_DONE_OK=SELESAI TANPA WARNING/FAIL YANG TERDETEKSI OLEH SCRIPT."
    set "STR_RESTART_ADVICE=Sangat disarankan restart PC agar registry, sharing, dan service reload penuh."
    set "STR_RESTART_PROMPT=Restart sekarang? [Y/N]: "
    set "STR_RESTART_MANUAL=Silakan restart manual."
    set "STR_RESTORE_TITLE=RESTORE REGISTRY DARI BACKUP TERAKHIR"
    set "STR_NO_BACKUP=[WARN] Belum ada backup."
    set "STR_BACKUP_BROKEN=[WARN] Backup rusak atau tidak lengkap."
    set "STR_RESTORE_DONE_FAIL_A=[WARN] Restore selesai, tetapi ada"
    set "STR_RESTORE_DONE_FAIL_B=masalah penting dan"
    set "STR_RESTORE_DONE_FAIL_C=warning. Cek log."
    set "STR_RESTORE_DONE_WARN_A=[WARN] Restore selesai dengan"
    set "STR_RESTORE_DONE_WARN_B=warning. Cek log."
    set "STR_RESTORE_DONE_OK=[+] Restore selesai tanpa warning yang terdeteksi."
    set "STR_RESTART_RECOMMENDED=Disarankan restart PC."
    set "STR_ALREADY_ABSENT=sudah tidak ada"
    set "STR_SPOOL_CREATE_FAIL=Folder spool PRINTERS tidak bisa dibuat."
    set "STR_FIREWALL_ENABLED=    - Firewall File and Printer Sharing enabled"
    set "STR_FIREWALL_FAILED=    - Firewall File and Printer Sharing gagal"
    set "STR_NET_PRIVATE_SKIP=[i] Windows 7/legacy: Set-NetConnectionProfile dilewati."
    set "STR_NET_PRIVATE_PROMPT=Ubah network aktif ke Private? [Y/N]: "
    set "STR_VERIFY_MISMATCH=tidak sesuai"
    set "STR_ACTUAL=aktual"
    set "STR_TARGET=target"
    set "STR_QUICK_ACCESS_TITLE=AKSES CEPAT"
)
exit /b 0

:requireAdmin
fltmc >nul 2>&1
if not errorlevel 1 exit /b 0

color 0E
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

set "ELEVATE_TARGET=%~f0"
set "ELEVATE_DIR=%SCRIPT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:ELEVATE_TARGET -WorkingDirectory $env:ELEVATE_DIR -Verb RunAs; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    color 0C
    echo !STR_ELEVATE_FAIL!
    echo !STR_ELEVATE_SOL!
    echo.
    echo !STR_PRESS_KEY!
    pause >nul
)
exit /b 1

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
goto :mainMenu

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
echo - !STR_LANGUAGE_LABEL!       : !LANG!
echo - !STR_TIME_LABEL!           : %DATE% %TIME%
echo - !STR_STATUS!  : !SPOOLER_STATUS!
echo.
echo -------------------------------------------------------------------------------
echo [!STR_MENU!]
echo -------------------------------------------------------------------------------
echo !STR_MENU_1!
echo !STR_MENU_2!
echo !STR_MENU_3!
echo !STR_MENU_4!
echo !STR_MENU_5!
echo !STR_MENU_6!
echo !STR_MENU_7!
echo !STR_MENU_8!
echo.

choice /C 12345678 /N /M "!STR_SELECT!"

if errorlevel 8 exit /b 0
if errorlevel 7 goto :viewLog
if errorlevel 6 goto :langSettings
if errorlevel 5 goto :userGuide
if errorlevel 4 goto :quickAccess
if errorlevel 3 goto :restoreSettings
if errorlevel 2 (
    set "FIX_MODE=LEGACY"
    goto :confirmLegacy
)
if errorlevel 1 (
    set "FIX_MODE=QUICK"
    goto :runFix
)

echo.
echo !STR_BAD_INPUT!
ping -n 2 127.0.0.1 >nul 2>&1
goto :mainMenu

:confirmLegacy
cls
color 0C
echo.
if /I "!LANG!"=="EN" (
    echo ###############################################################################
    echo #                         CLASSIC/FULL FIX WARNING                            #
    echo ###############################################################################
    echo.
    echo This option should NOT be tried first.
    echo It can reduce security because it enables older compatibility settings:
    echo - SMBv1 on modern Windows.
    echo - SMB insecure guest auth.
    echo - LAN Manager compatibility.
    echo - Blank-password account compatibility.
    echo.
    echo Use only on a trusted home/small-office network if Quick Fix fails.
    echo.
    set "CONFIRM_PROMPT=Type YES to continue, anything else cancels: "
) else (
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
    set "CONFIRM_PROMPT=Ketik YES untuk lanjut, selain itu batal: "
)
echo.
set "CONFIRM="
set /p CONFIRM="!CONFIRM_PROMPT!"
if /I not "!CONFIRM!"=="YES" goto :mainMenu
goto :runFix

:runFix
set "WARN_COUNT=0"
set "FAIL_COUNT=0"
set "BACKUP_RUN_DIR="
cls
color 0E
echo ==============================================================================
echo                  !STR_PROCESS_START! [!FIX_MODE!]
echo ==============================================================================
echo.
call :log "--- Started Printer Fix [!FIX_MODE!] ---"

call :createBackup
if errorlevel 1 (
    echo !STR_BACKUP_FATAL!
    call :log "[FATAL] Backup creation failed. Aborting fix."
    pause
    goto :mainMenu
)

echo !STR_PREP_SERVICES!
call :runCritical "Set Spooler startup auto" "sc config Spooler start= auto"
call :runWarn "Set Server startup auto" "sc config LanmanServer start= auto"
call :runWarn "Set Workstation startup auto" "sc config LanmanWorkstation start= auto"
call :safeStart LanmanServer WARN
call :safeStart LanmanWorkstation WARN
call :safeStop Spooler WARN

echo.
echo !STR_CLEAR_CACHE!
call :ensureSpoolFolders
call :clearFolder "%SystemRoot%\System32\spool\PRINTERS" "Clear PRINTERS queue"
call :clearFolder "%SystemRoot%\System32\spool\SERVERS" "Clear SERVERS cache"

echo.
echo !STR_APPLY_RPC!
call :runCritical "Set RpcAuthnLevelPrivacyEnabled=0" "reg add ^"HKLM\System\CurrentControlSet\Control\Print^" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f"
call :runCritical "Set RpcUseNamedPipeProtocol=1" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f"
call :runCritical "Set RpcProtocols=7" "reg add ^"HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC^" /v RpcProtocols /t REG_DWORD /d 7 /f"
call :deleteKeyOptional "Client Side Rendering Print Provider" "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider"

echo.
echo !STR_APPLY_POINT!
call :runCritical "Set RestrictDriverInstallationToAdministrators=0" "reg add ^"HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint^" /v RestrictDriverInstallationToAdministrators /t REG_DWORD /d 0 /f"
call :runCritical "Set BypassUpdateRoleIndicator=0" "reg add ^"HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint^" /v BypassUpdateRoleIndicator /t REG_DWORD /d 0 /f"

echo.
echo !STR_FIX_PERMS!
call :runWarn "Grant SYSTEM/Admins on PRINTERS" "icacls ^"%SystemRoot%\System32\spool\PRINTERS^" /grant *S-1-5-18:^(OI^)^(CI^)F *S-1-5-32-544:^(OI^)^(CI^)F /T /C /Q"
call :runWarn "Grant SYSTEM/Admins on spool drivers" "icacls ^"%SystemRoot%\System32\spool\drivers^" /grant *S-1-5-18:^(OI^)^(CI^)F *S-1-5-32-544:^(OI^)^(CI^)F /T /C /Q"

echo.
echo !STR_ENABLE_FW!
call :enableFirewallSharing

echo.
call :offerNetworkPrivate

if /I "!FIX_MODE!"=="LEGACY" (
    echo.
    echo !STR_APPLY_LEGACY!
    if !BUILD_NUM! GEQ 9200 (
        call :runWarn "Enable SMBv1 feature" "dism /online /Enable-Feature /FeatureName:SMB1Protocol -All /NoRestart /quiet"
    ) else (
        echo !STR_SMB_SKIP!
        call :log "[SKIP] SMBv1 DISM feature skipped for pre-Windows 8 build."
    )
    call :runCritical "Allow insecure guest auth" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters^" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f"
    call :runWarn "Set LmCompatibilityLevel=1" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f"
    call :runWarn "Set limitblankpassworduse=0" "reg add ^"HKLM\SYSTEM\CurrentControlSet\Control\Lsa^" /v limitblankpassworduse /t REG_DWORD /d 0 /f"
)

echo.
echo !STR_RESTART_SERVICES!
call :safeStart Spooler FAIL
call :runWarn "Set fdPHost auto" "sc config fdPHost start= auto"
call :runWarn "Set FDResPub auto" "sc config FDResPub start= auto"
call :safeStart fdPHost WARN
call :safeStart FDResPub WARN

echo.
echo !STR_VERIFY_FINAL!
call :verifyFinal

echo.
if !FAIL_COUNT! GTR 0 (
    color 0C
    echo ==============================================================================
    echo !STR_DONE_FAIL_A! !FAIL_COUNT! !STR_DONE_FAIL_B! !WARN_COUNT! !STR_DONE_FAIL_C!
    echo !STR_DONE_FAIL_HINT!
    echo ==============================================================================
) else if !WARN_COUNT! GTR 0 (
    color 0E
    echo ==============================================================================
    echo !STR_DONE_WARN_A! !WARN_COUNT! !STR_DONE_WARN_B!
    echo ==============================================================================
) else (
    color 0A
    echo ==============================================================================
    echo !STR_DONE_OK!
    echo ==============================================================================
)
echo Log    : %LOG_FILE%
echo Backup : !BACKUP_RUN_DIR!
echo.
echo !STR_RESTART_ADVICE!
choice /C YN /N /M "!STR_RESTART_PROMPT!"
if errorlevel 2 (
    echo !STR_RESTART_MANUAL!
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
call :saveValueState "RestrictDriverInstallationToAdministrators" "HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "RestrictDriverInstallationToAdministrators"
call :saveValueState "BypassUpdateRoleIndicator" "HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "BypassUpdateRoleIndicator"
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
echo                  !STR_RESTORE_TITLE!
echo ==============================================================================
echo.
if not exist "%LATEST_FILE%" (
    echo !STR_NO_BACKUP!
    pause
    goto :mainMenu
)
set "RESTORE_DIR="
set /p RESTORE_DIR=<"%LATEST_FILE%"
if not exist "!RESTORE_DIR!\reg_state.cmd" (
    echo !STR_BACKUP_BROKEN!
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
call :restoreValue "RestrictDriverInstallationToAdministrators" "HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "RestrictDriverInstallationToAdministrators"
call :restoreValue "BypassUpdateRoleIndicator" "HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "BypassUpdateRoleIndicator"
call :restoreValue "AllowInsecureGuestAuth" "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth"
call :restoreValue "LmCompatibilityLevel" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel"
call :restoreValue "limitblankpassworduse" "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "limitblankpassworduse"

call :safeStart Spooler FAIL
echo.
if !FAIL_COUNT! GTR 0 (
    color 0C
    echo !STR_RESTORE_DONE_FAIL_A! !FAIL_COUNT! !STR_RESTORE_DONE_FAIL_B! !WARN_COUNT! !STR_RESTORE_DONE_FAIL_C!
) else if !WARN_COUNT! GTR 0 (
    color 0E
    echo !STR_RESTORE_DONE_WARN_A! !WARN_COUNT! !STR_RESTORE_DONE_WARN_B!
) else (
    color 0A
    echo !STR_RESTORE_DONE_OK!
)
echo Log: %LOG_FILE%
echo !STR_RESTART_RECOMMENDED!
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
    echo     - %~1 !STR_ALREADY_ABSENT!
    call :log "[OK] %~1 already absent."
    exit /b 0
)
call :runWarn "Delete %~1" "reg delete ^"%~2^" /f"
exit /b 0

:ensureSpoolFolders
if not exist "%SystemRoot%\System32\spool\PRINTERS" mkdir "%SystemRoot%\System32\spool\PRINTERS" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\SERVERS" mkdir "%SystemRoot%\System32\spool\SERVERS" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\drivers" mkdir "%SystemRoot%\System32\spool\drivers" >nul 2>&1
if not exist "%SystemRoot%\System32\spool\PRINTERS" call :addIssue FAIL "!STR_SPOOL_CREATE_FAIL!"
exit /b 0

:clearFolder
set "TARGET=%~1"
set "DESC=%~2"
echo     - !DESC!
call :log "[CMD] !DESC!"
if not exist "!TARGET!" mkdir "!TARGET!" >nul 2>&1
pushd "!TARGET!" || exit /b 0
del /q /f * >> "%LOG_FILE%" 2>&1
for /d %%D in (*) do rd /s /q "%%D" >> "%LOG_FILE%" 2>&1
popd
exit /b 0

:enableFirewallSharing
set "RULE_EN=File and Printer Sharing"
set "RULE_ID=Berbagi File dan Printer"
netsh advfirewall firewall set rule group="%RULE_EN%" new enable=yes >> "%LOG_FILE%" 2>&1
set "RC1=!ERRORLEVEL!"
netsh advfirewall firewall set rule group="%RULE_ID%" new enable=yes >> "%LOG_FILE%" 2>&1
set "RC2=!ERRORLEVEL!"
if "!RC1!"=="0" (
    echo !STR_FIREWALL_ENABLED!
    call :log "[OK] Firewall group '%RULE_EN%' enabled."
) else if "!RC2!"=="0" (
    echo !STR_FIREWALL_ENABLED!
    call :log "[OK] Firewall group '%RULE_ID%' enabled."
) else (
    call :addIssue WARN "Firewall sharing group enable failed (both EN and ID names)."
)
exit /b 0

:offerNetworkPrivate
if !BUILD_NUM! LSS 9200 (
    echo !STR_NET_PRIVATE_SKIP!
    call :log "[SKIP] Set-NetConnectionProfile skipped for legacy Windows."
    exit /b 0
)
choice /C YN /N /M "!STR_NET_PRIVATE_PROMPT!"
if errorlevel 2 exit /b 0
call :runWarn "Set Network to Private" "powershell -NoProfile -ExecutionPolicy Bypass -Command ^"Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private^""
exit /b 0

:verifyFinal
call :verifyService Spooler
call :verifyDword "HKLM\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled" "0x0"
call :verifyDword "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcUseNamedPipeProtocol" "0x1"
call :verifyDword "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "RpcProtocols" "0x7"
call :verifyDword "HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "RestrictDriverInstallationToAdministrators" "0x0"
call :verifyDword "HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "BypassUpdateRoleIndicator" "0x0"
if /I "!FIX_MODE!"=="LEGACY" (
    call :verifyDword "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth" "0x1"
)
exit /b 0

:verifyService
set "SVC=%~1"
call :isServiceRunning "%SVC%"
if errorlevel 1 (
    call :addIssue FAIL "Verification: %SVC% is NOT running."
) else (
    call :log "[VERIFY] %SVC% is running."
)
exit /b 0

:verifyDword
set "VKEY=%~1"
set "VVAL=%~2"
set "VEXP=%~3"
set "VACT="
for /f "tokens=3" %%A in ('reg query "%VKEY%" /v "%VVAL%" 2^>nul ^| findstr /I /C:"%VVAL%"') do set "VACT=%%A"
if /I not "!VACT!"=="!VEXP!" (
    call :addIssue WARN "Verification mismatch: %VVAL% (!STR_ACTUAL! !VACT!, !STR_TARGET! !VEXP!)"
) else (
    call :log "[VERIFY] %VVAL% matches expected !VEXP!."
)
exit /b 0

:log
set "MSG=%~1"
echo [%DATE% %TIME%] !MSG! >> "%LOG_FILE%"
exit /b 0

:langSettings
cls
echo.
echo ###############################################################################
echo #                                                                             #
echo #        !STR_LANG_TITLE!
echo #                                                                             #
echo ###############################################################################
echo.
echo !STR_LANG_1!
echo !STR_LANG_2!
echo !STR_LANG_3!
echo.
choice /C 123 /N /M "!STR_LANG_SELECT!"
if errorlevel 3 goto :mainMenu
if errorlevel 2 (
    call :saveLanguage ID
    goto :mainMenu
)
if errorlevel 1 (
    call :saveLanguage EN
    goto :mainMenu
)
goto :langSettings

:viewLog
cls
echo.
echo ###############################################################################
echo #                                                                             #
echo #        !STR_LOG_TITLE!
echo #                                                                             #
echo ###############################################################################
echo.
echo !STR_LOG_FILE!: %LOG_FILE%
echo.
if not exist "%LOG_FILE%" (
    echo !STR_LOG_MISSING!
    pause
    goto :mainMenu
)
set "SIZE=0"
for %%A in ("%LOG_FILE%") do set "SIZE=%%~zA"
if !SIZE! EQU 0 (
    echo !STR_LOG_EMPTY!
    pause
    goto :mainMenu
)
type "%LOG_FILE%"
echo.
pause
goto :mainMenu

:quickAccess
cls
echo.
echo ###############################################################################
echo #                                                                             #
echo #        !STR_QUICK_ACCESS_TITLE!
echo #                                                                             #
echo ###############################################################################
echo.
echo [1] Services (services.msc)
echo [2] Printers & Scanners (ms-settings:printers)
echo [3] Print Management (printmanagement.msc)
echo [4] Network Connections (ncpa.cpl)
echo [5] !STR_BACK!
echo.
choice /C 12345 /N /M "!STR_SELECT!"
if errorlevel 5 goto :mainMenu
if errorlevel 4 (
    start ncpa.cpl
    goto :quickAccess
)
if errorlevel 3 (
    start printmanagement.msc
    goto :quickAccess
)
if errorlevel 2 (
    start ms-settings:printers
    goto :quickAccess
)
if errorlevel 1 (
    start services.msc
    goto :quickAccess
)
goto :quickAccess

:userGuide
cls
echo.
echo ###############################################################################
echo #                                                                             #
echo #        !STR_MENU_5!
echo #                                                                             #
echo ###############################################################################
echo.
if /I "!LANG!"=="EN" (
    echo [GUIDE ^& RISK]
    echo.
    echo 1. Run as Administrator.
    echo 2. If run normally, the script will request UAC elevation automatically.
    echo 3. Start with Quick Fix.
    echo 4. Classic/Full Fix is for persistent issues but reduces security.
    echo 5. Point and Print compatibility is included in Quick Fix.
    echo 6. Registry backups are created per run and never overwritten.
    echo 7. Restore only reverts registry keys, not printer drivers.
    echo 8. Windows 7 support is best-effort (command compatibility).
    echo 9. If FAIL appears, check the log and resolve the issue.
) else (
    echo [PANDUAN ^& RISIKO]
    echo.
    echo 1. Jalankan sebagai Administrator.
    echo 2. Jika double-click biasa, script akan meminta UAC Administrator otomatis.
    echo 3. Gunakan Quick Fix dulu.
    echo 4. Classic/Full Fix hanya untuk kasus lama/bandel karena menurunkan keamanan.
    echo 5. Point and Print compatibility dari versi awal sudah masuk ke Quick Fix.
    echo 6. Backup registry dibuat per eksekusi dan tidak ditimpa.
    echo 7. Restore menu hanya mengembalikan registry yang dibackup, bukan driver printer.
    echo 8. Windows 7 didukung sebatas kompatibilitas command; hasil tetap tergantung driver/update/SMB.
    echo 9. Jika muncul FAIL, jangan anggap sukses. Buka log dan perbaiki penyebabnya.
)
echo.
pause
goto :mainMenu
