@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "DOWNLOADS_DIR=%SCRIPT_DIR%downloads"

echo ==============================
echo  VIDEO DOWNLOADER
echo ==============================
echo.


:: Always save and open downloads relative to this script's folder.
if not exist "%DOWNLOADS_DIR%" mkdir "%DOWNLOADS_DIR%"

:input
echo Paste a YouTube URL (or type EXIT to quit):
set /p URL=

if /i "%URL%"=="exit" goto finish

if "%URL%"=="" (
    echo No URL entered. Try again.
    goto input
)

echo.
echo Downloading:
echo %URL%
echo ------------------------------

yt-dlp ^
  -f "bv*+ba/b" ^
  --merge-output-format mkv ^
  --remux-video mkv ^
  --embed-metadata ^
  --embed-thumbnail ^
  --concurrent-fragments 4 ^
  --js-runtimes deno ^
  --restrict-filenames ^
  -o "%DOWNLOADS_DIR%\%%(title)s [%%(id)s].%%(ext)s" ^
  "%URL%"

echo.
if %errorlevel% neq 0 (
    echo Download failed.
  echo Check the URL and confirm Install-Dependencies.bat completed successfully.
) else (
    echo Download complete.
)

:repeat_prompt
echo.
set /p AGAIN=Download another? (y/n): 

if /i "%AGAIN%"=="y" goto input
if /i "%AGAIN%"=="n" goto finish

echo Please enter Y or N.
goto repeat_prompt
:finish
echo Opening downloads folder...
explorer "%DOWNLOADS_DIR%"
:exit
pause