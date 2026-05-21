# Release Process

This document describes how Crest releases are built, signed, and distributed.

## Overview

Releases are fully automated via GitHub Actions. Pushing a version tag triggers the pipeline, which builds the app, creates a signed DMG, publishes a GitHub Release, updates the Sparkle appcast, and optionally updates the Homebrew Cask.

```
git tag → GitHub Actions → DMG + GitHub Release + Appcast + Homebrew
```

## Prerequisites (One-Time Setup)

### 1. Sparkle EdDSA Keys

Sparkle uses EdDSA (Ed25519) signatures to verify updates. The key pair was generated using Sparkle's `generate_keys` tool.

- **Public key** — stored in `project.yml` under `SUPublicEDKey`, baked into the app at build time
- **Private key** — stored as GitHub Actions secret `SPARKLE_EDDSA_PRIVATE_KEY`

To regenerate keys (will break updates for existing users):

```bash
# Download Sparkle 2.9.1 and extract
curl -sL -o sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.9.1/Sparkle-2.9.1.tar.xz
mkdir sparkle && tar -xf sparkle.tar.xz -C sparkle

# Generate new key pair (saved to macOS Keychain)
./sparkle/bin/generate_keys

# Export private key to a file
./sparkle/bin/generate_keys -x private_key.pem
cat private_key.pem  # Copy this to GitHub secret
rm private_key.pem   # Delete after copying
```

### 2. GitHub Pages

The Sparkle appcast is hosted on GitHub Pages at:

```
https://saiftheboss7.github.io/crest/appcast.xml
```

**Setup:** GitHub repo > Settings > Pages > Source: `gh-pages` branch, `/ (root)`

### 3. GitHub Secrets

| Secret | Purpose |
|---|---|
| `SPARKLE_EDDSA_PRIVATE_KEY` | Signs DMG for Sparkle update verification |
| `HOMEBREW_TAP_TOKEN` (optional) | PAT with `repo` scope for pushing to `saiftheboss7/homebrew-crest` |

### 4. Homebrew Tap (Optional)

Create the repo `saiftheboss7/homebrew-crest` with a `Casks/crest.rb` file. The CI workflow updates it automatically if the `HOMEBREW_TAP_TOKEN` secret exists.

## Creating a Release

### 1. Update the version in `project.yml`

```yaml
settings:
  base:
    MARKETING_VERSION: "1.0.0"
```

### 2. Commit and tag

```bash
git add project.yml
git commit -m "chore: bump version to 1.0.0"
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main --tags
```

### 3. Wait for CI

The `Release` workflow (`.github/workflows/release.yml`) triggers automatically on the `v*` tag push.

Monitor progress at: `https://github.com/saiftheboss7/crest/actions`

### 4. Verify the release

- [ ] GitHub Release exists with DMG attached
- [ ] Appcast is updated at `https://saiftheboss7.github.io/crest/appcast.xml`
- [ ] DMG installs correctly (drag to Applications, right-click > Open)
- [ ] Existing app detects the update via Sparkle

## What the CI Pipeline Does

1. **Checkout** code at the tagged commit
2. **Extract version** from the git tag (`v1.0.0` → `1.0.0`)
3. **Install tools** — `xcodegen` and `create-dmg` via Homebrew
4. **Generate Xcode project** — `xcodegen generate`
5. **Resolve SPM dependencies** — fetches Adhan and Sparkle packages
6. **Build Release** — ad-hoc signed (`CODE_SIGN_IDENTITY="-"`), with:
   - `MARKETING_VERSION` from git tag
   - `CURRENT_PROJECT_VERSION` from `github.run_number` (auto-incrementing)
7. **Create DMG** — using `create-dmg` with Applications symlink
8. **Sign DMG** — downloads Sparkle tools, signs with EdDSA private key
9. **Update appcast** — fetches existing `appcast.xml` from `gh-pages`, inserts new `<item>`, pushes back
10. **Create GitHub Release** — attaches DMG, generates release notes
11. **Update Homebrew Cask** — updates version and SHA256 in the tap repo (if token exists)

## Version Numbers

| Field | Source | Example |
|---|---|---|
| `CFBundleShortVersionString` (display version) | Git tag via `MARKETING_VERSION` | `1.0.0` |
| `CFBundleVersion` (build number) | `github.run_number` | `42` |

The build number auto-increments with each CI run, ensuring Sparkle always sees newer builds as updates.

## Appcast

The appcast (`appcast.xml`) is a Sparkle RSS feed hosted on GitHub Pages. Each release adds a new `<item>` to the feed. The feed is cumulative — older versions are preserved so Sparkle can show release notes for skipped versions.

**URL:** `https://saiftheboss7.github.io/crest/appcast.xml`

Each item contains:
- Display version and build number
- Download URL pointing to the GitHub Release DMG
- EdDSA signature for update verification
- Minimum macOS version (14.0)

## Distribution Without Notarization

Crest is distributed without Apple notarization (no Apple Developer account). This means:

- macOS Gatekeeper will show an "unidentified developer" warning on first launch
- Users must bypass this once using one of these methods:
  1. **Right-click > Open > Open** (simplest)
  2. **System Settings > Privacy & Security > Open Anyway**
  3. `xattr -cr /Applications/Crest.app` (terminal)
- The Homebrew Cask includes a `caveats` block that prints these instructions

Sparkle updates are **not affected** by notarization — Sparkle uses its own EdDSA signature verification, independent of Apple's code signing. Once the app is running, updates install seamlessly.

## Troubleshooting

### CI build fails on SPM resolution
macOS GitHub runners cache Xcode versions. If the runner's Xcode version doesn't match the project, add a step to select the correct version:
```yaml
- name: Select Xcode
  run: sudo xcode-select -s /Applications/Xcode_16.1.app
```

### create-dmg exits with code 2
This is normal — it means `create-dmg` couldn't set a custom volume icon. The DMG is still valid. The `|| true` in the workflow handles this.

### Sparkle shows "No updates available" for a new release
- Verify the appcast URL is accessible: `curl https://saiftheboss7.github.io/crest/appcast.xml`
- Check that `sparkle:version` (build number) in the appcast is greater than the installed app's build number
- Ensure `SUPublicEDKey` in the app matches the key used to sign the DMG

### Homebrew Cask update step fails
- Ensure the `HOMEBREW_TAP_TOKEN` secret has `repo` scope
- Verify the `saiftheboss7/homebrew-crest` repo exists with `Casks/crest.rb`
- This step is non-blocking — the GitHub Release is created regardless
