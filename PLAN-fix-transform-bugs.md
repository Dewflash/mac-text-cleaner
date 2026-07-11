# PLAN-fix-transform-bugs — wrapped bullets and multi-line title case

- **Rank:** 2 of 4
- **Dependencies:** run AFTER `PLAN-verify-harness` (the tests added here extend `Tests/TextCleanerTests.swift`, which that plan creates). Independent of `PLAN-clipboard-hotkey` — either may land first.
- **Effort:** ~30 minutes
- **Files touched:** `TextCleaner/TextCleaner.swift`, `Tests/TextCleanerTests.swift`. **Nothing else.**

## Goal

Two confirmed bugs sit directly in the primary user flow (PDF Lines and Smart Clean are headline features). Both were confirmed by executing the current code on 2026-07-11, and the exact fixed code below was verified to compile and pass all tests (50 checks green):

1. **`fixPDFLines` tears wrapped bullet continuations into separate paragraphs.** PDF bullets wrap constantly, so this breaks the flagship "PDF Lines" promise. Confirmed: `TextCleaner.fixPDFLines("• Apples are red\nand tasty\n• Bananas are yellow")` returns `"• Apples are red\n\nand tasty\n\n• Bananas are yellow"` — the continuation `and tasty` becomes its own paragraph. Cause: in `TextCleaner/TextCleaner.swift` lines 41–46, a list item is appended to `paragraphs` immediately and `current` is reset, so the following non-bullet line has nothing to join to; additionally `shouldJoin` (line 199) refuses whenever `previous` is a list item.
2. **`titleCase` only capitalizes after spaces, not after newlines.** Confirmed: `TextCleaner.titleCase("hello world\ngoodbye moon")` returns `"Hello World\ngoodbye Moon"` — `goodbye` stays lowercase. Cause: line 88 splits the whole text on `" "` only, so `world\ngoodbye` is one token.

## Steps

All three code edits are in `TextCleaner/TextCleaner.swift`. Apply them as exact search-and-replace blocks — the "old" text below exists verbatim in the file today.

### 1. Rewrite `fixPDFLines` to keep the current list item joinable

Replace this entire function (currently lines 26–61):

```swift
    static func fixPDFLines(_ text: String) -> String {
        let normalized = normalizePlainText(text)
        let lines = normalized.components(separatedBy: "\n")
        var paragraphs: [String] = []
        var current = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                appendParagraph(current, to: &paragraphs)
                current = ""
                continue
            }

            if isListItem(trimmed) {
                appendParagraph(current, to: &paragraphs)
                current = ""
                appendListItem(trimmed, to: &paragraphs)
                continue
            }

            if current.isEmpty {
                current = trimmed
            } else if shouldJoin(previous: current, next: trimmed) {
                current = join(previous: current, next: trimmed)
            } else {
                appendParagraph(current, to: &paragraphs)
                current = trimmed
            }
        }

        appendParagraph(current, to: &paragraphs)

        return paragraphs.joined(separator: "\n\n")
    }
```

with:

```swift
    static func fixPDFLines(_ text: String) -> String {
        let normalized = normalizePlainText(text)
        let lines = normalized.components(separatedBy: "\n")
        var paragraphs: [String] = []
        var current = ""
        var currentIsListItem = false

        func flushCurrent() {
            if currentIsListItem {
                appendListItem(current, to: &paragraphs)
            } else {
                appendParagraph(current, to: &paragraphs)
            }

            current = ""
            currentIsListItem = false
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushCurrent()
                continue
            }

            if isListItem(trimmed) {
                flushCurrent()
                current = trimmed
                currentIsListItem = true
                continue
            }

            if current.isEmpty {
                current = trimmed
            } else if shouldJoin(previous: current, next: trimmed) {
                current = join(previous: current, next: trimmed)
            } else {
                flushCurrent()
                current = trimmed
            }
        }

        flushCurrent()

        return paragraphs.joined(separator: "\n\n")
    }
```

The key change: a list item now becomes the `current` accumulator (instead of being appended immediately), so following wrapped lines can join it; `flushCurrent()` routes it through `appendListItem` so consecutive bullets still merge into one block.

### 2. Relax the `shouldJoin` guard

Replace:

```swift
    private static func shouldJoin(previous: String, next: String) -> Bool {
        guard !isListItem(previous), !isListItem(next) else {
            return false
        }
```

with:

```swift
    private static func shouldJoin(previous: String, next: String) -> Bool {
        guard !isListItem(next) else {
            return false
        }
```

### 3. Make `titleCase` operate per line

Replace:

```swift
    static func titleCase(_ text: String) -> String {
        let smallWords: Set<String> = ["a", "an", "and", "as", "at", "but", "by", "for", "in", "nor", "of", "on", "or", "per", "the", "to", "vs", "via"]
        let tokens = text.lowercased().split(separator: " ", omittingEmptySubsequences: false)
```

with:

