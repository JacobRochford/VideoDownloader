function Write-ErrorLog {
    param([string]$Entry)
    try {
        $ErrorLogFile = Join-Path $BaseDir "yt-dlp-errors.log"
        if ((Get-Item $ErrorLogFile -ErrorAction SilentlyContinue).Length -gt ($MaxLogMB * 1MB)) {
            Move-Item $ErrorLogFile "$ErrorLogFile.old" -Force
            Write-Host "[!] Error log rotated (exceeded ${MaxLogMB} MB)." -ForegroundColor DarkYellow
        }
        Add-Content -Path $ErrorLogFile -Value $Entry -Encoding UTF8
    } catch {
        Write-Host "[!] Write-ErrorLog error: $_" -ForegroundColor Red
    }
}
