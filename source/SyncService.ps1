# GuildShopSync Background Service v2.9
# Watches for price scans and automatically uploads to guild website
# System tray icon for status visibility

$ApiUrl = "https://tbcguild.duckdns.org/api/consumes/prices"
$LogDir = "$env:LOCALAPPDATA\GuildShopSync"
$LogFile = "$LogDir\service.log"

# Ensure log directory exists
New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue | Out-Null

# ===== Single Instance Check =====
# Prevent duplicate tray icons by ensuring only one SyncService can run at a time.
# Uses a named mutex - if another instance already holds it, this one exits immediately.
$mutex = New-Object System.Threading.Mutex($false, "Global\GuildShopSyncService")
if (-not $mutex.WaitOne(0)) {
    # Another instance is already running - exit silently
    exit 0
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $Message" | Out-File $LogFile -Append -ErrorAction SilentlyContinue
}

# ===== Get WoW Path =====
function Get-WoWPath {
    try {
        $regPath = Get-ItemProperty -Path "HKCU:\Software\GuildShopSync" -Name "WoWPath" -ErrorAction SilentlyContinue
        if ($regPath -and $regPath.WoWPath -and (Test-Path $regPath.WoWPath)) {
            return $regPath.WoWPath
        }
    } catch {}

    if ($env:GUILDSHOPSYNC_WOWPATH -and (Test-Path $env:GUILDSHOPSYNC_WOWPATH)) {
        return $env:GUILDSHOPSYNC_WOWPATH
    }

    $commonPaths = @(
        "C:\turtlewow",
        "D:\turtlewow",
        "C:\Games\turtlewow",
        "D:\Games\turtlewow",
        "$env:USERPROFILE\Documents\turtlewow",
        "C:\Program Files\turtlewow",
        "C:\Program Files (x86)\turtlewow"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path "$path\WoW.exe") {
            return $path
        }
    }

    return $null
}

# ===== Upload Logic =====
function Upload-Prices {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }

    if ($content -notmatch '\["triggerUpload"\]\s*=\s*true') { return }

    # Update tray status
    $script:statusItem.Text = "Status: Uploading prices..."
    $script:trayIcon.Text = "GuildShopSync - Uploading..."

    # Extract prices
    $prices = @{}
    if ($content -match '\["prices"\]\s*=\s*\{([^}]+)\}') {
        $pricesSection = $Matches[1]
        $pattern = '\["(\w+)"\]\s*=\s*(\d+)'
        $priceMatches = [regex]::Matches($pricesSection, $pattern)
        foreach ($match in $priceMatches) {
            $prices[$match.Groups[1].Value] = [int]$match.Groups[2].Value
        }
    }

    if ($prices.Count -eq 0) {
        $script:statusItem.Text = "Status: Watching for price scans"
        $script:trayIcon.Text = "GuildShopSync - Watching for scans"
        return
    }

    $payload = @{
        prices = $prices
        source = "GuildShopSync-addon"
        updatedBy = "GuildShopSync"
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Put -ContentType "application/json" -Body $payload -TimeoutSec 30

        if ($response.success) {
            $content = $content -replace '\["triggerUpload"\]\s*=\s*true', '["triggerUpload"] = false'
            $content | Set-Content $FilePath -NoNewline

            $script:uploadCount++
            $script:lastUploadTime = (Get-Date -Format 'h:mm tt')
            $script:statusItem.Text = "Status: Watching for price scans"
            $script:lastUploadItem.Text = "Last Upload: $($script:lastUploadTime)"
            $script:countItem.Text = "Uploads This Session: $($script:uploadCount)"
            $script:trayIcon.Text = "GuildShopSync - Last upload: $($script:lastUploadTime)"

            Write-Log "Uploaded $($prices.Count) prices successfully"

            $script:trayIcon.BalloonTipTitle = "Guild Shop Sync"
            $script:trayIcon.BalloonTipText = "Uploaded $($prices.Count) prices to guild website!"
            $script:trayIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
            $script:trayIcon.ShowBalloonTip(5000)
        }
    } catch {
        $script:statusItem.Text = "Status: Upload failed - retrying on next scan"
        $script:trayIcon.Text = "GuildShopSync - Upload failed"
        Write-Log "Upload failed: $_"

        $script:trayIcon.BalloonTipTitle = "Guild Shop Sync"
        $script:trayIcon.BalloonTipText = "Upload failed. Check internet connection."
        $script:trayIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
        $script:trayIcon.ShowBalloonTip(5000)
    }
}

