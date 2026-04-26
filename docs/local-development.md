# Local Development Builds

Vocra uses a separate local development app identity so it can coexist with the
released DMG build:

- Release app: `Vocra.app`, bundle id `com.indincys.Vocra`
- Local test app: `Vocra Dev.app`, bundle id `com.indincys.Vocra.dev`

The Codex Run action and `./script/build_and_run.sh` build and launch the local
test app by default. Release packaging still builds `Vocra.app`.

## Keep Accessibility Permission Stable

macOS Accessibility permission is tied to the app's code-signing identity. If the
app is ad-hoc signed after every build, macOS can treat each build as a new app
and ask for permission again.

You do not need an Apple Developer account for local testing. Create a local
self-signed code-signing certificate once:

1. Open Keychain Access.
2. Choose Keychain Access > Certificate Assistant > Create a Certificate.
3. Name it `Vocra Local Development`.
4. Set Identity Type to `Self Signed Root`.
5. Set Certificate Type to `Code Signing`.
6. Create it in the login keychain.
7. If macOS marks it as untrusted, open the certificate, expand Trust, and set
   Code Signing to Always Trust.

Verify that codesign can see it:

```bash
security find-identity -p codesigning -v
```

Then run:

```bash
./script/build_and_run.sh
```

The script automatically uses `Vocra Local Development` for `Vocra Dev.app` when
that certificate exists. After the first Accessibility approval for
`Vocra Dev.app`, rebuilds should keep using the same permission.

## Useful Commands

Build and launch the test app:

```bash
./script/build_and_run.sh
```

Build the test app without launching:

```bash
VOCRA_APP_VARIANT=dev ./script/build_and_run.sh --package
```

Build the release app without launching:

```bash
VOCRA_APP_VARIANT=release ./script/build_and_run.sh --package
```

Create release assets:

```bash
./script/release_github.sh <version>
```

Use a different local signing identity:

```bash
VOCRA_CODESIGN_IDENTITY="My Local Code Signing Cert" ./script/build_and_run.sh
```
