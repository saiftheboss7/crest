# Crest — Software Requirements Document

**Version:** 1.1 · **Date:** April 2025 · **Platform:** macOS 13+ · **Status:** Draft

---

## Overview

Crest is a native Swift/SwiftUI macOS menu bar app focused on **calendar events, meetings, and schedule awareness**. It replaces the system clock with a rich, always-visible panel for your day. An optional Islamic Mode adds prayer times and alerts as a secondary layer.

---

## Core Features

### Menu Bar

- Custom date/time label (format string, show/hide seconds)
- Upcoming event title in menu bar (truncated, configurable)
### Calendar & Events

- Mini monthly calendar popover with event dot indicators
- Upcoming event list (configurable window, default 7 days)
- Google Calendar via macOS EventKit — no OAuth required
- Event details: attendees, notes, location, video call button
- Quick event creation with global keyboard shortcut

### Meeting Integration

- Auto-detects meeting links in event fields (location, notes)
- Supports 50+ services: Google Meet, Zoom, Teams, Webex, etc.
- One-click join from popover or global keyboard shortcut
- Fullscreen meeting notification overlay at event start time

### Utilities

- Date calculator (days between dates, future/past date)
- Reminders support via EventKit
- Hourly chime (optional)

---

## Islamic Mode

> Disabled by default. Enabled via **Settings → General → Islamic Mode**. Zero overhead when off.

### Prayer Times

- Calculated locally using `adhan-swift` — no network required
- 5 daily prayers shown in popover below the event list
- Hijri date displayed in popover and optionally in menu bar label
- Prayer notifications with optional Adhan audio (per-prayer toggle)
- Calculation method selector (MWL, ISNA, Karachi, Umm al-Qura, and more)
- Madhab selector (Shafi'i / Hanafi) affecting Asr time
- Manual per-prayer time offsets (±30 min) for mosque alignment
- Hijri date offset slider (±3 days) for local moon sighting

### Full-Screen Overlays

Two separate full-screen overlays fire per prayer. Both can be individually toggled per prayer in Settings.

#### Overlay 1: Prayer Start Reminder (at prayer start)

Fires at the prayer's start time (or at the configured jamaat time when jamaat times are enabled). It always fires after the predecessor prayer's Overlay 2, never simultaneously with it.

- Full-screen non-blocking NSWindow overlay
- Shows: prayer name in Arabic + transliteration, the prayer's start time, live countdown updating every second
- Thin circular arc animating down from full to empty over 15 minutes
- Actions: **Snooze 5 min** (simple button click, re-shows in 5 minutes), **Dismiss** (requires typing "inshallah" to confirm dismissal)
- Esc key is blocked — the only way to close is typing "inshallah" or snoozing
- Non-blocking — user can still interact with apps behind it

#### Overlay 2: Prayer Ending Warning (15 min before prayer window closes)

Fires when only 15 minutes remain in the current prayer's time window (i.e., 15 min before the next prayer begins). The offset is configurable globally and per prayer.

- Full-screen **blocking** NSWindow overlay — captures input to demand attention
- Urgent tone: warmer/amber colour scheme to distinguish from Overlay 1
- Shows: prayer name, "Prayer time ending in 15 minutes", live countdown, next prayer name and its start time
- Actions: **Dismiss** (requires typing "inshallah" to confirm dismissal)
- Esc key is blocked — the only way to close is typing "inshallah"
- Intended as a final urgent reminder for users who haven't prayed yet

#### Overlay Settings (per-prayer)

Each prayer has two independent checkboxes in **Settings → Islamic Mode → Overlays**:

- **Remind at prayer start** — enables/disables Overlay 1 for that prayer
- **Remind before prayer ends** — enables/disables Overlay 2 for that prayer

No prayer tracking or "I have prayed" functionality — the overlays are purely reminders.

#### Overlay Behaviour Rules

- If device was asleep when an overlay should have triggered, it fires immediately on wake if still within the valid window
- Both overlays respect macOS Focus / Do Not Disturb — a sub-setting controls whether to override DND or respect it

---

## Tech Stack


| Layer         | Technology                 |
| ------------- | -------------------------- |
| UI            | SwiftUI + AppKit           |
| Calendar data | EventKit (EKEventStore)    |
| Prayer times  | `adhan-swift` via SPM      |
| Persistence   | UserDefaults / @AppStorage |
| Audio         | AVFoundation               |
| Location      | CoreLocation (local only)  |


---

## Release Phases


| Phase | Scope                                                                             |
| ----- | --------------------------------------------------------------------------------- |
| v0.1  | Menu bar shell, clock label, settings skeleton                                    |
| v0.2  | EventKit, calendar popover, event list, Google Calendar                           |
| v0.3  | Meeting detection, join button, fullscreen meeting alert                          |
| v0.4  | Islamic Mode: prayer times, Hijri date, notifications, Overlay 1 (15-min warning) |
| v0.5  | Overlay 2 (20-min prayer ending alert), sleep/wake handling                       |
| v1.0  | Date calculator, polish, App Store release                          |
