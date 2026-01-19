# GuildShopSync

A World of Warcraft addon and background sync service for TurtleWoW that automatically uploads Auction House prices to a guild website.

## Features

- In-game button to scan all guild consumable prices from the Auction House
- Background Windows service that automatically uploads prices to the guild website
- Auto-starts on Windows logon
- Clean installer with easy uninstall via Windows Settings

## Installation

1. Download the latest release from [Releases](../../releases)
2. Extract the zip file
3. Run `GuildShopSync-Setup-v2.5.exe`
4. Select your TurtleWoW installation folder
5. Done! The addon and sync service are installed automatically

## Usage

1. Open World of Warcraft (TurtleWoW)
2. Go to the Auction House
3. Click the "Sync Prices" button (bottom-right of AH window)
4. Wait for the scan to complete
5. Click "Reload UI & Sync" when prompted
6. Prices are automatically uploaded to the guild website

## Uninstalling

**Option 1: Windows Settings**
- Open Windows Settings > Apps > Installed Apps
- Find "GuildShopSync"
- Click Uninstall

**Option 2: Start Menu**
- Open Start Menu
- Find "GuildShopSync" folder
- Click "Uninstall GuildShopSync"

## Building from Source

### Requirements
- [Inno Setup 6](https://jrsoftware.org/isdl.php)
- Windows 10 or later

### Build Steps
1. Clone this repository
2. Run `compile.ps1` in PowerShell
3. The installer will be created in the `output` folder

## Project Structure

```
GuildShopSync-Installer/
├── source/
│   ├── GuildShopSync.lua    # WoW addon - AH scanner
│   ├── GuildShopSync.toc    # WoW addon manifest
│   ├── SyncService.ps1      # Background upload service
│   └── README.txt           # End-user instructions
├── GuildShopSync.iss        # Inno Setup script
├── compile.ps1              # Build script
├── LICENSE                  # MIT License
└── README.md                # This file
```

## How It Works

1. **In-Game Addon**: Scans Auction House prices for guild consumables and saves them to WoW's SavedVariables
2. **Background Service**: Watches the SavedVariables file for changes and uploads prices to the guild API when triggered
3. **Website Integration**: The guild website receives price updates via REST API

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Pull requests welcome! Please ensure any changes maintain compatibility with TurtleWoW (vanilla 1.12 client).

## Support

For help, contact guild leadership on Discord.
