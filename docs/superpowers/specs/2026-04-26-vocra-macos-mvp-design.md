# Vocra macOS MVP Design

Date: 2026-04-26

## Summary

Vocra is a native macOS menu bar app for reading English AI content across local apps and browsers. The first MVP focuses on one core workflow: select English text anywhere on the Mac, press one global shortcut, and get an AI-powered explanation. If the selected text is a word or technical phrase, Vocra also saves it to a local vocabulary notebook for spaced review.

The first phase targets macOS 26+ and uses Swift and SwiftUI with a narrow AppKit bridge for system-level behavior. OCR, cloud sync, accounts, browser extensions, and mobile apps are out of scope for this phase.

## Goals

- Provide one global shortcut for both sentence explanation and vocabulary collection.
- Read selected text from common macOS apps, browsers, terminals, and editor surfaces without requiring a browser extension.
- Classify selected text locally as `word`, `phrase`, or `sentence` with millisecond-level overhead.
- Show results in a draggable Liquid Glass floating panel.
- Support OpenAI-compatible API providers through user-configurable settings.
- Let users fully customize prompts for word explanation, phrase explanation, sentence explanation, and vocabulary card generation.
- Automatically collect words and phrases into a local review system.
- Provide active review and optional daily reminders.

## Non-Goals

- OCR or screen image recognition.
- Cloud sync, account login, or cross-device data.
- Browser extensions.
- iOS or mobile clients.
- Complex spaced-repetition algorithms.
- Shared vocabulary libraries.
- Automatic full-page or surrounding-webpage context extraction.

## Product Shape

Vocra is a menu bar resident app with an optional main window.

Daily reading flow:

```text
Select English text
→ Press global shortcut
→ Vocra reads selected text
→ Vocra classifies the text locally
→ Vocra calls the configured AI API
→ Vocra shows a Liquid Glass floating panel
→ If the text is a word or phrase, Vocra saves it to the vocabulary notebook
```

Menu bar actions:

- Start today's review.
- Open vocabulary notebook.
- Open settings.
- Pause shortcut listening.
- Quit Vocra.

Main window sections:

- Vocabulary notebook.
- Today's review.
- Prompt management.
- API settings.
- Shortcut settings.
- Basic statistics.

## Text Capture

The first phase does not use OCR. Text capture follows a layered strategy:

1. Try macOS Accessibility APIs to read the selected text from the focused UI element.
2. If Accessibility text extraction fails, temporarily simulate `Command-C`, read the clipboard, and restore the previous clipboard contents.
3. If both methods fail, show a clear message asking the user to copy text manually and retry.

First launch should guide the user through required permissions:

- Accessibility permission for reading selected text and fallback copy behavior.
- Notification permission only if the user enables daily review reminders.

## Text Classification

Classification runs locally before any AI call. It must be deterministic, fast, and easy to override from the result panel.

Preprocessing:

- Trim leading and trailing whitespace.
- Collapse repeated spaces.
- Normalize line breaks.
- Remove meaningless leading or trailing punctuation where safe.

Primary rule:

```text
0 spaces → word
1 space → phrase
2+ spaces → sentence candidate
```

Sentence candidates receive a lightweight second pass:

- Contains sentence punctuation such as `.`, `?`, `!`, `;`, or line breaks → `sentence`.
- Contains a small set of predicate or auxiliary markers such as `is`, `are`, `was`, `were`, `has`, `have`, `can`, `should`, `will`, `returns`, `failed`, `means`, or `refers` → `sentence`.
- Has five or fewer words and no clear sentence marker → `phrase`.
- Otherwise → `sentence`.

Examples:

| Selected text | Classification |
| --- | --- |
| `embedding` | `word` |
| `context window` | `phrase` |
| `retrieval augmented generation` | `phrase` |
| `The model failed to follow the instruction.` | `sentence` |
| `this function returns a string` | `sentence` |

The floating panel always exposes a correction control so the user can switch between word or phrase explanation and sentence explanation when classification is wrong.

## Floating Panel

The explanation surface is a medium-sized floating panel.

Default behavior:

- Initial size around `480 x 520`.
- Draggable.
- Resizable.
- Remembers last position and size.
- Reuses the same panel on repeated shortcut triggers.
- Closes with `Esc`.
- Shows above normal app windows.

Visual design:

- Native macOS 26+ Liquid Glass.
- Whole-window transparent glass treatment.
- No darker nested content region.
- No card-inside-card layout.
- Automatically follows system light and dark appearance.
- Uses semantic text styles such as primary and secondary foreground colors.
- Uses system vibrancy and subtle text treatment for readability instead of adding a separate opaque content background.
- Respects accessibility settings such as Reduce Transparency through system-provided fallbacks.

Implementation direction:

- SwiftUI owns panel content.
- A narrow AppKit `NSPanel` bridge owns floating utility-window behavior.
- Use SwiftUI Liquid Glass APIs such as `glassEffect` and `GlassEffectContainer` where available.
- Use system materials and semantic colors rather than hardcoded translucent fills.

Panel content:

- Header: current mode label, correction switch, close control.
- Body: Markdown-rendered AI response.
- Footer for word and phrase: undo collection, mark mastered, review later.
- Footer for sentence: copy result, regenerate, switch explanation mode.

## API Settings

Vocra supports OpenAI-compatible API providers in the first phase.

Settings fields:

- API key.
- Base URL.
- Model.
- Temperature.
- Timeout.
- Test connection.

Security:

- Store API keys in macOS Keychain.
- Do not store plaintext API keys in the local database.

The API client should be isolated behind a small interface so provider details do not leak into UI or review logic.

## Prompt System

Prompt customization is a first-class feature. Vocra ships with defaults, but users may fully replace them.

Prompt slots:

- Word explanation prompt.
- Phrase or technical term explanation prompt.
- Sentence explanation prompt.
- Vocabulary card generation prompt.

Supported variables:

- `{{text}}`
- `{{type}}`
- `{{sourceApp}}`
- `{{surroundingContext}}`
- `{{createdAt}}`

`{{surroundingContext}}` is reserved for future context capture and may be empty in the first phase.

The explanation response is rendered as Markdown. Vocabulary card content is also generated through a prompt and stored as Markdown.

Prompt-driven output controls what the user learns. Scheduling metadata remains controlled by Vocra so review behavior stays reliable.

## Vocabulary Notebook

Words and phrases are automatically saved after the shortcut flow completes. Sentences are not automatically saved as vocabulary items.

The panel must provide fast recovery actions:

- Undo collection.
- Mark mastered.
- Review later.

Stored vocabulary fields:

- `id`
- `text`
- `type` (`word` or `phrase`)
- `cardMarkdown`
- `sourceApp`
- `createdAt`
- `updatedAt`
- `lastReviewedAt`
- `nextReviewAt`
- `reviewCount`
- `status`
- `familiarityLevel`

Duplicate handling:

- Normalize text for lookup.
- If an existing active card is found, update source metadata and show the existing card instead of creating a duplicate.
- If the card was previously mastered, show an option to reactivate it.

## Review System

Users can start review from the menu bar or main window.

Review card behavior:

- Front: selected English word or phrase only, with no hint.
- Back: prompt-generated Markdown card content.
- Click or keyboard action flips the card.

Review actions:

- Forgot.
- Vague.
- Familiar.
- Mastered.

Initial scheduling:

```text
Forgot → today or tomorrow
Vague → 3 days later
Familiar → 7-14 days later
Mastered → remove from active review
```

Review reminders:

- Users can always start review manually.
- Optional daily reminder is available.
- Reminder is off by default.

## Data Storage

The first phase should use a local database suitable for a native macOS app. SQLite is a good default because it is portable, inspectable, and stable. SwiftData or Core Data can be considered if the project values deeper Apple framework integration, but the storage boundary should remain abstract enough to avoid leaking persistence details into UI code.

Recommended storage boundaries:

- `VocabularyRepository`
- `PromptRepository`
- `SettingsRepository`
- `ReviewScheduler`
- `APIKeyStore`

`APIKeyStore` uses Keychain. The other repositories use local app storage.

## Error Handling

Text capture errors:

- Show a short panel message when selected text cannot be read.
- Offer a retry action.
- Mention required Accessibility permission if permission is missing.

API errors:

- Show provider, status, and a concise explanation.
- Preserve the selected text so the user can retry.
- Keep saved vocabulary state reversible if card generation fails.

Prompt errors:

- If a prompt references an unknown variable, show validation feedback in settings.
- If model output is empty, show a retryable empty-result state.

Database errors:

- Avoid losing the selected text.
- Show a local storage error with a retry option.
- Log diagnostic detail for debugging.

## Architecture

High-level modules:

- `AppShell`: menu bar app lifecycle, main window, settings entry.
- `ShortcutService`: global shortcut registration and pause/resume state.
- `SelectionReader`: Accessibility-based selected text reader and clipboard fallback.
- `TextClassifier`: local word/phrase/sentence classifier.
- `PromptRenderer`: prompt template variable substitution and validation.
- `AIClient`: OpenAI-compatible request/response layer.
- `FloatingPanelController`: AppKit bridge for the Liquid Glass result panel.
- `ExplanationView`: SwiftUI panel content and Markdown rendering.
- `VocabularyRepository`: local vocabulary persistence.
- `ReviewScheduler`: review interval decisions.
- `ReviewView`: card review flow.
- `SettingsStore`: non-secret app settings.
- `APIKeyStore`: Keychain-backed secret storage.

Data flow:

```text
ShortcutService
→ SelectionReader
→ TextClassifier
→ PromptRenderer
→ AIClient
→ FloatingPanelController / ExplanationView
→ VocabularyRepository, when type is word or phrase
→ ReviewScheduler, when review actions occur
```

## MVP Acceptance Criteria

- User can configure an OpenAI-compatible API key, base URL, and model.
- User can set one global shortcut.
- User can select text in common apps and trigger Vocra.
- Vocra can classify word, phrase, and sentence selections with the agreed local rules.
- Vocra can show AI output in a medium Liquid Glass floating panel.
- User can switch explanation mode from the panel when classification is wrong.
- Words and phrases are automatically saved to the vocabulary notebook.
- User can undo collection or mark a word or phrase mastered from the panel.
- User can review due vocabulary cards from the menu bar or main window.
- Review actions update the next review date.
- Daily reminders can be enabled, but are off by default.
- API keys are stored in Keychain, not plaintext app storage.

## Implementation Choices To Finalize

- Exact local persistence technology: SQLite directly, SQLite through a wrapper, SwiftData, or Core Data.
- Exact Markdown renderer for SwiftUI.
- Exact global shortcut library or native Carbon/EventTap approach.