# ===== Initialize =====

$WoWPath = Get-WoWPath
if (-not $WoWPath) {
    Write-Log "ERROR: Could not find TurtleWoW installation. Please reinstall GuildShopSync."
    exit 1
}

$WatchPath = "$WoWPath\WTF\Account"

if (-not (Test-Path $WatchPath)) {
    Write-Log "ERROR: WTF\Account folder not found at $WatchPath"
    exit 1
}

Write-Log "Service started. WoW path: $WoWPath"

# ===== System Tray Icon =====
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create a green circle icon (running indicator)
$bmp = New-Object System.Drawing.Bitmap(16, 16)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$g.FillEllipse([System.Drawing.Brushes]::LimeGreen, 1, 1, 14, 14)
$g.DrawEllipse([System.Drawing.Pens]::DarkGreen, 1, 1, 13, 13)
$g.Dispose()

$script:lastUploadTime = "Never"
$script:uploadCount = 0

$script:trayIcon = New-Object System.Windows.Forms.NotifyIcon
$script:trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
$script:trayIcon.Text = "GuildShopSync - Watching for scans"
$script:trayIcon.Visible = $true

# Context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$headerItem = $contextMenu.Items.Add("GuildShopSync v2.9")
$headerItem.Enabled = $false
$headerItem.Font = New-Object System.Drawing.Font($headerItem.Font, [System.Drawing.FontStyle]::Bold)

$contextMenu.Items.Add("-") | Out-Null

$script:statusItem = $contextMenu.Items.Add("Status: Watching for price scans")
$script:statusItem.Enabled = $false

$script:lastUploadItem = $contextMenu.Items.Add("Last Upload: Never")
$script:lastUploadItem.Enabled = $false

$script:countItem = $contextMenu.Items.Add("Uploads This Session: 0")
$script:countItem.Enabled = $false

$contextMenu.Items.Add("-") | Out-Null

$openLogItem = $contextMenu.Items.Add("Open Log Folder")
$openLogItem.add_Click({
    if (Test-Path $LogDir) {
        Start-Process explorer.exe $LogDir
    }
})

$contextMenu.Items.Add("-") | Out-Null

$exitItem = $contextMenu.Items.Add("Exit (restarts in ~1 min)")
$exitItem.add_Click({
    Write-Log "Service stopped by user via tray menu"
    $script:trayIcon.Visible = $false
    $script:trayIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$script:trayIcon.ContextMenuStrip = $contextMenu

# Double-click shows status balloon
$script:trayIcon.add_DoubleClick({
    $script:trayIcon.BalloonTipTitle = "GuildShopSync"
    $script:trayIcon.BalloonTipText = "Watching for price scans`nLast upload: $($script:lastUploadTime)`nUploads this session: $($script:uploadCount)"
    $script:trayIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $script:trayIcon.ShowBalloonTip(5000)
})

# ===== File Watcher =====
# Poll for SavedVariables changes on the UI thread (Timer instead of FileSystemWatcher).
# This ensures Upload-Prices can update the tray icon, counters, and balloon tips
# since it runs in the main script scope with full access to $script: variables.
$script:lastPollHashes = @{}
$pollTimer = New-Object System.Windows.Forms.Timer
$pollTimer.Interval = 3000  # Check every 3 seconds
$pollTimer.add_Tick({
    $svFiles = Get-ChildItem -Path $WatchPath -Recurse -Filter "GuildShopSync.lua" -ErrorAction SilentlyContinue
    foreach ($f in $svFiles) {
        $currentWrite = $f.LastWriteTime.Ticks
        $lastWrite = $script:lastPollHashes[$f.FullName]
        if ($lastWrite -ne $currentWrite) {
            $script:lastPollHashes[$f.FullName] = $currentWrite
            if ($lastWrite) {  # Skip first detection (initial scan)
                Upload-Prices -FilePath $f.FullName
            }
        }
    }
})
$pollTimer.Start()

Write-Log "Polling $WatchPath for GuildShopSync.lua changes (3s interval)"

# ===== Run Message Loop =====
# Application.Run processes Windows messages to keep tray icon responsive
$appContext = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appContext)

# Cleanup
$script:trayIcon.Visible = $false
$script:trayIcon.Dispose()
Write-Log "Service stopped"
