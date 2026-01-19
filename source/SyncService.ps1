# GuildShopSync Background Service
# Watches for price scans and automatically uploads to guild website

$ApiUrl = "https://tbcguild.duckdns.org/api/consumes/prices"
$WatchPath = $env:GUILDSHOPSYNC_WOWPATH + "\WTF\Account"

Add-Type -AssemblyName System.Windows.Forms

function Show-Notification {
    param([string]$Title, [string]$Message, [string]$Type = "Info")

    $balloon = New-Object System.Windows.Forms.NotifyIcon
    $balloon.Icon = [System.Drawing.SystemIcons]::Information
    $balloon.BalloonTipTitle = $Title
    $balloon.BalloonTipText = $Message
    $balloon.Visible = $true
    $balloon.ShowBalloonTip(5000)
    Start-Sleep -Seconds 6
    $balloon.Dispose()
}

function Upload-Prices {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }

    # Check for trigger flag
    if ($content -notmatch '\["triggerUpload"\]\s*=\s*true') { return }

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

    if ($prices.Count -eq 0) { return }

    # Upload to website
    $payload = @{
        prices = $prices
        source = "GuildShopSync-addon"
        updatedBy = "GuildShopSync"
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Put -ContentType "application/json" -Body $payload -TimeoutSec 30

        if ($response.success) {
            # Clear trigger flag
            $content = $content -replace '\["triggerUpload"\]\s*=\s*true', '["triggerUpload"] = false'
            $content | Set-Content $FilePath -NoNewline

            # Show success notification
            Show-Notification -Title "Guild Shop Sync" -Message "Uploaded $($prices.Count) prices to guild website!"
        }
    } catch {
        Show-Notification -Title "Guild Shop Sync" -Message "Upload failed. Check internet connection." -Type "Error"
    }
}

# Find SavedVariables files
$svFiles = Get-ChildItem -Path $WatchPath -Recurse -Filter "GuildShopSync.lua" -ErrorAction SilentlyContinue
if ($svFiles.Count -eq 0) {
    # No saved variables yet - wait for first scan
    while ($true) {
        Start-Sleep -Seconds 10
        $svFiles = Get-ChildItem -Path $WatchPath -Recurse -Filter "GuildShopSync.lua" -ErrorAction SilentlyContinue
        if ($svFiles.Count -gt 0) { break }
    }
}

# Watch all found SavedVariables directories
$watchers = @()
foreach ($svFile in $svFiles) {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $svFile.DirectoryName
    $watcher.Filter = "GuildShopSync.lua"
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
    $watcher.EnableRaisingEvents = $true

    $action = {
        Start-Sleep -Milliseconds 1000
        Upload-Prices -FilePath $Event.SourceEventArgs.FullPath
    }

    Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
    $watchers += $watcher
}

# Keep running
while ($true) { Start-Sleep -Seconds 60 }
