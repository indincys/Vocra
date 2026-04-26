# Release Workflow

Vocra uses Sparkle for in-app updates and GitHub Releases for distribution. The release artifact is a DMG; the app is ad-hoc signed because this project does not use an Apple Developer account.

## One-Time Sparkle Key Setup

Generate Sparkle EdDSA keys locally:

```bash
swift package resolve
.build/artifacts/sparkle/Sparkle/bin/generate_keys
```

Add these GitHub repository secrets:

- `SPARKLE_PUBLIC_KEY`: public EdDSA key. This is embedded in `Info.plist` at release time as `SUPublicEDKey`.
- `SPARKLE_PRIVATE_KEY`: private EdDSA key. This is used only by CI to sign the appcast and update archive metadata.

Do not commit the private key.

## GitHub Release

Tag releases with semantic versions:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow builds `Vocra.app`, embeds Sparkle, ad-hoc signs the bundle, creates `Vocra-<version>.dmg`, generates `appcast.xml`, and uploads both files to the GitHub Release.

Release builds use a UTC timestamp as `CFBundleVersion` so Sparkle always sees a monotonically increasing internal version.

The app uses this default feed URL:

```text
https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml
```

To override it, set `SPARKLE_FEED_URL` when running `script/release_github.sh`.

## Local Release Build

Use this when testing the packaging flow outside GitHub Actions:

```bash
GITHUB_REPOSITORY=owner/repo \
SPARKLE_PUBLIC_KEY=... \
SPARKLE_PRIVATE_KEY=... \
./script/release_github.sh 0.1.0
```

Outputs are written under `dist/releases/v<version>/`.

## Distribution Without Apple Developer

Ad-hoc signing is enough for Sparkle's archive signature verification when paired with EdDSA appcast signing, but it is not Apple notarization. First launch on other Macs may require users to approve the app manually through Finder or macOS Privacy & Security. A Developer ID certificate and notarization would be required to avoid Gatekeeper friction.