```swift
    static func titleCase(_ text: String) -> String {
        text
            .components(separatedBy: "\n")
            .map(titleCaseLine)
            .joined(separator: "\n")
    }

    private static func titleCaseLine(_ line: String) -> String {
        let smallWords: Set<String> = ["a", "an", "and", "as", "at", "but", "by", "for", "in", "nor", "of", "on", "or", "per", "the", "to", "vs", "via"]
        let tokens = line.lowercased().split(separator: " ", omittingEmptySubsequences: false)
```

The rest of the original function body (the `return tokens.enumerated()...` part) stays exactly where it is — it now forms the body of `titleCaseLine`.

### 4. Add the regression tests

In `Tests/TextCleanerTests.swift`, directly after the line

```swift
    expectEqual(TextCleaner.fixPDFLines("Intro line\n- First item.\n- Second item.\nOutro text here"), "Intro line\n\n- First item.\n- Second item.\n\nOutro text here", "fixPDFLines separates lists from surrounding paragraphs")
```

insert:

```swift

    // Added by PLAN-fix-transform-bugs
    expectEqual(TextCleaner.fixPDFLines("• Apples are red\nand tasty\n• Bananas are yellow"), "• Apples are red and tasty\n• Bananas are yellow", "fixPDFLines joins wrapped bullet continuations")
    expectEqual(TextCleaner.fixPDFLines("- First point.\nNext paragraph starts"), "- First point.\n\nNext paragraph starts", "fixPDFLines does not join after a bullet ending a sentence")
    expectEqual(TextCleaner.fixPDFLines("1. numbered item\nwraps here\n2. second item"), "1. numbered item wraps here\n2. second item", "fixPDFLines joins wrapped numbered-list continuations")
```

And directly after the line

```swift
    expectEqual(TextCleaner.titleCase("a tale of two cities"), "A Tale of Two Cities", "titleCase capitalizes the first word")
```

insert:

```swift

    // Added by PLAN-fix-transform-bugs
    expectEqual(TextCleaner.titleCase("hello world\ngoodbye moon"), "Hello World\nGoodbye Moon", "titleCase capitalizes each line")
    expectEqual(TextCleaner.titleCase("the end\nthe beginning"), "The End\nThe Beginning", "titleCase capitalizes small words at line starts")
```

### 5. Run the gate

```bash
make verify
```

Expected: `ALL TESTS PASSED (50 checks)`.

## Edge cases a weaker model would miss

- **In Step 2, remove ONLY the `!isListItem(previous)` clause — the `!isListItem(next)` guard must stay.** `previous` being a list item is exactly the wrapped-bullet case we now want to join. But if `next` is a list item, joining would fuse two bullets into one line (`"- a - b"`), destroying every multi-bullet list. Deleting the whole guard breaks 3 existing tests; deleting only the `previous` clause keeps everything green.
- **`flushCurrent()` must reset `currentIsListItem = false` after appending.** The flag routes the NEXT flush; if it stays true, an ordinary paragraph following a list gets appended via `appendListItem` and merges into the bullet block.
- **This plan intentionally changes behavior for "bullet without punctuation followed by plain text".** `fixPDFLines("- item\nplain text")` used to produce two paragraphs; it now joins them (`"- item plain text"`) because that pattern is indistinguishable from a wrapped bullet, and wrapped bullets are far more common in PDF text. The disambiguator is sentence punctuation: `"- First point.\nNext paragraph starts"` still splits (see the new test) because `shouldJoin` refuses after `.` `!` `?` `;` `:`. **Do not "fix" this join by re-adding the previous-is-list guard** — that reintroduces the bug this plan exists to fix.
- **The existing test `"Intro line\n- First item.\n- Second item.\nOutro text here"` was written with punctuation-terminated bullets on purpose** so that it passes both before and after this change. If you see it fail, you altered `shouldJoin` incorrectly (most likely dropped the punctuation check) — fix the code, not the test.
- **In Step 3, the original function body must survive verbatim inside `titleCaseLine`.** In particular `index > 0 && smallWords.contains(word)` — per line, the FIRST word of each line is always capitalized even when it is a small word ("the end\nthe beginning" → both "The"s). That is standard title-case behavior and asserted by the new test.
- **Do not touch `appendParagraph`, `appendListItem`, `join`, or `isListItem`.** They are correct as-is; `flushCurrent` calling `appendListItem` with an empty string cannot happen (a list item always sets `current` to non-empty text, and the flag resets on flush).
- The check count printed by the runner is computed, not hard-coded — after this plan `make verify` reports 50, and nothing else needs editing for that.

## Acceptance criteria

1. `make verify` exits 0 and prints `ALL TESTS PASSED (50 checks)`.
2. `git diff --stat` shows exactly two files changed: `TextCleaner/TextCleaner.swift` and `Tests/TextCleanerTests.swift`.
3. Manual spot check (observable): run the app (`make build && open .build/DerivedData/Build/Products/Release/TextCleaner.app`), paste `• Apples are red⏎and tasty⏎• Bananas are yellow` into the input box, click **PDF Lines** — the output panel shows the two bullets on two lines with "and tasty" merged into the first bullet. Quit the app afterwards.

**Suggested commit message:** `fix: join wrapped list continuations and title-case every line`
