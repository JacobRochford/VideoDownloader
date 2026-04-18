@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_VERSION=1.1.0"
set "SCRIPT_DIR=%~dp0"
set "DOWNLOADS_DIR=%SCRIPT_DIR%videos"

pushd "%SCRIPT_DIR%" >nul 2>nul
title VideoDownloader

echo ==============================
echo  VIDEO DOWNLOADER
echo  Version %SCRIPT_VERSION%
echo ==============================
echo.

where yt-dlp >nul 2>nul
if %errorlevel% neq 0 (
  echo yt-dlp was not found.
  echo Run Install-Dependencies.bat before using this downloader.
  goto exit
)

where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
  echo FFmpeg was not found.
  echo Run Install-Dependencies.bat before using this downloader.
  goto exit
)

where deno >nul 2>nul
if %errorlevel% neq 0 (
  echo Deno was not found.
  echo Run Install-Dependencies.bat before using this downloader.
  goto exit
)

:: Always save and open downloads relative to this script's folder.
if not exist "%DOWNLOADS_DIR%" mkdir "%DOWNLOADS_DIR%"

:input
echo Paste a YouTube URL (or type EXIT to quit):
set "URL="
set /p URL=
if errorlevel 1 goto finish

if /i "%URL%"=="exit" goto finish

if "%URL%"=="" (
    echo No URL entered. Try again.
    goto input
)

echo %URL% | findstr /i "list=" >nul
if %errorlevel% equ 0 (
  set "DOWNLOAD_MODE=playlist"
  set "PLAYLIST_FLAG=--yes-playlist"
  set "OUTPUT_TEMPLATE=%DOWNLOADS_DIR%\%%(playlist_title)s [%%(playlist_id)s]\%%(playlist_index)03d - %%(title)s [%%(id)s].%%(ext)s"
) else (
  set "DOWNLOAD_MODE=single video"
  set "PLAYLIST_FLAG=--no-playlist"
  set "OUTPUT_TEMPLATE=%DOWNLOADS_DIR%\%%(title)s [%%(id)s].%%(ext)s"
)

:mode_ready

echo.
echo Detected: !DOWNLOAD_MODE!
echo Downloading:
echo !URL!
echo Format: MKV
echo ------------------------------

yt-dlp ^
  -f "bv*+ba/b" ^
  --merge-output-format mkv ^
  --remux-video mkv ^
  --embed-metadata ^
  --embed-chapters ^
  --embed-thumbnail ^
  --concurrent-fragments 4 ^
  --js-runtimes deno ^
  !PLAYLIST_FLAG! ^
  --restrict-filenames ^
  -o "!OUTPUT_TEMPLATE!" ^
  "!URL!"

echo.
if %errorlevel% neq 0 (
    echo Download failed.
  echo Check the URL, selected format, and confirm Install-Dependencies.bat completed successfully.
) else (
    echo Download complete.
)

:repeat_prompt
echo.
set "AGAIN="
set /p AGAIN=Download another? (y/n): 

if errorlevel 1 goto finish
if not defined AGAIN goto finish

if /i "%AGAIN%"=="y" goto input
if /i "%AGAIN%"=="n" goto finish

echo Please enter Y or N.
goto repeat_prompt

:finish
echo Opening downloads folder...
explorer "%DOWNLOADS_DIR%"
:exit
pause
popd >nul 2>nul