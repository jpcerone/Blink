# Blink Launcher

A minimal, keyboard-driven application launcher for macOS. Designed for integration with [yabai](https://github.com/koekeishiya/yabai) and [skhd](https://github.com/koekeishiya/skhd).

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Why Blink?

- **Instant**: Sub-100ms launch time
- **Keyboard-first**: No mouse required
- **Zero overhead**: Quits immediately after launching
- **Configurable**: Aliases, exclusions, and custom shortcuts
- **Smart search**: Fuzzy matching finds what you need

## Installation

### Homebrew (Recommended)

```bash
brew tap jpcerone/blink
brew install --cask blink-launcher
```

### Manual Install

1. Download `Blink.zip` from [Releases](https://github.com/jpcerone/BlinkLauncher/releases)
2. Extract and drag `Blink.app` to `/Applications`

### Build from Source

```bash
git clone https://github.com/jpcerone/BlinkLauncher
cd BlinkLauncher
xcodebuild -scheme Blink -configuration Release
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

1. Press your hotkey (e.g., `Option + Space`)
2. Type to search
3. `Up/Down` to navigate
4. `Enter` to launch
5. `Escape` to cancel

### Keyboard Shortcuts

While Blink is open:

| Shortcut | Action |
|----------|--------|
| `Cmd + ,` | Open config file |
| `Cmd + R` | Rescan applications |
| `Cmd + S` | Mark selected app as single-instance |

## Configuration

Config files are located at `~/.config/blink/`.

### blink.config

```toml
# Custom applications in non-standard locations
[[custom_apps]]
name = "My Script"
path = "~/scripts/deploy.app"

# Search aliases - type shortcuts to find apps faster
# App name must match exactly as shown in Blink
[[aliases]]
app = "Code"
shortcuts = ["vsc", "vscode", "editor"]

[[aliases]]
app = "Google Chrome"
shortcuts = ["chrome", "browser", "gc"]

# Hide apps from search results
exclude_apps = ["Migration Assistant", "Boot Camp Assistant"]

# Pattern-based exclusions (supports * wildcard)
exclude_patterns = ["*Helper*", "*Uninstaller*"]

# Keyboard shortcuts (modifier+key)
[shortcuts]
preferences = "cmd+,"
refresh = "cmd+r"
mark_single_instance = "cmd+s"

# Launch behavior
always_new_window = false    # Always open new instances
close_on_blur = true         # Quit when window loses focus
quit_after_launch = true     # Quit after launching an app
```

### single-instance-apps.config

Apps listed here activate existing windows instead of opening new ones:

```
# Lines starting with # are comments
Finder
System Settings
Activity Monitor
```

## How It Works

### App Discovery

Blink uses Spotlight (MDQuery) to find all installed applications, plus any custom apps defined in your config.

### Smart Launching

- **Multi-instance apps**: Opens new window with `-n` flag
- **Single-instance apps**: Activates existing instance
- Configurable via `single-instance-apps.config` or `Cmd + S`

### Search Algorithm

| Match Type | Score |
|------------|-------|
| Exact match | 1000 |
| Alias match | 950 |
| Starts with query | 900 |
| Partial alias match | 850 |
| Contains query | 500 |
| Fuzzy match | Variable |

## Requirements

- macOS 13.0+ (Ventura or later)
- [skhd](https://github.com/koekeishiya/skhd) (recommended for hotkey binding)

## Troubleshooting

**App doesn't launch**
- Ensure Blink is in `/Applications`
- Check skhd is running: `brew services list`

**Missing apps**
- Press `Cmd + R` to rescan
- Or add as `[[custom_apps]]` in config

**Wrong window behavior**
- Add app name to `~/.config/blink/single-instance-apps.config`
- Or select the app and press `Cmd + S`

**Alias not working**
- App name must match exactly as shown in Blink's search results
- Check with `Cmd + R` to refresh after config changes

## Development

```bash
git clone https://github.com/jpcerone/BlinkLauncher
open Blink.xcodeproj
```

### Project Structure

```
Blink/
├── BlinkApp.swift           # App lifecycle
├── LauncherView.swift       # UI and keyboard handling
├── LauncherViewModel.swift  # Search, filtering, and launch logic
├── ConfigManager.swift      # Config file parsing
└── CacheManager.swift       # Single-instance app management
```

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**[Download Latest Release](https://github.com/jpcerone/BlinkLauncher/releases)** | **[Report Bug](https://github.com/jpcerone/BlinkLauncher/issues)** | **[Request Feature](https://github.com/jpcerone/BlinkLauncher/issues)**
