@echo off
setlocal EnableExtensions

title Windows Printer Sharing Fix v4
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%FixPrinter.ps1"

if not exist "%PS_SCRIPT%" (
    echo.
    echo [ERROR] FixPrinter.ps1 was not found next to this launcher.
    echo Keep FixPrinter.bat and FixPrinter.ps1 in the same folder.
    echo.
    pause
    exit /b 2
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Windows PowerShell was not found.
    echo Windows Printer Sharing Fix v4 requires Windows PowerShell 5.1 or newer.
    echo.
    pause
    exit /b 3
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [ERROR] Windows Printer Sharing Fix exited with code %RC%.
    echo Check the logs folder for details.
    echo.
    pause
)

exit /b %RC%
