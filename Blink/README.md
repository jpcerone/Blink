# Blink ⚡

A minimal, keyboard-driven application launcher for macOS. Designed for speed and simplicity.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Why Blink?

- **Instant**: Sub-100ms launch time
- **Keyboard-first**: No mouse required
- **Zero overhead**: Quits immediately after use
- **skhd integration**: Works with your existing hotkey setup
- **Smart search**: Fuzzy matching finds what you need

## Installation

### Quick Install

1. Download `Blink.app` from [Releases](https://github.com/yourusername/blink/releases)
2. Drag to `/Applications`
3. Add to your skhd config (see below)

### Build from Source

```bash
git clone https://github.com/yourusername/blink
cd blink
xcodebuild -scheme Blink -configuration Release
cp -r build/Release/Blink.app /Applications/
```

## Setup

Add to your `~/.config/skhd/skhdrc`:

```bash
alt - space : open -a Blink
```

Reload skhd:
```bash
skhd --reload
```

## Usage

1. Press your hotkey (e.g., `⌥ Space`)
2. Type to search
3. `↑` `↓` to navigate
4. `Enter` to launch
5. `Esc` to cancel

That's it.

## Configuration

Blink creates config files at `~/.config/blink/`:

### `blink.config`

```toml
# Add custom applications
[[custom_apps]]
name = "My Script"
path = "/Users/you/scripts/deploy.sh"
]
```

### `single-instance-apps.config`

Controls single vs multi-instance launching:

```
# Blink Single-Instance Apps
# If nothing is happening when selecting a specific app, try adding to this list.
# Apps listed here will NOT use the -n flag when launched
# This means they'll activate existing windows instead of opening new ones
#
# Add one app name per line (case-sensitive, must match exactly)
# Lines starting with # are comments

Finder
System Settings
System Preferences
Activity Monitor
```
## How It Works

### App Discovery

Scans:
- `/Applications`
- `/System/Applications`  
- `~/Applications`
- `/System/Library/CoreServices` (Finder, etc.)
- Custom paths from config

### Smart Launching

- **Multi-instance apps** (browsers, editors): Opens new window with `-n` flag
- **Single-instance apps** (Finder, Mail): Activates existing instance
- **Custom apps**: Respects your cache.json preferences

### Search Algorithm

1. Exact match (1000 pts)
2. Starts with query (900 pts)
3. Contains query (500 pts)
4. Fuzzy match (variable)

## Requirements

- macOS 13.0+ (Ventura or later)
- [skhd](https://github.com/koekeishiya/skhd) (recommended)

## Troubleshooting

**App doesn't launch**
- Ensure Blink is in `/Applications`
- Check skhd is running: `brew services list`

**Missing apps**
- Add to `scan_paths` in `~/.config/blink/blink.config`
- Or add as `custom_apps`

**Wrong window behavior**
- Update `~/.config/blink/cache.json`
- Add app to `singleInstanceApps` or `multiInstanceApps`

## Development

```bash
# Clone
git clone https://github.com/yourusername/blink

# Open in Xcode
open Blink.xcodeproj

# Build
⌘B
```

### Project Structure

```
Blink/
├── BlinkApp.swift           # App lifecycle
├── LauncherView.swift       # UI components
├── LauncherViewModel.swift  # Search & launch logic
├── ConfigManager.swift      # Config file parsing
└── CacheManager.swift       # Instance cache
```

## Contributing

Contributions welcome! Please:
- Keep changes focused
- Test on macOS 13+
- Follow existing code style
- Update README if needed

## Roadmap

- [ ] Homebrew formula
- [ ] App icons/branding
- [ ] Frequency-based ranking
- [ ] Action shortcuts (⌘K for preferences, etc.)
- [ ] Plugin system

## License

MIT License - see [LICENSE](LICENSE) for details

## Credits

Built with SwiftUI for modern macOS.

Inspired by [Alfred](https://www.alfredapp.com/), [Raycast](https://www.raycast.com/), and the skhd community.

---

**[⬇️ Download Latest Release](https://github.com/yourusername/blink/releases)** | **[🐛 Report Bug](https://github.com/yourusername/blink/issues)** | **[💡 Request Feature](https://github.com/yourusername/blink/issues)**
