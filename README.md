# YouTube Plus (YTLite Fork) v4.0.0

> The ultimate iOS YouTube client — surpassing both ReVanced (Android) and the original YouTube Plus.

[![Build from Source](https://github.com/krstock-master/YTLite/actions/workflows/build_from_source.yml/badge.svg)](https://github.com/krstock-master/YTLite/actions/workflows/build_from_source.yml)

## Features

### Core (Always Included)
- **Ad removal** — Video ads, banners, sponsored cards, Premium popups
- **Background playback** — Continue audio when app is minimized
- **Custom playback speed** — 0.25× to 5× with long-press speedmaster
- **Auto quality** — Per-network (WiFi/Cellular) quality presets
- **Shorts control** — Hide, redirect to regular player, auto-skip, progress bar
- **Tab management** — Hide/reorder tabs, Explore tab, startup tab selection
- **Player overlay** — Hide autoplay, end cards, watermarks, fullscreen actions
- **Comment/Post manager** — Copy text, save as image via long press
- **Native share** — iOS share sheet instead of YouTube's built-in
- **Sideloading support** — Full keychain/bundle ID patching

### Optional Modules (Build-time Selection)

| Module | Flag | Description |
|--------|------|-------------|
| **Enhanced Ad Block** | `ENABLE_ADBLOCK_PLUS=1` | 7-layer deep ad removal: server response stripping, renderer nullification, tracking prevention, Premium upsell blocking, Shorts ads, notification promos |
| **Sleep Timer** | `ENABLE_SLEEP_TIMER=1` | 15/30/45/60/90/120 min timers, end-of-video pause, headphone disconnect auto-pause |
| **Gesture Controls** | `ENABLE_GESTURES=1` | ReVanced-style volume/brightness swipe (right=volume, left=brightness) with pill HUD |
| **Clipboard Detector** | `ENABLE_CLIPBOARD=1` | Auto-detect YouTube URLs in clipboard, prompt to open in-app |
| **OLED Theme** | `ENABLE_OLED=1` | Pure black (#000000) dark mode for OLED battery savings |
| **AI Summary** | `ENABLE_AI_SUMMARY=1` | Video transcript → LLM API → 3-5 bullet point summary (Groq/OpenRouter) |
| **Auto-Translate** | `ENABLE_AUTO_TRANSLATE=1` | Translate descriptions and comments via AI API |
| **Download Plus** | `ENABLE_DOWNLOAD_PLUS=1` | Subtitle export (.srt) with language fallback, playlist batch queue |

## Building

### Prerequisites
- macOS with Xcode Command Line Tools
- [Theos](https://theos.dev) build system
- `make`, `ldid`, `dpkg` (via Homebrew)

### Build from Source

```bash
# Clone
git clone https://github.com/krstock-master/YTLite.git
cd YTLite

# Build with all modules
make clean package ENABLE_ALL_MODULES=1

# Build with specific modules only
make clean package ENABLE_ADBLOCK_PLUS=1 ENABLE_OLED=1 ENABLE_SLEEP_TIMER=1

# Build core only (no extra modules)
make clean package
```

### GitHub Actions (Recommended)

1. Go to **Actions** → **Build YouTube Plus (from source)**
2. Click **Run workflow**
3. Provide a decrypted YouTube IPA URL
4. Toggle desired modules on/off
5. Download the built IPA from **Releases**

## AI Features Setup

The AI Summary and Auto-Translate modules require an API key:

1. Get a free API key:
   - **Groq**: [console.groq.com](https://console.groq.com) (free tier available)
   - **OpenRouter**: [openrouter.ai](https://openrouter.ai) (free models available)

2. In YouTube → Settings → **YTLite** → **Plus Features**:
   - Select your **AI Provider**
   - Enter your **API Key**
   - Enable **AI Summary** and/or **Auto-Translate**

3. Usage:
   - **AI Summary**: Tap ✨ button in video description panel
   - **Translate Description**: Tap 🌐 button in video description panel
   - **Translate Comment**: Long-press comment → "Translate text"

## Project Structure

```
YTLite/
├── YTLite.x             # Core hooks (1500+ lines)
├── Settings.x           # YouTube Settings integration
├── Sideloading.x        # Bundle ID / keychain patching
├── YTNativeShare.x      # Native iOS share sheet
├── YTLite.h             # Shared header / interface declarations
├── YouTubeHeaders.h     # YouTube internal class declarations
├── Utils/               # NSBundle, Reachability, UserDefaults
├── Modules/
│   ├── AdBlock/         # Enhanced 7-layer ad removal
│   ├── SleepTimer/      # Timer + headphone auto-pause
│   ├── GestureControls/ # Volume/brightness swipe
│   ├── ClipboardDetector/ # Clipboard URL detection
│   ├── OLEDTheme/       # Pure black dark mode
│   ├── AISummary/       # Video transcript summarization
│   ├── AutoTranslate/   # Description/comment translation
│   └── DownloadPlus/    # Subtitle export + playlist queue
├── layout/              # Resources, localizations
│   └── Library/Application Support/YTLite.bundle/
│       ├── en.lproj/    # English
│       ├── ko.lproj/    # Korean
│       └── ...          # 12+ languages
├── Makefile             # Module toggle build system
├── control              # Debian package metadata
└── .github/workflows/
    ├── build_from_source.yml  # Full source build + module selection
    ├── main.yml               # Legacy pre-built .deb workflow
    └── _build_tweaks.yml      # Companion tweak builder
```

## Companion Tweaks

These are built separately and injected alongside YouTube Plus:

| Tweak | Purpose |
|-------|---------|
| [YouPiP](https://github.com/PoomSmart/YouPiP) | Picture-in-Picture |
| [YTUHD](https://github.com/Tonwalter888/YTUHD) | 4K/HDR quality unlock |
| [Return YouTube Dislikes](https://github.com/PoomSmart/Return-YouTube-Dislikes) | Dislike count restoration |
| [YTABConfig](https://github.com/PoomSmart/YTABConfig) | A/B experiment flag control |
| [YouQuality](https://github.com/PoomSmart/YouQuality) | Quality preferences |
| [DontEatMyContent](https://github.com/therealFoxster/DontEatMyContent) | Dynamic Island safe area |

## Credits

- **[dayanch96](https://github.com/dayanch96)** — Original YTLite / YouTube Plus developer
- **[PoomSmart](https://github.com/PoomSmart)** — YouTubeHeaders, YouTube-X, NoYTPremium, YouPiP, and many more
- **[MiRO92](https://github.com/MiRO92)** — YTNoShorts
- **[Tony Million](https://github.com/tonymillion)** — Reachability
- **[jkhsjdhjs](https://github.com/jkhsjdhjs)** — YouTube Native Share

## Disclaimer

This project modifies a copyrighted application. It likely violates YouTube's Terms of Service. Use at your own risk and for personal/educational purposes only. The developers of this project are not responsible for any consequences arising from its use.

## License

This project is licensed under the [GPL-3.0 License](LICENSE).
