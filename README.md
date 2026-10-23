# VideoDownloader

A Windows console utility for downloading YouTube videos and playlists using yt-dlp and FFmpeg.

Run the batch script, paste one or more URLs, and download the best available video and audio as merged MKV files.

## Features

- Download single videos or full playlists.
- Enter multiple URLs separated by commas or spaces.
- Process URLs sequentially.
- Download up to four fragments concurrently within each download.
- Merge video and audio into MKV files.
- Embed metadata, chapters, and thumbnails.
- Save downloads in a `videos` folder beside the script.
- Organize playlist downloads into separate folders.
- Open the downloads folder when you type `EXIT`.

## Requirements

- Windows 10 or later.
- winget, provided by Microsoft's App Installer.
- Python 3 and pip.
- yt-dlp.
- FFmpeg.
- Deno.

The included installer attempts to install missing dependencies and install or upgrade yt-dlp.

## Installation

1. Clone the repository's `master` branch:

   ```cmd
   git clone --branch master --single-branch https://github.com/JacobRochford/VideoDownloader.git
   cd VideoDownloader
   ```

   Alternatively, download and extract the `master` branch ZIP from GitHub.

2. Run:

   ```cmd
   Install-Dependencies.bat
   ```

3. Review the tool verification summary.

   If a tool is not found, reopen your terminal and run the installer again. Newly installed tools may not be available in the current terminal session.

## Usage

1. Run:

   ```cmd
   VideoDownloader.bat
   ```

2. Paste a YouTube URL at the prompt and press Enter:

   ```text
   Paste YouTube URLs (comma, newline, or space separated, or type EXIT to quit):
   https://www.youtube.com/watch?v=VIDEO_ID
   ```

   For multiple URLs, use commas or spaces on one line:

   ```text
   https://www.youtube.com/watch?v=VIDEO_ID_1, https://www.youtube.com/watch?v=VIDEO_ID_2
   ```

   Although the prompt mentions newline separation, comma or space separated input on one line is the supported way to submit multiple URLs.

3. Wait for the downloads to finish.

   URLs containing `list=` are treated as playlists. Other URLs are treated as single videos.

4. The script returns to the URL prompt after processing your input. Enter more URLs, or type:

   ```text
   EXIT
   ```

   The script opens the downloads folder and prompts you to press a key before closing.

## Download Locations

All downloads are saved relative to `VideoDownloader.bat`, regardless of the terminal's current directory.

Single videos:

```text
videos\[video_title].mkv
```

Playlist videos:

```text
videos\[playlist_title]\[playlist_index] - [video_title].mkv
```

Playlist indexes use at least three digits, such as `001`.

The script uses yt-dlp's restricted filename mode, so spaces and special characters may be replaced. Video and playlist IDs are not included in the filename templates.

## How It Works

| Component | Purpose |
|-----------|---------|
| Windows Batch | Console interface and download workflow |
| Python and pip | Install and run yt-dlp |
| yt-dlp | Extract and download video and audio |
| FFmpeg | Merge and remux media into MKV files |
| Deno | JavaScript runtime supplied to yt-dlp |
| winget | Install dependencies |

The script requests the best available video and audio streams, with a fallback to a combined stream. Available quality depends on the source video.

## Troubleshooting

### winget was not found

Install Microsoft's App Installer from the Microsoft Store, then run `Install-Dependencies.bat` again.

### Python or another dependency is not found after installation

Close and reopen your terminal, then run:

```cmd
Install-Dependencies.bat
```

Review the installation messages and tool verification summary for failures.

### yt-dlp was not found

Run `Install-Dependencies.bat` to install or upgrade yt-dlp.

If the downloader still cannot find it, verify that the Python Scripts directory containing `yt-dlp` is on your PATH.

### FFmpeg or Deno was not found

Run `Install-Dependencies.bat`, reopen your terminal, and check:

```cmd
ffmpeg -version
deno --version
```

### A download fails

- Check that the URL is valid and your internet connection is working.
- Review yt-dlp's error output.
- Run `Install-Dependencies.bat` to update yt-dlp.
- Confirm that FFmpeg and Deno are available.
- Try another video to determine whether the failure is specific to that content.

Some videos may be unavailable because of access restrictions or removal.

## License

MIT License. See [LICENSE](LICENSE).

**Version:** 1.1.0
