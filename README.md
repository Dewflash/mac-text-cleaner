# TextCleaner

TextCleaner is a small macOS menu bar app for cleaning and reformatting copied text before pasting it elsewhere.

It strips rich formatting by reading and writing plain clipboard text, fixes PDF-style broken line breaks, normalizes spaces, converts capitalization, creates Markdown snippets, formats chat text, and keeps your five most recent cleaned outputs.

## Install

1. Download `release/TextCleaner-1.1.0.dmg` (or the `.zip`).
2. Drag `TextCleaner.app` to your Applications folder and launch it.
3. If macOS warns about an unidentified developer, Control-click the app in Finder and choose Open. The app is ad-hoc signed and not notarized.

Requires macOS 13 or later (Apple Silicon).

## Use

1. Copy messy text from a PDF, website, email, or message.
2. Click TextCleaner in the menu bar.
3. Click `Clean Clipboard` to clean and copy the result back to the clipboard.
4. Paste anywhere.

You can also paste or edit text in the popover. Each cleanup action updates the output preview and copies the cleaned result back to the clipboard immediately.

## Tools

- Plain text, PDF lines, and Smart Clean
- Sentence button, plus Case menu: title case, lowercase, uppercase
- Markdown menu: quote, bullet list, comma list, bold, italic, code
- Chat menu: bold, italic, monospace, strikethrough
- Recent cleaned outputs: click any recent item to copy it again

## Build from source

    make build             # visible app at build/TextCleaner.app
    make verify            # release build + unit tests (needs a logged-in macOS session)
    Scripts/package.sh     # rebuild release/TextCleaner-<version>.dmg and .zip
