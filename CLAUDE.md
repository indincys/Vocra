# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Vocra Is

Vocra is a macOS 26+ menu bar app for reading English on a Mac: select text anywhere, press a global shortcut (`Option-Space` by default), and Vocra reads the selection, classifies it locally as `word`/`phrase`/`sentence`, sends it to an OpenAI-compatible model, and renders a structured explanation in a floating panel. Words and phrases are saved to a local SQLite notebook for spaced-repetition review; sentences are not.

The app UI is in Chinese — it targets Chinese speakers learning English. Menu titles, button labels, and user-facing strings are Chinese; keep new UI strings consistent with that.

## Build, Run, Test

This is a Swift Package (SwiftPM, `swift-tools-version: 6.2`), not an Xcode project. But **do not use `swift run`** — the app needs a real `.app` bundle (Info.plist, icon, Sparkle framework, code signing) for `MenuBarExtra` and Accessibility to work.

```bash
./script/build_and_run.sh            # build + launch the dev app (Vocra Dev.app)
./script/build_and_run.sh --verify   # build, launch, confirm process is alive
./script/build_and_run.sh --logs     # launch and stream os_log output
./script/build_and_run.sh --package  # build the bundle without launching

swift build                          # compile only (fast check, no bundle)
swift test                           # run all tests (both test targets)
swift test --filter TextClassifierTests                       # one test class
swift test --filter TextClassifierTests/testClassifiesOneSpaceAsPhrase   # one test
```

Tests use **XCTest** (not swift-testing) and run fine with plain `swift build`/`swift test` — no bundle needed.

### Dev vs. release variant

`build_and_run.sh` builds the **dev** variant by default: `Vocra Dev.app`, bundle id `com.indincys.Vocra.dev`, so it coexists with an installed release `Vocra.app` (`com.indincys.Vocra`). The bundle id is checked at runtime to pick the Application Support folder (`Vocra Dev` vs `Vocra`), so dev and release keep separate databases and caches. Set `VOCRA_APP_VARIANT=release` to build the release identity.

### Accessibility permission gotcha

macOS ties Accessibility permission to the code-signing identity. Ad-hoc signing changes identity each build, so macOS re-prompts every time. The script uses a self-signed `Vocra Local Development` certificate when present to keep the grant stable — see [docs/local-development.md](docs/local-development.md) for the one-time Keychain setup. Without it, expect to re-grant Accessibility after rebuilds.

## Architecture

Two SwiftPM targets, one dependency (Sparkle, for in-app updates):

- **`VocraCore`** (library) — models, services, stores, prompt rendering/validation, SQLite, Keychain, the OpenAI-compatible client. No AppKit/SwiftUI. Everything is `Sendable` under Swift 6 strict concurrency.
- **`Vocra`** (executable) — SwiftUI app shell, views, the floating panel, settings, and the AppKit bridge for the global shortcut and panel behavior.

### The core pipeline (shortcut → panel)

`AppModel.handleShortcut()` ([Sources/Vocra/App/AppModel.swift](Sources/Vocra/App/AppModel.swift)) orchestrates the whole flow and is the best entry point for understanding the app:

1. **Read selection** — `SelectionReader` (`MacSelectionReader`) reads the focused app's selection via Accessibility, falling back to a temporary `Cmd-C` copy.
2. **Classify locally** — `TextClassifier` decides `word`/`phrase`/`sentence` from spacing, punctuation, line breaks, and predicate markers. No network call. The panel lets the user override the guessed mode (`explainWithMode`).
3. **Render prompt** — `LearningPromptFactory` + `PromptRenderer` fill a `PromptTemplate` and append a strict JSON "Contract" (schema version, source-text echo, learning-preference knobs).
4. **Call model** — `OpenAICompatibleClient` streams from an OpenAI-compatible chat endpoint. Streaming is used so `URLRequest`'s *idle* timeout doesn't trip during a long single-shot generation.
5. **Validate + repair** — `StructuredExplanationService` decodes into `LearningExplanationDocument`, validates it, and on failure **retries exactly once** with a repair prompt that includes the validation error and the bad output.
6. **Show + persist** — result renders in the `FloatingPanelController`; for word/phrase modes a second call generates a vocabulary card that's upserted into SQLite (dedup by normalized text).

### Key architectural conventions

- **`LearningExplanationDocument` is the contract.** The model returns structured JSON, not Markdown, so the UI stays stable across prompt edits. It carries a `schemaVersion`; the prompt Contract pins it to `currentSchemaVersion`. Changing the document shape means updating the model, the validator, the schema prompts, and the SwiftUI renderers together.
- **Stale-request guarding.** `handleShortcut` increments an `activeExplanationRequestID` and checks `isCurrentExplanationRequest` after every `await`, so a newer lookup discards an in-flight older one's results. Preserve this pattern when adding async steps.
- **Dependency injection for testability.** `AppModel.init` takes every store/service/reader/presenter as a parameter (with production defaults), plus optional `explanationProvider`/`vocabularyCardProvider` closures that bypass the network entirely. Tests inject fakes; don't hardcode singletons inside `AppModel`.
- **`@MainActor @Observable`.** `AppModel` is main-actor and drives SwiftUI via `@Observable`. `vocabularyRevision` is a manual counter bumped on writes to force SwiftUI re-reads of SQLite-backed data.
- **Storage boundaries.** Vocabulary and review data live in SQLite (`SQLiteVocabularyRepository` over a thin `SQLiteDatabase`) in Application Support. Settings/prompts/preferences live in `UserDefaults`. The **API key lives only in Keychain** (`KeychainAPIKeyStore`), never in the DB — per-profile keys use a `keychainAccount`.
- **Multiple API profiles.** Settings support several OpenAI-compatible `APIProfile`s; `AppModel` resolves the active profile's `configuration` + per-profile Keychain account before each call, falling back to the single-config settings.

## Release

Releases go out as an ad-hoc-signed DMG via GitHub Releases, with Sparkle EdDSA-signed appcasts for in-app updates (no Apple Developer account / notarization). Tag `vX.Y.Z` to trigger [.github/workflows/release.yml](.github/workflows/release.yml); local packaging is `./script/release_github.sh <version>`. Full details and the one-time Sparkle key setup are in [docs/release.md](docs/release.md).
