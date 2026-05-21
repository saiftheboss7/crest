# Crest

A native macOS menu bar app for calendar events, meetings, and schedule awareness. Optional Islamic Mode adds prayer times, Hijri date, and prayer reminders.

**Requires macOS 14.0 (Sonoma) or later.**

## Features

Keep forgetting meetings when there was a tiny notification triggered 30m before somewhere? Crest is designed to make your event alerts look good, taking the full real estate of your Retina screen with beautiful typography, accessibility friendly design. You probably won’t be able to miss them. Crest also has an optional Islamic Reminder app section to remind you about the daily prayers.

<img width="650" height="1270" alt="CleanShot 2026-05-22 at 04 34 49@2x" src="https://github.com/user-attachments/assets/e58395f4-1d7a-4aef-88f4-f9a23fcf05d2" />
<img width="5118" height="2880" alt="CleanShot 2026-05-22 at 03 38 57@2x" src="https://github.com/user-attachments/assets/08210bb8-d6d7-4abb-9997-ab1bddb99f32" />
<img width="5118" height="2872" alt="CleanShot 2026-05-22 at 03 39 14@2x" src="https://github.com/user-attachments/assets/84c606de-4495-4135-af20-e625ee17b996" />



### Calendar & Events
- View upcoming events from all macOS system calendars (including synced Google Calendar)
- Interactive mini calendar in the popover
- Select which calendars to display
- Configurable lookahead window (1–30 days)

### Meeting Detection
- Detects meeting links from **65+ video conferencing services** including Zoom, Google Meet, Microsoft Teams, Webex, Slack, Discord, and many more
- Fullscreen alert when meetings are about to start with countdown timer
- One-click Join button to open the meeting link
- Snooze options: 1 min, 5 min, or until event starts
- Global shortcut to join next meeting: `Cmd+Shift+J`

### Islamic Mode (Optional)
- **Prayer times** for Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha
- **12 calculation methods** (Muslim World League, ISNA, Umm al-Qura, and more)
- **Madhab selection** (Shafi'i or Hanafi)
- **Hijri date** display with adjustable offset
- **Prayer notifications** with optional Adhan audio per prayer
- **Fullscreen prayer reminders** at prayer start and before prayer ends
- Per-prayer time adjustments (-30 to +30 minutes)
- Respects macOS Do Not Disturb

### Auto-Updates
- Automatic update checks via Sparkle
- Manual check available in Settings > General > "Check for Updates..."

## Installation

### Download (Recommended)

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/saiftheboss7/crest/releases/latest)
2. Open the DMG and drag **Crest** to **Applications**
3. On first launch, right-click Crest.app > **Open** > click **Open** (required once for unsigned apps)

**Note:** Crest is not notarized with Apple. If macOS blocks the app, run:

> ```bash
> xattr -cr /Applications/Crest.app
> ```

or

<img width="1836" height="2176" alt="CleanShot 2026-04-08 at 23 13 57@2x" src="https://github.com/user-attachments/assets/40b2b7bb-c707-4cc1-b7fa-1e7ad41e0b6e" />


### Homebrew

```bash
brew tap saiftheboss7/crest
brew install --cask crest
```

### Build from Source

```bash
# Install xcodegen if you don't have it
brew install xcodegen

# Clone and build
git clone https://github.com/saiftheboss7/crest.git
cd crest
xcodegen generate
xcodebuild -project Crest.xcodeproj -scheme Crest -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES

# Launch
open $(xcodebuild -project Crest.xcodeproj -scheme Crest -configuration Release \
  -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/Crest.app
```

## Calendar Permission

Crest needs calendar access to show your events. On first launch:

1. Click the Crest icon in the menu bar and click **Grant Access**, or
2. Go to **System Settings > Privacy & Security > Calendars** and enable Crest

Restart the app after granting permission.

## Location Permission

Islamic Mode uses your location to calculate accurate prayer times. When you enable Islamic Mode:

1. Crest will prompt for location access — click **Allow**, or
2. Go to **System Settings > Privacy & Security > Location Services** and enable Crest

Location is used only for prayer time calculation and is never sent off-device.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+,` | Open Settings |
| `Cmd+Q` | Quit |
| `Cmd+Shift+J` | Join next meeting (global, toggleable) |
| `Enter` | Join meeting from alert |
| `Escape` | Dismiss meeting alert |

## Tech Stack

- Swift 6.2 / SwiftUI
- EventKit for calendar access
- CoreLocation for prayer time calculation
- [Adhan](https://github.com/batoulapps/adhan-swift) for prayer time computation
- [Sparkle](https://github.com/sparkle-project/Sparkle) for auto-updates
- Built with [xcodegen](https://github.com/yonaskolb/XcodeGen)

## License

All rights reserved.
