# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Vocra Is

Vocra is a macOS 26+ menu bar app for reading English on a Mac: select text anywhere, press a global shortcut (`Option-Space` by default), and Vocra reads the selection, classifies it locally as `word`/`phrase`/`sentence`, sends it to an OpenAI-compatible model, and renders a structured explanation in the main window's 查词 section. Words and phrases are saved to a local SQLite notebook for spaced-repetition review; sentences are not.

A second global shortcut (`Option-Shift-Space` by default) collects a **long selection** — a paragraph or a whole article — into the app's 阅读 (reading) section instead, where it is studied sentence by sentence.

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

- **`VocraCore`** (library) — models, services, stores, prompt rendering/validation, SQLite, the encrypted API key vault, the OpenAI-compatible client. No AppKit/SwiftUI. Everything is `Sendable` under Swift 6 strict concurrency.
- **`Vocra`** (executable) — SwiftUI app shell, views, settings, and the AppKit bridge for the global shortcut and window behavior.

### The core pipeline (shortcut → panel)

`AppModel.handleShortcut()` ([Sources/Vocra/App/AppModel.swift](Sources/Vocra/App/AppModel.swift)) orchestrates the whole flow and is the best entry point for understanding the app:

1. **Read selection** — `SelectionReader` (`MacSelectionReader`) reads the focused app's selection via Accessibility, falling back to a temporary `Cmd-C` copy.
2. **Classify locally** — `TextClassifier` decides `word`/`phrase`/`sentence` from spacing, punctuation, line breaks, and predicate markers. No network call. The panel lets the user override the guessed mode (`explainWithMode`).
3. **Render prompt** — `LearningPromptFactory` + `PromptRenderer` fill a `PromptTemplate` and append a strict JSON "Contract" (schema version, source-text echo, learning-preference knobs).
4. **Call model** — `OpenAICompatibleClient` streams from an OpenAI-compatible chat endpoint. Streaming is used so `URLRequest`'s *idle* timeout doesn't trip during a long single-shot generation.
5. **Validate + repair** — `StructuredExplanationService` decodes into `LearningExplanationDocument`, validates it, and on failure **retries exactly once** with a repair prompt that includes the validation error and the bad output.
6. **Show + persist** — the result renders in the main window's 查词 section (`LookupView`), which reads `AppModel`'s published state directly; `MainWindowLookupPresenter` only raises the window, once per lookup. For word/phrase modes a vocabulary card is synthesized locally and upserted into SQLite (dedup by normalized text).

### The reading pipeline (collect shortcut → 阅读 section)

`AppModel.handleCollectArticle()` is the second entry point, and reuses the pieces above:

1. **Read selection** — the same `SelectionReader`.
2. **Segment locally** — `ArticleSegmenter` folds soft-wrapped lines back together (PDF/web copy), heals hyphenation across line breaks, splits paragraphs on blank lines, and tokenizes sentences with `NLTokenizer`. `ArticleLengthPolicy` guards against collecting a stray word.
3. **Persist** — `SQLiteArticleRepository` stores the article plus one row per sentence in **its own database file** (`vocra-articles.sqlite`), separate from the vocabulary notebook so the two schemas migrate independently.
4. **Analyze in the background** — `ArticleLibraryModel` walks the unanalyzed sentences two at a time, calling the same `StructuredExplanationService` in `.sentence` mode, and writes each `LearningExplanationDocument` back onto its sentence row. Reopening an article is then a pure local read. Failed sentences are parked (not retried in a loop) until the user retries explicitly.
5. **Render** — `ArticleReaderView` shows every sentence with its grammar colors inline; clicking one expands the full `SentenceLearningView` breakdown **directly beneath that sentence**, never in a separate pane.

Articles have a retention window (default 30 days from last open, configurable in Settings). The sweep runs at launch and on setting change, and also purges disk-cached explanations of the same age.

### Key architectural conventions

