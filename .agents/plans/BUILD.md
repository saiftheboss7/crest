# BUILD — first launch, signing, release

Detail companion to `AGENTS.md > Build & run`. Pulled out so the top-level guide stays scannable.

## First launch — calendar permission

The app needs calendar access. On first launch:

1. Click the date/time label in the menu bar and click **"Grant Access"** in the popover, **or**
2. Open **System Settings → Privacy & Security → Calendars** and enable Crest manually:

   ```bash
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
   ```

3. Restart the app after granting (`killall Crest`, then relaunch).

If permission is denied, `CalendarService` falls back gracefully — the menu bar still shows the clock — but events will be empty. The popover surfaces a "Grant Access" CTA whenever EventKit reports `denied` / `notDetermined`.

## First launch — location (Islamic Mode only)

`PrayerTimeService` resolves coordinates from one of two sources:

- **Static location** (preferred for testing): set `staticLocationEnabled` + `staticLatitude` + `staticLongitude` in Settings → Islamic Mode.
- **Live location** via `LocationService` / `CLLocationManager`. Requires `NSLocationUsageDescription` (already in `project.yml`) and a one-time system permission prompt.

If neither produces valid coords, `recompute()` clears `todayPrayers` and the prayer UI hides itself. There is no error toast — verify by checking that `todayPrayers.isEmpty` is `false` after granting permission.

## Code signing

Local development uses **ad-hoc signing**:

```yaml
# project.yml
CODE_SIGN_STYLE: Manual
CODE_SIGN_IDENTITY: "-"
```

No Apple Developer team is required to build, run, or test locally.

For App Store distribution (v1.0):

1. Switch `CODE_SIGN_STYLE` to `Automatic` in `project.yml`.
2. Add `DEVELOPMENT_TEAM: <TEAM_ID>` under the `Crest` target's `settings.base`.
3. Re-run `xcodegen generate`.
4. Archive via `xcodebuild archive` or the Xcode Organizer.

Sparkle requires the app to be signed with a stable identity for update verification — `SUPublicEDKey` is already wired in `project.yml`. Generate an EdDSA keypair with `Sparkle/bin/generate_keys` and keep the private key out of the repo.

## Release-build commands

Debug build (default for development):

```bash
xcodebuild -project Crest.xcodeproj -scheme Crest -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES
```

Release build (for distribution / appcast publishing):

```bash
xcodebuild -project Crest.xcodeproj -scheme Crest -configuration Release archive \
  -archivePath build/Crest.xcarchive
xcodebuild -exportArchive -archivePath build/Crest.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
```

(`ExportOptions.plist` is not yet in the repo — create it during the v1.0 App Store prep.)

## Bumping the version

Two values control the user-visible version (both in `project.yml > targets.Crest.settings.base`):

- `MARKETING_VERSION` — public version (e.g. `0.0.5`)
- `CURRENT_PROJECT_VERSION` — build number (monotonic integer)

After editing, run `xcodegen generate` and rebuild.

## Sparkle appcast

- Feed URL: `https://saiftheboss7.github.io/crest/appcast.xml` (set in Info.plist via `SUFeedURL`)
- Public EdDSA key: hardcoded in Info.plist via `SUPublicEDKey`
- Update flow: see Sparkle docs → fetch via `ctx7` if you need API specifics.

## Common pitfalls

- **Don't edit `Crest.xcodeproj` by hand.** It is regenerated. Edit `project.yml` and run `xcodegen generate`.
- **`xcodegen` not installed?** `brew install xcodegen`.
- **Calendar permission was granted but events still empty:** the app caches the EventKit auth state; restart Crest (`killall Crest` then relaunch) after granting.
- **Build fails with code-signing error:** confirm the `CODE_SIGN_IDENTITY="-"` flags are passed to `xcodebuild` — the project defaults work but some CI hosts override.
