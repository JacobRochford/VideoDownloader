@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_VERSION=1.1.0"
set "SCRIPT_DIR=%~dp0"
set "SETUP_FAILED=0"
set "RESTART_REQUIRED=0"
set "PYTHON_CMD="

pushd "%SCRIPT_DIR%" >nul 2>nul
title Install Dependencies

echo ==============================
echo  INSTALL DEPENDENCIES
echo  Version %SCRIPT_VERSION%
echo ==============================
echo.

where winget >nul 2>nul
if %errorlevel% neq 0 (
    echo winget was not found.
    echo Install App Installer from Microsoft Store, then run Install-Dependencies.bat again.
    set "SETUP_FAILED=1"
    goto summary
)

:: ---- Python ----
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo Installing Python...
    winget install --id Python.Python -e
    if %errorlevel% neq 0 (
        echo Python installation failed.
        set "SETUP_FAILED=1"
    )
) else (
    echo Python already installed.
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python"
) else (
    where py >nul 2>nul
    if %errorlevel% equ 0 (
        set "PYTHON_CMD=py -3"
    ) else (
        echo Python is not available in the current terminal session yet.
        echo Reopen the terminal after setup, then run Install-Dependencies.bat again to finish yt-dlp installation.
        set "RESTART_REQUIRED=1"
    )
)

:: ---- yt-dlp ----
if defined PYTHON_CMD (
    !PYTHON_CMD! -m pip show yt-dlp >nul 2>nul
    if !errorlevel! neq 0 (
        echo Installing yt-dlp...
    ) else (
        echo Upgrading yt-dlp...
    )

    !PYTHON_CMD! -m pip install -U yt-dlp
    if !errorlevel! neq 0 (
        echo yt-dlp installation failed.
        set "SETUP_FAILED=1"
    )
) else (
    echo Skipping yt-dlp because Python is not ready in this terminal session.
)

:: ---- FFmpeg ----
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo Installing FFmpeg...
    winget install --id Gyan.FFmpeg.Essentials -e
    if %errorlevel% neq 0 (
        echo FFmpeg installation failed.
        set "SETUP_FAILED=1"
    )
) else (
    echo FFmpeg already installed.
)

:: ---- Deno ----
where deno >nul 2>nul
if %errorlevel% neq 0 (
    echo Installing Deno...
    winget install --id DenoLand.Deno -e
    if %errorlevel% neq 0 (
        echo Deno installation failed.
        set "SETUP_FAILED=1"
    )
) else (
    echo Deno already installed.
)

:summary
echo.
echo ==============================
if "%SETUP_FAILED%"=="0" (
    if "%RESTART_REQUIRED%"=="0" (
        echo  SETUP COMPLETE
    ) else (
        echo  SETUP PARTIALLY COMPLETE
    )
) else (
    echo  SETUP FINISHED WITH WARNINGS
)
echo ==============================
if "%SETUP_FAILED%"=="0" (
    if "%RESTART_REQUIRED%"=="0" (
        echo You can now run VideoDownloader.bat
    ) else (
        echo Reopen the terminal, then run Install-Dependencies.bat once more if yt-dlp was skipped.
        echo After that, run VideoDownloader.bat
    )
) else (
    echo Review the messages above, then rerun Install-Dependencies.bat.
)
echo If any command is still not recognized, reopen your terminal window.
echo.
echo Tool verification:
where python >nul 2>nul
if %errorlevel% equ 0 (
    echo   Python: OK
) else (
    where py >nul 2>nul
    if %errorlevel% equ 0 (
        echo   Python: OK via py launcher
    ) else (
        echo   Python: NOT FOUND
    )
)

where yt-dlp >nul 2>nul
if %errorlevel% equ 0 (
    echo   yt-dlp: OK
) else (
    echo   yt-dlp: NOT FOUND
)

where ffmpeg >nul 2>nul
if %errorlevel% equ 0 (
    echo   FFmpeg: OK
) else (
    echo   FFmpeg: NOT FOUND
)

where deno >nul 2>nul
if %errorlevel% equ 0 (
    echo   Deno: OK
) else (
    echo   Deno: NOT FOUND
)
pause
popd >nul 2>nul