- **`LearningExplanationDocument` is the contract.** The model returns structured JSON, not Markdown, so the UI stays stable across prompt edits. It carries a `schemaVersion`; the prompt Contract pins it to `currentSchemaVersion`. Changing the document shape means updating the model, the validator, the schema prompts, and the SwiftUI renderers together.
- **A sentence analysis is exactly three things:** `translation`, `sentence.segments`, and `keyVocabulary`. Earlier versions also requested a headline, a nested structure outline, a relationship diagram, and a logic summary; they roughly tripled the generated tokens for sections readers skipped, and were removed along with the second (supplementary) request. Old documents in the explanation cache and the article DB still decode — the removed keys are simply ignored — so no data migration is needed. Resist re-adding sections: every field costs first-token-to-readable latency.
- **The sentence is the UI.** `SentenceLearningView` renders the sentence with a colored underline per grammatical span and a soft wash per key word, and tapping one opens its explanation **inline, on its own row directly beneath the row that span sits on** — no popover, no separate pane. That row insertion is why `InlineExpansionFlow` is a custom `Layout`: which row a span lands on is only known after the words are measured, so it can't be expressed as a `VStack` of rows in the view body.
- **Stale-request guarding.** `handleShortcut` increments an `activeExplanationRequestID` and checks `isCurrentExplanationRequest` after every `await`, so a newer lookup discards an in-flight older one's results. Preserve this pattern when adding async steps.
- **Dependency injection for testability.** `AppModel.init` takes every store/service/reader/presenter as a parameter (with production defaults), plus optional `explanationProvider`/`vocabularyCardProvider` closures that bypass the network entirely. Tests inject fakes; don't hardcode singletons inside `AppModel`.
- **`@MainActor @Observable`.** `AppModel` is main-actor and drives SwiftUI via `@Observable`. `vocabularyRevision` is a manual counter bumped on writes to force SwiftUI re-reads of SQLite-backed data.
- **Storage boundaries.** Vocabulary and review data live in SQLite (`SQLiteVocabularyRepository` over a thin `SQLiteDatabase`) in Application Support; collected articles live in a second SQLite file (`SQLiteArticleRepository`). All paths come from `AppStorageLocations`, which delegates to `VocraStorageLocations` in VocraCore. Settings/prompts/preferences live in `UserDefaults`.
- **API keys live in a local encrypted file, not the Keychain.** `FileAPIKeyStore` writes `secrets.key` + `secrets.enc` (ChaCha20-Poly1305, 0600, atomic `rename`) next to the databases; per-profile keys use `APIProviderProfile.secretAccount`. Without an Apple Developer certificate the Keychain's per-app ACL cannot survive a re-signed build, so it re-prompted on every update and every local rebuild. The file layer is **防误不防恶** — it keeps keys out of backups and `grep`, but the master key sits beside the ciphertext and is not an independent security boundary. `APIKeyMigrator` runs at every launch and is idempotent; it does **not** clear the Keychain in the dev build, which shares the Keychain account with the installed release app while keeping its own vault.
- **One model factory.** `ExplanationServiceFactory` resolves the active API profile + its key account + learning preferences into a `StructuredExplanationService`. Both the lookup flow and the article reader go through it; don't re-derive that assembly.
- **Global shortcuts are slotted.** `ShortcutService` installs one Carbon event handler for the process and routes each keypress by `EventHotKeyID` to a `ShortcutSlot` (`.lookup`, `.collectArticle`). Adding a third shortcut means adding a slot, not a second service.
- **Background launch.** `LaunchAtLoginService` wraps `SMAppService.mainApp`. `AppDelegate` checks `NSApplication.launchIsDefaultUserInfoKey`: a login-item start stays `.accessory` (menu bar only, no Dock icon, no focus steal) and is promoted to `.regular` the first time the main window opens.
- **Multiple API profiles.** Settings support several OpenAI-compatible `APIProfile`s; `AppModel` resolves the active profile's `configuration` + per-profile key account before each call, falling back to the single-config settings.
- **The app must survive closing its window.** `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false`. Without it SwiftUI terminates the process when the last window closes — which read to users as "the app quits by itself" (the system log shows a `voluntary` exit(0) right after the window's WindowServer assertions drop). Closing the last window also demotes the app back to `.accessory`.

## Release

Releases go out as an ad-hoc-signed DMG via GitHub Releases, with Sparkle EdDSA-signed appcasts for in-app updates (no Apple Developer account / notarization). Tag `vX.Y.Z` to trigger [.github/workflows/release.yml](.github/workflows/release.yml); local packaging is `./script/release_github.sh <version>`. Full details and the one-time Sparkle key setup are in [docs/release.md](docs/release.md).
