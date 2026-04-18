# VideoDownloader

A Windows batch utility script for downloading YouTube videos and playlists in the best quality available, saved as merged MKV files with embedded metadata.

## Description

**VideoDownloader** downloads YouTube videos and playlists with minimal setup. It:

- Detects single videos and playlists from pasted YouTube URLs
- Grabs the best available video and audio streams
- Merges them into a single MKV file
- Embeds metadata, chapters, and thumbnails automatically
- Saves everything in a clean `videos` folder structure


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
   cd C:\Users\{YourUsername}\Desktop
   git clone https://github.com/JacobRochford/VideoDownloader.git
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

3. **Verify installation** — The installer will display a verification summary. All required tools should verify successfully. Python may appear as **OK via py launcher** depending on your setup.

## Usage

1. **Run the downloader:**
   ```cmd
   VideoDownloader.bat
   ```

2. **Paste a YouTube URL** when prompted:
   ```
   ==============================
    VIDEO DOWNLOADER
   Version 1.1.0
   ==============================
   
   Paste a YouTube URL (or type EXIT to quit):
   https://www.youtube.com/watch?v=dQw4w9WgXcQ
   ```

3. **Wait for it to finish** — The script will:
   - Download the best video and audio (or full playlist if detected)
   - Merge them into MKV format
   - Add metadata and thumbnail
   - Save to the `videos` folder (organized by playlist if applicable)

4. **Next steps:**
   - Press `y` to download another video
   - Press `n` to exit


**Single videos save as:**
`videos\[video_title] [video_id].mkv`

**Playlists save as:**
`videos\[playlist_title] [playlist_id]\[playlist_index] - [video_title] [video_id].mkv`

**Example (single):**
`videos\Stop_Updating_Your_Software_No_Seriously [WBgdAkol0VQ].mkv`

**Example (playlist):**
`videos\My_Playlist [PL12345]\001 - Alan_Watts_Chillstep [abc123].mkv`

## Features

- Best quality output — top video and audio combined
- MKV format — no quality loss
- Playlist support — download full playlists with organized folder structure
- Metadata & thumbnails automatically saved
- Fast — up to 4 parallel downloads
- Simple interface — just paste a URL (supports both single videos and playlists)
- Clean filenames — handles special characters and organizes by playlist
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


**Version:** 1.1.0 | April 2026