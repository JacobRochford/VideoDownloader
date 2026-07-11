@echo off
chcp 65001 >nul
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"

set "FORCE_SETUP="
set "SHOW_MENU="

:parseArgs
if "%~1"=="" goto afterArgs
if /I "%~1"=="--setup" set "FORCE_SETUP=1"
if /I "%~1"=="/setup" set "FORCE_SETUP=1"
if /I "%~1"=="--install" set "FORCE_SETUP=1"
if /I "%~1"=="--menu" set "SHOW_MENU=1"
if /I "%~1"=="/menu" set "SHOW_MENU=1"
shift
goto parseArgs

:afterArgs

if defined FORCE_SETUP goto verifyDependencies

call :haveCommand pwsh
if errorlevel 1 goto verifyDependencies
call :haveCommand yt-dlp
if errorlevel 1 goto verifyDependencies
call :haveCommand ffmpeg
if errorlevel 1 goto verifyDependencies
call :haveCommand deno
if errorlevel 1 goto verifyDependencies

echo [OK] Dependencies already available. Skipping setup.
goto launch

:verifyDependencies
where winget >nul 2>&1
if errorlevel 1 (
    echo [X] winget not found. Install App Installer or add dependencies manually.
    popd & exit /b 1
)

echo [!] Verifying dependencies...

:: NOTE: --accept-package-agreements silently accepts third-party EULAs for:
::   Microsoft PowerShell 7, yt-dlp, Gyan/FFmpeg Essentials, DenoLand.Deno
:: Review each project's license before distributing this script.
:: NOTE: Deno is required by yt-dlp at runtime for full YouTube support (yt-dlp-ejs).
call :ensurePackage Microsoft.PowerShell pwsh
if errorlevel 1 popd & exit /b 1
call :ensurePackage yt-dlp.yt-dlp yt-dlp
if errorlevel 1 popd & exit /b 1
call :ensurePackage Gyan.FFmpeg.Essentials ffmpeg
if errorlevel 1 popd & exit /b 1
call :ensurePackage DenoLand.Deno deno
if errorlevel 1 popd & exit /b 1

:launch
echo [OK] Launching ClipboardWatcher...
set "VIDEODOWNLOADER_LAUNCHED=1"
set "LAUNCH_ARGS="
if defined SHOW_MENU set "LAUNCH_ARGS=-ShowMenu"
start "Video Downloader" pwsh -NoProfile -ExecutionPolicy RemoteSigned ^
    -File "%SCRIPT_DIR%lib\ClipboardWatcher.ps1" %LAUNCH_ARGS%
popd
exit /b 0

:haveCommand
where "%~1" >nul 2>&1
exit /b %errorlevel%

:ensurePackage
set "PACKAGE_ID=%~1"
set "COMMAND_NAME=%~2"

call :haveCommand "%COMMAND_NAME%"
if not errorlevel 1 (
    echo [OK] %PACKAGE_ID% ready.
    exit /b 0
)

echo [!] Installing %PACKAGE_ID%...
winget install --id %PACKAGE_ID% -e --accept-package-agreements
if errorlevel 1 (
    echo [X] Install failed for %PACKAGE_ID%.
    popd & exit /b 1
)

call :haveCommand "%COMMAND_NAME%"
if errorlevel 1 (
    echo [X] %COMMAND_NAME% not found after install.
    echo     Close this window, open a new terminal, and run the script again.
    popd & exit /b 1
)

echo [OK] %PACKAGE_ID% ready.
exit /b 0