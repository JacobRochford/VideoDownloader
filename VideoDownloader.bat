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

yt-dlp ^
goto input

:input
echo.
echo Paste YouTube URLs (comma, newline, or space separated, or type EXIT to quit):
set "URLS="
set /p URLS=

if /i "%URLS%"=="exit" goto finish

if "%URLS%"=="" (
    echo No URL entered. Try again.
    goto input
)

:: Combine all arguments if passed via command line
if not "%~1"=="" (
  set "URLS=%*"
)

:: Replace commas with spaces
set "URLS=%URLS:,= %"

:: Split URLs by space or newline and process each
for %%U in (%URLS%) do call :process_url "%%U"

goto input

:process_url
setlocal EnableDelayedExpansion
set "RAW_URL=%~1"
:: Remove surrounding quotes and whitespace
set "URL=!RAW_URL!"
for /f "tokens=*" %%A in ("!URL!") do set "URL=%%A"
set "URL=!URL:~0,512!"
if "!URL!"=="" exit /b

:: Detect playlist or single video
echo !URL! | findstr /i "list=" >nul
if !errorlevel! equ 0 (
  set "DOWNLOAD_MODE=playlist"
  set "PLAYLIST_FLAG=--yes-playlist"
  set "OUTPUT_TEMPLATE=%DOWNLOADS_DIR%\%%(playlist_title)s\%%(playlist_index)03d - %%(title)s.%%(ext)s"
) else (
  set "DOWNLOAD_MODE=single video"
  set "PLAYLIST_FLAG=--no-playlist"
  set "OUTPUT_TEMPLATE=%DOWNLOADS_DIR%\%%(title)s.%%(ext)s"
)

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

if !errorlevel! neq 0 (
    echo Download failed for !URL!.
    echo Check the URL and dependencies.
) else (
    echo Download complete for !URL!.
)
endlocal
exit /b

:finish
echo Opening downloads folder...
explorer "%DOWNLOADS_DIR%"

:exit
pause
popd >nul 2>nul