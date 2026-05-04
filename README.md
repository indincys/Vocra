# Vocra

Vocra is a macOS 26+ menu bar app I built for the moments when I am reading English on a Mac and do not want to leave the app I am already in just to ask what a word or sentence means.

The flow is simple: select some text, press one shortcut, and Vocra reads the selection, classifies it locally, sends it to an OpenAI-compatible model, and shows the result in a floating panel. If the selection is a word or phrase, Vocra also saves a vocabulary card locally so I can review it later.

I kept the app focused on purpose. There is no account system, no cloud sync, and no browser extension. It lives in the menu bar, does the reading work, and gets out of the way.

## What It Does

- Reads the current selection from the focused app through macOS Accessibility.
- Falls back to a temporary `Cmd-C` copy if Accessibility text extraction does not work.
- Classifies the selection locally as `word`, `phrase`, or `sentence`.
- Sends the text to an OpenAI-compatible API.
- Renders structured sentence analysis, word explanations, and vocabulary cards in SwiftUI.
- Saves words and phrases to a local SQLite notebook.
- Keeps review simple with `forgot`, `vague`, `familiar`, and `mastered`.
- Lets me edit prompts, learning preferences, keyboard shortcut, and API profiles in Settings.
- Optionally schedules a daily review reminder.

## How It Works

```text
Selected text
  -> global shortcut
  -> capture + local classification
  -> prompt rendering
  -> OpenAI-compatible API
  -> structured JSON response
  -> floating panel
  -> local notebook / review
```

I split the code into two targets:

- `Sources/VocraCore` holds the shared models, services, prompt rendering, validation, SQLite storage, Keychain access, and the OpenAI-compatible client.
- `Sources/Vocra` holds the app shell, SwiftUI views, the floating panel, settings, and the small AppKit bridge needed for the global shortcut and panel behavior.

The explanation format is structured JSON instead of free-form Markdown. That keeps the UI stable even when prompts change. Vocra validates the JSON before rendering it, and if the model output is off, it retries once with a repair prompt.

## Main Screens

- Vocabulary: the local notebook.
- Review: due cards and the simple review flow.
- Settings: API profiles, prompt editing, learning preferences, shortcut, and reminders.

The floating panel is the part I use most. It shows the explanation, lets me switch between word / term / sentence mode when the classifier gets it wrong, and gives a quick copy action for the rendered summary. Press `Esc` to close it.

## Using Vocra

1. Add your API key in Settings.
2. Pick an OpenAI-compatible base URL and model if you need something other than the default.
3. Grant Accessibility permission so Vocra can read selected text from other apps.
4. Select some English text anywhere on macOS.
5. Press the shortcut, which is `Option-Space` by default.
6. If Vocra guessed the wrong mode, switch it in the panel and keep going.
7. Words and phrases are stored automatically. Sentences are not added to the notebook.

If you turn on reminders, Vocra will also ask for Notification permission and schedule a daily review time.

## Settings

Vocra works with OpenAI-compatible providers, not just one fixed endpoint.

In Settings I usually set:

- API base URL
- model name
- API key
- explanation depth
- example count
- Chinese explanation style
- diagram density
- global shortcut
- daily reminder time

The API key never goes into the database. It stays in Keychain.

Prompt templates are editable too. I keep three schema prompts in the app:

- sentence analysis
- word and term explanation
- vocabulary card generation

## Permissions

Vocra needs Accessibility permission to read selected text from other apps.

If Accessibility extraction fails, it can fall back to a temporary `Cmd-C` copy and then restore the clipboard, but Accessibility is still the main path.

Notification permission is only needed if daily review reminders are enabled.

I do not rely on paid Apple signing for this project. For local builds and releases I use a stable self-signed code-signing identity so macOS does not treat every rebuild like a different app. That keeps Accessibility permission much less annoying across updates.

## Development

This is a Swift Package project. The helper scripts build the app bundle for me.

Build and launch the local dev app:

```bash
./script/build_and_run.sh
```

Package without launching:

```bash
VOCRA_APP_VARIANT=dev ./script/build_and_run.sh --package
```

Package the release app:

```bash
VOCRA_APP_VARIANT=release ./script/build_and_run.sh --package
```

Create release assets:

```bash
./script/release_github.sh <version>
```

If I want to use a different local signing identity, I set:

```bash
VOCRA_CODESIGN_IDENTITY="My Local Code Signing Cert" ./script/build_and_run.sh
```

The default local development bundle is `Vocra Dev.app`, while the release bundle is `Vocra.app`.

## Release Notes

Vocra uses Sparkle for in-app updates and GitHub Releases for distribution. The release flow builds the app, creates a DMG, and generates an appcast for Sparkle.

The release script expects Sparkle keys in the environment when I package a release locally:

```bash
SPARKLE_PUBLIC_KEY=... \
SPARKLE_PRIVATE_KEY=... \
GITHUB_REPOSITORY=owner/repo \
./script/release_github.sh 0.1.0
```

## A Few Notes

I built Vocra around the workflow I actually wanted while reading:

1. grab the text
2. get a clean explanation fast
3. save the useful bits without extra steps
4. review later without opening another app

That is basically the whole app.
