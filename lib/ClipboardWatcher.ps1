
#Requires -Version 7
param(
    [switch]$ShowMenu
)

$ErrorActionPreference = 'Stop'

function Write-Host {
    [CmdletBinding(DefaultParameterSetName='String')]
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        $Object,
        [System.ConsoleColor] $ForegroundColor,
        [System.ConsoleColor] $BackgroundColor,
        [Switch] $NoNewline,
        [Switch] $NoTimestamp
    )

    if ($Object -eq "" -or $Object -eq $null) {
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
        return
    }

    $args = @{}
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $args['ForegroundColor'] = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $args['BackgroundColor'] = $BackgroundColor }
    if ($NoNewline) { $args['NoNewline'] = $true }

    if ($NoTimestamp) {
        Microsoft.PowerShell.Utility\Write-Host $Object @args
    } else {
        $timestamp = (Get-Date).ToString('HH:mm:ss')
        $prefixed = "[$timestamp] $Object"
        Microsoft.PowerShell.Utility\Write-Host $prefixed @args
    }
}

# Guard: must be launched via VideoDownloader.bat, not run directly (except for tests)
if (-not $env:VIDEODOWNLOADER_LAUNCHED -and -not $env:TESTING -and -not $env:CI) {
    Write-Host ""
    Write-Host "  Run VideoDownloader.bat to start the application." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

$script:InstanceMutex = $null
$script:OwnsInstanceMutex = $false
if (-not $env:TESTING -and -not $env:CI) {
    try {
        # Create without initially owning — use WaitOne(0) so we handle
        # AbandonedMutexException (previous owner was killed) gracefully.
        $script:InstanceMutex = [System.Threading.Mutex]::new($false, 'Local\VideoDownloader.ClipboardWatcher')
        $acquired = $false
        try {
            $acquired = $script:InstanceMutex.WaitOne(0)
        } catch [System.Threading.AbandonedMutexException] {
            # Previous watcher was force-killed without releasing — we inherit ownership.
            $acquired = $true
        }
        $script:OwnsInstanceMutex = $acquired
    } catch {
        Write-Host "[X] Could not initialize the single-instance lock: $_" -ForegroundColor Red
        exit 1
    }

    if (-not $script:OwnsInstanceMutex) {
        Write-Host "[!] VideoDownloader is already running. Close the existing watcher before launching another window." -ForegroundColor Yellow
        exit 0
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web


# Script lives in lib\ — resolve root as parent so all data files land correctly
$BaseDir      = Split-Path $PSScriptRoot -Parent
$DownloadsDir = Join-Path $BaseDir "videos"
$HistoryFile  = Join-Path $BaseDir "download_history.json"
$LogFile      = Join-Path $BaseDir "yt-dlp.log"
$VersionFile  = Join-Path $BaseDir "VERSION"
$MaxJobs      = 3
$MaxJobHours  = 4       # Kill stalled jobs after this many hours
$MaxHistory   = 5000    # Rolling cap; trimmed to half when exceeded
$MaxLogMB     = 10      # Rotate log file after this size
$MaxClipLen   = 8192    # Ignore clipboard payloads larger than this
$ConfigFile   = Join-Path $BaseDir "config.json"
. (Join-Path $PSScriptRoot 'Write-ErrorLog.ps1')


$ScriptVersion = try {
    (Get-Content $VersionFile -Raw -ErrorAction Stop).Trim()
} catch {
    "unknown"
}

# Import desktop notification helper
. (Join-Path $PSScriptRoot 'Show-DesktopNotification.ps1')

# --- Binary hash pinning ----------------------------------------------------
# SHA-256 of the yt-dlp binary is stored in yt-dlp-pin.json on first run.
# Hash change + version change => winget upgrade  (warns, prompts to accept)
# Hash change + same version   => binary substitution (hard abort)
$PinFile = Join-Path $BaseDir "yt-dlp-pin.json"

# --- Resolve & verify yt-dlp ------------------------------------------------

# --- Strict schema validation for yt-dlp-pin.json ---
$ytDlpCmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
if (-not $ytDlpCmd) {
    Write-Host "[X] yt-dlp not found on PATH." -ForegroundColor Red
    exit 1
}
$ytDlpPath = $ytDlpCmd.Source

# Authenticode: only reject actively bad signatures (tampered / untrusted CA).
# NotSigned is allowed — yt-dlp does not ship with an Authenticode signature.
$sig = Get-AuthenticodeSignature $ytDlpPath
if ($sig.Status -in 'HashMismatch', 'NotTrusted') {
    Write-Host "[X] yt-dlp Authenticode check failed ($($sig.Status)) — possible tampering. Aborting." -ForegroundColor Red
    exit 1
}

# SHA-256 hash pinning — works regardless of whether the binary is signed
$CurrentHash    = (Get-FileHash $ytDlpPath -Algorithm SHA256).Hash
$CurrentVersion = try { (& $ytDlpPath --version 2>$null).Trim() } catch { "unknown" }

function Test-YtDlpPinSchema {
    param($pin)
    return (
        $null -ne $pin -and
        $pin.PSObject.Properties["Hash"] -and
        $pin.PSObject.Properties["Version"] -and
        $pin.PSObject.Properties["PinnedAt"] -and
        ($pin.Hash -is [string]) -and ($pin.Hash -match '^[A-Fa-f0-9]{64}$') -and
        ($pin.Version -is [string]) -and ($pin.Version.Length -gt 0) -and
        ($pin.PinnedAt -is [string]) -and ($pin.PinnedAt.Length -gt 0)
    )
}

if (Test-Path $PinFile) {
    $pin = try {
        $raw = Get-Content $PinFile -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if (-not (Test-YtDlpPinSchema $obj)) { throw "Invalid yt-dlp-pin.json schema" }
        $obj
    } catch {
        Write-Host "[!] yt-dlp-pin.json is corrupt, unreadable, or invalid schema — re-bootstrapping." -ForegroundColor Yellow
        $null
    }

    if (-not $pin) {
        # Corrupt or legacy thumbprint-based pin — re-bootstrap with hash
        [PSCustomObject]@{
            Hash     = $CurrentHash
            Version  = $CurrentVersion
            PinnedAt = (Get-Date -Format 'u')
        } | ConvertTo-Json | Set-Content $PinFile -Encoding UTF8
        Write-Host "[OK] yt-dlp pin re-bootstrapped (SHA-256)." -ForegroundColor Green
    } elseif ($CurrentHash -ne $pin.Hash) {
        Write-Host ""
        Write-Host "[!] yt-dlp binary has changed since last run." -ForegroundColor Yellow
        Write-Host "    Pinned  : v$($pin.Version)  [$($pin.Hash.Substring(0,16))...]" -ForegroundColor Yellow
        Write-Host "    Current : v$CurrentVersion  [$($CurrentHash.Substring(0,16))...]" -ForegroundColor Yellow

        if ($CurrentVersion -eq $pin.Version) {
            # Same version, different hash — strong indicator of binary substitution
            Write-Host ""
            Write-Host "[X] Version is unchanged but binary content differs." -ForegroundColor Red
            Write-Host "    This may indicate a supply-chain compromise. Aborting." -ForegroundColor Red
            Write-Host "    If you intentionally replaced yt-dlp, delete yt-dlp-pin.json to re-bootstrap." -ForegroundColor Red
            exit 1
        }

        # Different version — consistent with a winget upgrade
        Write-Host ""
        Write-Host "[!] Version change detected — consistent with a winget upgrade." -ForegroundColor Yellow
        Write-Host "    Pinned at: $($pin.PinnedAt)" -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "Accept new binary and update pin? [Y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-Host "[X] New binary not accepted. Aborting." -ForegroundColor Red
            exit 1
        }

        [PSCustomObject]@{
            Hash     = $CurrentHash
            Version  = $CurrentVersion
            PinnedAt = (Get-Date -Format 'u')
        } | ConvertTo-Json | Set-Content $PinFile -Encoding UTF8
        Write-Host "[OK] Pin updated to new binary hash." -ForegroundColor Green
    }
} else {
    # First run: bootstrap the pin file from the currently installed binary
    [PSCustomObject]@{
        Hash     = $CurrentHash
        Version  = $CurrentVersion
        PinnedAt = (Get-Date -Format 'u')
    } | ConvertTo-Json | Set-Content $PinFile -Encoding UTF8
    Write-Host "[OK] yt-dlp pin bootstrapped (SHA-256) — no manual setup required." -ForegroundColor Green
}

Write-Host "[OK] yt-dlp verified: v$CurrentVersion ($($CurrentHash.Substring(0,16))...)" -ForegroundColor Green


# --- Bootstrap dirs / history -----------------------------------------------
function Test-OutputDir {
    param($dir)
    try {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
        }
        $testFile = Join-Path $dir ([System.IO.Path]::GetRandomFileName())
        Set-Content -Path $testFile -Value 'test' -Encoding UTF8 -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Host "[X] Output directory is not writable: $dir" -ForegroundColor Red
        try { Write-ErrorLog "[X] Output directory is not writable: $dir" } catch {}
        exit 1
    }
}

$null = Test-OutputDir $DownloadsDir  # $null suppresses the $true return value; the call is for its side-effects (create dir, write-test)

# HashSet for O(1) contains-check; List preserves insertion order for trimming
$DownloadedUrls = [System.Collections.Generic.HashSet[string]]::new()
$DownloadedList = [System.Collections.Generic.List[string]]::new()
$PendingQueue   = [System.Collections.Generic.Queue[string]]::new()

try {
    if (Test-Path $HistoryFile) {
        (Get-Content $HistoryFile -Raw | ConvertFrom-Json) | ForEach-Object {
            if ($DownloadedUrls.Add($_)) { $DownloadedList.Add($_) }
        }
        Write-Host "[OK] Loaded $($DownloadedList.Count) history entries." -ForegroundColor Green
    }
} catch {
    Write-Host "[!] History file corrupt — starting fresh." -ForegroundColor Yellow
}

# Maps job ID -> URL so the reaper can commit/release history correctly
$JobUrlMap = [System.Collections.Generic.Dictionary[int,string]]::new()

# --- Helpers ----------------------------------------------------------------
function Write-Log {
    param([string]$Entry)
    try {
        if ((Get-Item $LogFile -ErrorAction SilentlyContinue).Length -gt ($MaxLogMB * 1MB)) {
            Move-Item $LogFile "$LogFile.old" -Force
            Write-Host "[!] Log rotated (exceeded ${MaxLogMB} MB)." -ForegroundColor DarkYellow
        }
        Add-Content -Path $LogFile -Value $Entry -Encoding UTF8
    } catch {
        Write-Host "[!] Write-Log error: $_" -ForegroundColor Red
        try { Write-ErrorLog "[!] Write-Log error: $_" } catch {}
    }
}

function Save-History {
    try {
        if ($DownloadedUrls.Count -gt $MaxHistory) {
            $keep = $DownloadedList | Select-Object -Last ([int]($MaxHistory / 2))
            $DownloadedUrls.Clear()
            $DownloadedList.Clear()
            foreach ($u in $keep) {
                [void]$DownloadedUrls.Add($u)
                $DownloadedList.Add($u)
            }
            Write-Host "[!] History trimmed to $($DownloadedList.Count) entries." -ForegroundColor DarkYellow
        }
        $Temp = "$HistoryFile.tmp"
        $DownloadedList | ConvertTo-Json | Set-Content $Temp -Encoding UTF8
        Move-Item -Path $Temp -Destination $HistoryFile -Force
    } catch {
        Write-Host "[!] Save-History error: $_" -ForegroundColor Red
        try { Write-ErrorLog "[!] Save-History error: $_" } catch {}
    }
}

function Strip-YouTubeTimestamp {
    param([string]$Url)
    try {
        $builder        = [System.UriBuilder]::new($Url)
        $query          = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        $query.Remove('t')
        $builder.Query  = $query.ToString()
        return $builder.Uri.AbsoluteUri
    } catch {
        return $Url   # Return original on any parse failure
    }
}

function Test-PathTraversal {
    param($path)
    # Disallow .., absolute paths, or invalid chars
    if ($path -match '\.\.' -or $path -match '^[A-Za-z]:\\' -or $path -match '^[\\/]' -or $path -match '[<>:"|?*]') {
        return $false
    }
    return $true
}

function Start-Download {
    param([string]$Url)
    try {
        # If at capacity, park the URL; the reaper drains it when a slot opens
        if ((Get-Job -State Running).Count -ge $MaxJobs) {
            $PendingQueue.Enqueue($Url)
            Write-Host "[~] Queue full ($MaxJobs active). Parked: $Url" -ForegroundColor DarkYellow
            return
        }

        $IsPlaylist = $Url -match "list="
        $Playlist   = if ($IsPlaylist) { "--yes-playlist" } else { "--no-playlist" }
        $Template   = if ($IsPlaylist) {
            Join-Path $DownloadsDir "%(playlist_title)s\%(playlist_index)03d - %(title)s.%(ext)s"
        } else {
            Join-Path $DownloadsDir "%(title)s.%(ext)s"
        }

        # Path traversal guard: only needed for user-supplied values.
        # $Template and $DownloadsDir are script-internal; the URL is protected by
        # '--' and '--restrict-filenames' passed to yt-dlp.
        $null = Test-OutputDir $DownloadsDir  # re-check before each job in case the dir was removed at runtime

        $YtDlpArgs = @(
            "-f",  "bv*+ba/b",
            "--merge-output-format", "mkv",
            "--remux-video", "mkv",
            "--download-archive", "archive.txt",
            "--embed-metadata",
            "--embed-chapters",
            "--embed-thumbnail",
            "--concurrent-fragments", "4",
            "--js-runtimes", "deno",
            "--restrict-filenames",   # Guarantees filesystem-safe names
            "-o", $Template,
            $Playlist,
            "--", $Url                # '--' prevents URLs starting with '-' being parsed as flags
        )

        Write-Host "[+] Queuing: $Url" -ForegroundColor Cyan
        $job = Start-Job -ScriptBlock { param($exe, $a) & $exe @a } -ArgumentList $ytDlpPath, $YtDlpArgs
        $JobUrlMap[$job.Id] = $Url

        # Guard against duplicate queuing while the job is in flight;
        # history is only persisted once the job completes successfully.
        [void]$DownloadedUrls.Add($Url)
    } catch {
        Write-Host "[!] Start-Download error: $_" -ForegroundColor Red
        try { Write-ErrorLog "[!] Start-Download error: $_" } catch {}
    }
}

function Process-Url {
    param([string]$Raw)
    if ($Raw.Length -gt $MaxClipLen) {
        Write-Host "[!] Input too large ($($Raw.Length) chars) — skipped." -ForegroundColor DarkYellow
        return
    }
    foreach ($Url in ($Raw -split "\s+" | Where-Object { $_ -match "^https?://" })) {
        try {
            $u = [System.Uri]$Url
            $h = $u.Host.ToLower()
            if (-not ($AllowedHosts | Where-Object { $h -eq $_ -or $h.EndsWith(".$_") })) { continue }
            if ($h -match "youtu") { $Url = Strip-YouTubeTimestamp $Url }
        } catch { continue }
        if ($DownloadedUrls.Contains($Url)) {
            Write-Host "[=] Already downloaded: $Url" -ForegroundColor DarkGray
            continue
        }
        Start-Download $Url
    }
}

# --- Load config ------------------------------------------------------------

# --- Menu-driven mode selection (persist last-used mode) ---
$DefaultHosts = @("youtube.com", "youtu.be", "twitch.tv", "vimeo.com", "tiktok.com")

# Load config or create default if missing/corrupt
function Test-ConfigSchema {
    param($cfg)
    if ($null -eq $cfg) { return $false }
    if (-not $cfg.PSObject.Properties["customHosts"]) { return $false }
    if (-not ($cfg.customHosts -is [System.Collections.IEnumerable])) { return $false }
    if ($cfg.PSObject.Properties["clipboardMonitoring"] -and ($cfg.clipboardMonitoring -ne $true -and $cfg.clipboardMonitoring -ne $false)) { return $false }
    if ($cfg.PSObject.Properties["showStartupMenu"] -and ($cfg.showStartupMenu -ne $true -and $cfg.showStartupMenu -ne $false)) { return $false }
    if ($cfg.PSObject.Properties["desktopNotifications"] -and ($cfg.desktopNotifications -ne $true -and $cfg.desktopNotifications -ne $false)) { return $false }
    $hostCount = 0
    foreach ($h in $cfg.customHosts) {
        if (-not ($h -is [string])) { return $false }
        $hostCount++
    }
    if ($hostCount -gt 50) { return $false }
    return $true
}

function Load-Config {
    param([switch]$Silent)
    $cfg = $null
    try {
        if (Test-Path $ConfigFile) {
            $raw = Get-Content $ConfigFile -Raw
            $obj = $raw | ConvertFrom-Json
            if (-not (Test-ConfigSchema $obj)) { throw "Invalid config.json schema" }
            $cfg = $obj
        }
    } catch {
        if (-not $Silent) { Write-Host "[!] config.json unreadable or invalid — using default allowlist." -ForegroundColor Yellow }
    }
    if (-not $cfg) {
        $cfg = [PSCustomObject]@{
            customHosts = @()
            clipboardMonitoring = $false
            showStartupMenu = $false
        }
    }
    if (-not $cfg.PSObject.Properties['clipboardMonitoring']) {
        $cfg | Add-Member -NotePropertyName clipboardMonitoring -NotePropertyValue $false
    }
    if (-not $cfg.PSObject.Properties['showStartupMenu']) {
        $cfg | Add-Member -NotePropertyName showStartupMenu -NotePropertyValue $false
    }
    return $cfg
}

# Save config helper
function Save-Config {
    param($cfg)
    $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
}

function Get-StartupState {
    param(
        $cfg,
        [switch]$ShowMenu
    )

    $clipboardMonitoring = $false
    if ($null -ne $cfg.PSObject.Properties['clipboardMonitoring']) {
        $clipboardMonitoring = [bool]$cfg.clipboardMonitoring
    }

    $showStartupMenu = $false
    if ($null -ne $cfg.PSObject.Properties['showStartupMenu']) {
        $showStartupMenu = [bool]$cfg.showStartupMenu
    }

    return [PSCustomObject]@{
        ClipboardMonitoring = $clipboardMonitoring
        ShowMenu = ($ShowMenu -or $showStartupMenu)
    }
}


$cfg = Load-Config
$startupState = Get-StartupState -cfg $cfg -ShowMenu:$ShowMenu

# In test mode, stop here — all functions are defined and variables are set;
# skip interactive menu and main loop entirely.
if ($env:TESTING) {
    $AllowedHosts = $DefaultHosts
    $ClipboardMonitoring = $startupState.ClipboardMonitoring
    $DesktopNotifications = $false
    return
}

if ($startupState.ShowMenu) {
    $lastMode = if ($startupState.ClipboardMonitoring) { 'Clipboard' } else { 'Manual' }

    # Build menu: last-used mode is always first, add option to add site
    if ($lastMode -eq 'Clipboard') {
        $menu = @( 'Clipboard monitoring — automatically download any supported URL you copy',
                   'Manual input — paste a URL and press Enter each time',
                   'Add a supported site (custom host)')
        $modeMap = @{ '1' = $true; '2' = $false }
    } else {
        $menu = @( 'Manual input — paste a URL and press Enter each time',
                   'Clipboard monitoring — automatically download any supported URL you copy',
                   'Add a supported site (custom host)')
        $modeMap = @{ '1' = $false; '2' = $true }
    }


    # --- Startup menu (no timestamp) ---
    while ($true) {
        Write-Host "" -NoTimestamp
        Write-Host "  Select mode" -ForegroundColor Cyan -NoTimestamp
        Write-Host "  ───────────────────────────────────────────────" -ForegroundColor DarkGray -NoTimestamp
        for ($i = 0; $i -lt $menu.Count; $i++) {
            Write-Host "  [$($i+1)] $($menu[$i])" -ForegroundColor White -NoTimestamp
        }
        Write-Host "" -NoTimestamp
        do {
            $choice = (Read-Host "  Choose option [1/2/3]").Trim()
        } until ($choice -in '1', '2', '3')
        if ($choice -eq '3') {
            $HostRx = '^(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$'
            $newHost = (Read-Host "  Enter the domain (for example: youtube.com or vimeo.com; do NOT include 'www.')").ToLower().Trim()
            if ($newHost -match $HostRx) {
                if ($cfg.customHosts -notcontains $newHost) {
                    $cfg.customHosts += $newHost
                    Save-Config $cfg
                    Write-Host "[OK] Added: $newHost" -ForegroundColor Green -NoTimestamp
                } else {
                    Write-Host "[!] That site is already in your custom hosts." -ForegroundColor Yellow -NoTimestamp
                }
            } else {
                Write-Host "[!] Invalid domain. Please enter a valid hostname (e.g. example.com)." -ForegroundColor Red -NoTimestamp
            }
            continue
        } else {
            $ClipboardMonitoring = $modeMap[$choice]
            $cfg.clipboardMonitoring = $ClipboardMonitoring
            Save-Config $cfg
            $modeLabel = if ($ClipboardMonitoring) { "Clipboard monitoring" } else { "Manual input" }
            Write-Host "[OK] Mode set to: $modeLabel" -ForegroundColor Green -NoTimestamp
            Write-Host "" -NoTimestamp
            break
        }
    }
} else {
    $ClipboardMonitoring = $startupState.ClipboardMonitoring
    $modeLabel = if ($ClipboardMonitoring) { "Clipboard monitoring" } else { "Manual input" }
    Write-Host "[OK] Auto-starting last mode: $modeLabel" -ForegroundColor Green -NoTimestamp
    Write-Host "[~] Run VideoDownloader.bat --menu to change mode or add custom sites." -ForegroundColor DarkYellow -NoTimestamp
    Write-Host "" -NoTimestamp
}

# Strict hostname validation: labels of a-z0-9/hyphens, letter-only TLD.
# Rejects IP addresses, wildcards, non-strings, and malformed entries.
$HostRx      = '^(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$'
$CustomHosts = @(
    $cfg.customHosts |
    Select-Object -First 50 |                          # cap: prevent main-loop perf impact
    Where-Object { $_ -is [string] } |                 # reject non-strings (numbers, objects)
    ForEach-Object { $_.ToLower().Trim() } |           # normalise before matching
    Where-Object { $_ -match $HostRx }
)
$Rejected    = $cfg.customHosts.Count - $CustomHosts.Count
if ($Rejected -gt 0) {
    Write-Host "[!] config.json: $Rejected customHosts entr$(if($Rejected -eq 1){'y'}else{'ies'}) rejected (invalid hostname or over 50-entry cap)." -ForegroundColor Yellow
}
$AllowedHosts = ($DefaultHosts + $CustomHosts) | Select-Object -Unique
if ($CustomHosts.Count -gt 0) {
    Write-Host "[OK] Custom hosts loaded: $($CustomHosts -join ', ')" -ForegroundColor Green
}
$DesktopNotifications = if ($null -ne $cfg.PSObject.Properties['desktopNotifications']) { [bool]$cfg.desktopNotifications } else { $false }

# --- Main loop --------------------------------------------------------------
Write-Host "ClipboardWatcher v$ScriptVersion" -ForegroundColor Cyan
if ($ClipboardMonitoring) {
    Write-Host "Mode: Clipboard monitoring  (Ctrl+C to stop)" -ForegroundColor Yellow
} else {
    Write-Host "Mode: Manual input  (paste a URL and press Enter; Ctrl+C to stop)" -ForegroundColor Yellow
}

$LastClipboardText = $null

try {
    $script:ShouldExit = $false
    # Trap Ctrl+C and other terminating errors for cleanup
    trap {
        Write-Host "[!] Caught terminating error or Ctrl+C. Cleaning up jobs..." -ForegroundColor Yellow
        $script:ShouldExit = $true
        continue
    }
    while (-not $script:ShouldExit) {
        try {
            # 1. Reap: completed, failed, and timed-out jobs -------------------------
            Get-Job | Where-Object {
                $_.State -in 'Completed', 'Failed' -or
                ($_.State -eq 'Running' -and ((Get-Date) - $_.PSBeginTime).TotalHours -gt $MaxJobHours)
            } | ForEach-Object {
                try {
                    if ($_.State -eq 'Running') {
                        Stop-Job $_ -ErrorAction SilentlyContinue
                        Write-Host "[!] Job $($_.Id) exceeded ${MaxJobHours}h — killed." -ForegroundColor DarkYellow
                        $timeoutMsg = "[$(Get-Date -Format 'u')] TIMEOUT — Job $($_.Id)"
                        Write-Log  $timeoutMsg
                        Write-ErrorLog $timeoutMsg
                        if ($DesktopNotifications) {
                            Show-DesktopNotification -Title "VideoDownloader: Job Timeout" -Message $timeoutMsg -Type Warning
                        }
                        if ($JobUrlMap.ContainsKey($_.Id)) {
                            [void]$DownloadedUrls.Remove($JobUrlMap[$_.Id])
                            Write-Host "    Removed from history — paste again to retry." -ForegroundColor DarkYellow
                            $JobUrlMap.Remove($_.Id)
                        }
                    } elseif ($_.State -eq 'Failed') {
                        $err = Receive-Job $_ 2>&1
                        $failMsg = "[$(Get-Date -Format 'u')] FAILED — $err"
                        Write-Host "[X] Job $($_.Id) failed: $err" -ForegroundColor Red
                        Write-Log  $failMsg
                        Write-ErrorLog $failMsg
                        if ($DesktopNotifications) {
                            Show-DesktopNotification -Title "VideoDownloader: Download Failed" -Message $failMsg -Type Error
                        }
                        if ($JobUrlMap.ContainsKey($_.Id)) {
                            [void]$DownloadedUrls.Remove($JobUrlMap[$_.Id])
                            Write-Host "    Removed from history — paste again to retry." -ForegroundColor DarkYellow
                            $JobUrlMap.Remove($_.Id)
                        }
                    } else {
                        $out = Receive-Job $_
                        $okMsg = "[$(Get-Date -Format 'u')] OK`n$out"
                        Write-Host "[✓] Job $($_.Id) finished." -ForegroundColor Green
                        Write-Log  $okMsg
                        # Successes are not logged to error log or desktop notification
                        if ($JobUrlMap.ContainsKey($_.Id)) {
                            $doneUrl = $JobUrlMap[$_.Id]
                            $DownloadedList.Add($doneUrl)
                            Save-History
                            $JobUrlMap.Remove($_.Id)
                        }
                    }
                } catch {
                    Write-Host "[!] Exception during job reap: $_" -ForegroundColor Red
                    Write-ErrorLog "[!] Exception during job reap: $_"
                }
                Remove-Job $_ -ErrorAction SilentlyContinue
                [System.Media.SystemSounds]::Asterisk.Play()

                # Drain one parked URL now that a slot has opened
                if ($PendingQueue.Count -gt 0) {
                    $next = $PendingQueue.Dequeue()
                    Write-Host "[>] Resuming parked: $next" -ForegroundColor Cyan
                    Start-Download $next
                }
            }

            # 2. Input: clipboard or manual ------------------------------------------
            if ($ClipboardMonitoring) {
                try {
                    # Single Forms API call eliminates the TOCTOU race between ContainsText() and Get-Clipboard that existed in the previous version.
                    $Raw = [System.Windows.Forms.Clipboard]::GetText().Trim()
                } catch {
                    Write-Host "[!] Clipboard access error: $_" -ForegroundColor Red
                    Write-ErrorLog "[!] Clipboard access error: $_"
                    $Raw = $null
                }
                if ($Raw -and $Raw -ne $LastClipboardText) {
                    $LastClipboardText = $Raw
                    try {
                        Process-Url $Raw
                    } catch {
                        Write-Host "[!] Exception in Process-Url: $_" -ForegroundColor Red
                        Write-ErrorLog "[!] Exception in Process-Url: $_"
                    }
                }
                Start-Sleep -Seconds 1
            } else {
                try {
                    $Raw = (Read-Host "`nURL").Trim()
                } catch {
                    Write-Host "[!] Input error: $_" -ForegroundColor Red
                    Write-ErrorLog "[!] Input error: $_"
                    $Raw = $null
                }
                if ($Raw) {
                    try {
                        Process-Url $Raw
                    } catch {
                        Write-Host "[!] Exception in Process-Url: $_" -ForegroundColor Red
                        Write-ErrorLog "[!] Exception in Process-Url: $_"
                    }
                }
            }
        } catch {
            Write-Host "[!] Unhandled exception in main loop: $_" -ForegroundColor Red
            Write-ErrorLog "[!] Unhandled exception in main loop: $_"
        }
    }
} finally {
    Write-Host "[~] Cleaning up all background jobs..." -ForegroundColor Yellow
    Get-Job | ForEach-Object {
        try {
            Stop-Job $_ -ErrorAction SilentlyContinue
            Remove-Job $_ -ErrorAction SilentlyContinue
        } catch {
            Write-Host "[!] Exception during job cleanup: $_" -ForegroundColor Red
            Write-ErrorLog "[!] Exception during job cleanup: $_"
        }
    }
    if ($script:OwnsInstanceMutex -and $null -ne $script:InstanceMutex) {
        try {
            $script:InstanceMutex.ReleaseMutex()
        } catch {}
    }
    if ($null -ne $script:InstanceMutex) {
        $script:InstanceMutex.Dispose()
    }
    Write-Host "[~] Cleanup complete. Exiting." -ForegroundColor Yellow
}