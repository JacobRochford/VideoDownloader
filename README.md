# VideoDownloader

A Windows batch utility script for downloading YouTube videos in the best quality available (MKV format with best audio and video combined).

## Description

**VideoDownloader** downloads YouTube videos at the best quality with minimal setup. It:

- Grabs the best video and audio streams
- Merges them into a single MKV file
- Saves thumbnails automatically
- Keeps things simple and interactive


## Tech Stack

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Downloader** | YouTube video extraction | [yt-dlp](https://github.com/yt-dlp/yt-dlp) |
| **Video Merger** | Combines streams & converts format | [FFmpeg](https://ffmpeg.org/) |
| **Runtime** | Video processing scripts | [Deno](https://deno.com/) |
| **Package Manager** | Installs dependencies | [winget](https://github.com/microsoft/winget-cli) |
| **Script Language** | Main application logic | Windows Batch (CMD) |

## Installation

### Prerequisites
- **Windows 10 or later**
- **winget** (included on most modern Windows installations)

### Quick Start

1. **Clone or download** this repository to your desired location:
   ```cmd
   cd C:\Users\YourUsername\Desktop
   git clone https://github.com/yourusername/VideoDownloader.git
   cd VideoDownloader
   ```

2. **Run the dependency installer:**
   ```cmd
   Install-Dependencies.bat
   ```
   
   This script will automatically install:
   - Python 3
   - yt-dlp (Python package)
   - FFmpeg (Essentials build)
   - Deno
   
   **Note:** After installation, you may need to reopen your terminal if Python was freshly installed.

3. **Verify installation** — The installer will display a verification summary. All four tools should show **OK**.

## Usage

### Usage

1. **Run the downloader:**
   ```cmd
   VideoDownloader.bat
   ```

2. **Paste a YouTube URL** when prompted:
   ```
   ==============================
    VIDEO DOWNLOADER
    Version 1.0.0
   ==============================
   
   Paste a YouTube URL (or type EXIT to quit):
   https://www.youtube.com/watch?v=dQw4w9WgXcQ
   ```

3. **Wait for it to finish** — The script will:
   - Download the best video and audio
   - Merge them into MKV format
   - Add metadata and thumbnail
   - Save to the `downloads` folder

4. **Next steps:**
   - Press `y` to download another video
   - Press `n` to exit

Videos save as: `downloads\[video_title] [video_id].mkv`

**Example:** `downloads\Stop_Updating_Your_Software_No_Seriously [WBgdAkol0VQ].mkv`

## Features

- Best quality output — top video and audio combined
- MKV format — no quality loss
- Metadata & thumbnails automatically saved
- Fast — up to 4 parallel downloads
- Simple interface — just paste a URL
- Clean filenames — handles special characters
- One command setup — automatic dependency install
- Helpful errors — clear messages if something goes wrong

## Troubleshooting

### "Python was not found"
- Check installation: `python --version`
- Close and reopen Command Prompt
- Run `Install-Dependencies.bat` again

### "yt-dlp was not found"
- Run `Install-Dependencies.bat` again
- Close and reopen Command Prompt
- Run `VideoDownloader.bat` again

### "FFmpeg was not found"
- Verify FFmpeg installation: `ffmpeg -version`
- If missing, run `Install-Dependencies.bat` again

### "Deno was not found"
- Verify Deno installation: `deno --version`
- If missing, reinstall via `Install-Dependencies.bat`

### Download fails with error
1. Verify the URL is a valid YouTube link
2. Check internet connection
3. Some videos may have restrictions—try another video
4. Check FFmpeg is properly installed

### Tools not found after install
- Close and reopen your terminal
- Run `Install-Dependencies.bat` again

## License

MIT License — see [LICENSE](LICENSE) for details.


**Version:** 1.0.0 | April 2026