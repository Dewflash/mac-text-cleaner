# PLAN-verify-harness — one-command mechanical verification

- **Rank:** 1 of 4 (execute first)
- **Dependencies:** none — run this before every other plan
- **Effort:** ~30 minutes
- **Files touched:** `Makefile` (new), `Tests/TextCleanerTests.swift` (new), `.gitignore` (append one line). **Nothing else.** Do NOT touch `TextCleaner.xcodeproj/project.pbxproj` or any file under `TextCleaner/`.

## Goal

The product promise is: *copy messy text, invoke TextCleaner, paste clean text — the clipboard always ends up holding exactly what the app shows.* Today nothing mechanically guards that promise: the repo has zero tests and no verify command, so every later change (bug fixes, hotkey, release) would land blind. This plan creates the `make verify` gate that every other plan's acceptance criteria depend on.

Both the approach and the exact file contents below were verified by running them on this machine on 2026-07-11: the harness compiles with stock `swiftc` and reports `ALL TESTS PASSED (45 checks)` at commit `d755a7f`.

## Background you need (do not skip)

- The app has exactly 3 source files. `TextCleaner/TextCleaner.swift` is pure Foundation (the transforms). `TextCleaner/TextCleanerModel.swift` is the AppKit view model — it already takes an injected `NSPasteboard` and `UserDefaults` in `init(pasteboard:defaults:)`, which is what makes it testable without touching the real clipboard. `TextCleaner/TextCleanerApp.swift` is SwiftUI UI and is NOT compiled into the tests.
- There is no test target in the Xcode project, and we are not adding one (editing `project.pbxproj` by hand is error-prone). Instead the tests are a standalone executable compiled directly with `swiftc` against the two non-UI source files.

## Steps

### 1. Create `Tests/TextCleanerTests.swift`

Create the directory `Tests/` at the repo root and write exactly this content to `Tests/TextCleanerTests.swift`:

```swift
import AppKit
import Foundation

// Minimal dependency-free test runner. Compiled together with the app sources
// by `make verify`; exits 0 when every expectation passes, 1 otherwise.

var failures: [String] = []
var passCount = 0

func expectEqual(_ actual: String, _ expected: String, _ name: String) {
    if actual == expected {
        passCount += 1
    } else {
        failures.append("\(name)\n  expected: \(expected.debugDescription)\n  actual:   \(actual.debugDescription)")
    }
}

func expectTrue(_ condition: Bool, _ name: String) {
    if condition {
        passCount += 1
    } else {
        failures.append("\(name)\n  expected true, got false")
    }
}

func runTransformTests() {
    // normalizePlainText
    expectEqual(TextCleaner.normalizePlainText("a\r\nb\rc"), "a\nb\nc", "normalizePlainText converts CRLF and CR to LF")
    expectEqual(TextCleaner.normalizePlainText("a\u{00A0}b"), "a b", "normalizePlainText replaces non-breaking spaces")
    expectEqual(TextCleaner.normalizePlainText("  hello \t  world  "), "hello world", "normalizePlainText collapses inline whitespace and trims")
    expectEqual(TextCleaner.normalizePlainText("line1  \n\n  line2"), "line1\n\nline2", "normalizePlainText keeps blank lines")

    // fixPDFLines
    expectEqual(TextCleaner.fixPDFLines("This is a\nwrapped sentence."), "This is a wrapped sentence.", "fixPDFLines joins wrapped lines")
    expectEqual(TextCleaner.fixPDFLines("Para one.\n\nPara two."), "Para one.\n\nPara two.", "fixPDFLines keeps paragraph breaks")
    expectEqual(TextCleaner.fixPDFLines("hyphen-\nated word"), "hyphenated word", "fixPDFLines rejoins hyphenated line breaks")
    expectEqual(TextCleaner.fixPDFLines("Ends with period.\nNew sentence starts"), "Ends with period.\n\nNew sentence starts", "fixPDFLines breaks after sentence punctuation")
    expectEqual(TextCleaner.fixPDFLines("- item one\n- item two"), "- item one\n- item two", "fixPDFLines keeps bullet items on separate lines")
    expectEqual(TextCleaner.fixPDFLines("1. first\n2. second"), "1. first\n2. second", "fixPDFLines keeps numbered items on separate lines")
    expectEqual(TextCleaner.fixPDFLines("Intro line\n- First item.\n- Second item.\nOutro text here"), "Intro line\n\n- First item.\n- Second item.\n\nOutro text here", "fixPDFLines separates lists from surrounding paragraphs")

    // smartClean
    expectEqual(TextCleaner.smartClean("THIS IS ALL UPPERCASE TEXT. SECOND SENTENCE HERE."), "This is all uppercase text. Second sentence here.", "smartClean sentence-cases mostly-uppercase text")
    expectEqual(TextCleaner.smartClean("Normal mixed case text stays as it is written."), "Normal mixed case text stays as it is written.", "smartClean leaves normal text alone")

    // sentenceCase
    expectEqual(TextCleaner.sentenceCase("hello there. how are you? fine!"), "Hello there. How are you? Fine!", "sentenceCase capitalizes after . ? !")
    expectEqual(TextCleaner.sentenceCase("WHAT IS THIS"), "What is this", "sentenceCase lowercases the rest")

    // titleCase
    expectEqual(TextCleaner.titleCase("the quick brown fox and the lazy dog"), "The Quick Brown Fox and the Lazy Dog", "titleCase keeps small words lowercase")
    expectEqual(TextCleaner.titleCase("a tale of two cities"), "A Tale of Two Cities", "titleCase capitalizes the first word")

    // markdown
    expectEqual(TextCleaner.markdownQuote("line one\n\nline two"), "> line one\n>\n> line two", "markdownQuote prefixes every line")
    expectEqual(TextCleaner.markdownBulletList("apple\nbanana\n\ncherry"), "- apple\n- banana\n- cherry", "markdownBulletList bullets non-empty lines")
    expectEqual(TextCleaner.commaSeparatedLineList("apple\nbanana\ncherry"), "apple, banana, cherry", "commaSeparatedLineList joins lines with commas")
    expectEqual(TextCleaner.markdownBold("hello\nworld"), "**hello**\n**world**", "markdownBold wraps each line")
    expectEqual(TextCleaner.markdownItalic("hello"), "*hello*", "markdownItalic wraps each line")
    expectEqual(TextCleaner.markdownInlineCode("let x = 1"), "`let x = 1`", "markdownInlineCode wraps in backticks")
    expectEqual(TextCleaner.markdownInlineCode("use `git` here"), "`` use `git` here ``", "markdownInlineCode escapes embedded backticks")

    // chat
    expectEqual(TextCleaner.chatBold("hi there"), "*hi there*", "chatBold uses single asterisks")
    expectEqual(TextCleaner.chatItalic("hi there"), "_hi there_", "chatItalic uses underscores")
    expectEqual(TextCleaner.chatMonospace("hi there"), "`hi there`", "chatMonospace uses backticks")
    expectEqual(TextCleaner.chatStrikethrough("hi there"), "~hi there~", "chatStrikethrough uses tildes")
}

@MainActor
func runModelTests() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.dewflash.TextCleaner.tests"))
    let suiteName = "com.dewflash.TextCleaner.tests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    func freshModel() -> TextCleanerModel {
        TextCleanerModel(pasteboard: pasteboard, defaults: defaults)
    }

    // loadClipboard reads the injected pasteboard
    pasteboard.clearContents()
    pasteboard.setString("  spaced   input  ", forType: .string)
    let model = freshModel()
    model.loadClipboard()
    expectEqual(model.input, "  spaced   input  ", "loadClipboard copies pasteboard text into input")

    // perform(.plainText) cleans, publishes output, and writes it back to the pasteboard
    model.perform(.plainText)
    expectEqual(model.output, "spaced input", "perform(.plainText) normalizes input")
    expectEqual(pasteboard.string(forType: .string) ?? "", "spaced input", "perform(.plainText) copies output to pasteboard")
    expectEqual(model.recentOutputs.first ?? "", "spaced input", "cleaned output lands at the front of recents")

    // cleanClipboard runs smartClean on pasteboard content
    pasteboard.clearContents()
    pasteboard.setString("SHOUTED CLIPBOARD TEXT. SECOND SENTENCE HERE.", forType: .string)
    model.cleanClipboard()
    expectEqual(pasteboard.string(forType: .string) ?? "", "Shouted clipboard text. Second sentence here.", "cleanClipboard smart-cleans and copies back")

    // recents: dedupe and cap at 5, newest first
    let capModel = freshModel()
    for index in 1...6 {
        capModel.input = "recent item \(index)"
        capModel.perform(.plainText)
    }
    expectTrue(capModel.recentOutputs.count == 5, "recents keep at most 5 entries")
    expectEqual(capModel.recentOutputs.first ?? "", "recent item 6", "recents put the newest entry first")
    expectTrue(!capModel.recentOutputs.contains("recent item 1"), "recents evict the oldest entry")

    capModel.input = "recent item 4"
    capModel.perform(.plainText)
    expectTrue(capModel.recentOutputs.filter { $0 == "recent item 4" }.count == 1, "recents dedupe repeated outputs")
    expectEqual(capModel.recentOutputs.first ?? "", "recent item 4", "recents move repeated output to the front")

    // copyRecentOutput restores a stored value to output and pasteboard
    pasteboard.clearContents()
    capModel.copyRecentOutput("recent item 3")
    expectEqual(pasteboard.string(forType: .string) ?? "", "recent item 3", "copyRecentOutput copies the stored value")
    expectEqual(capModel.output, "recent item 3", "copyRecentOutput shows the value in output")

    // recents persist through UserDefaults
    let secondModel = freshModel()
    expectEqual(secondModel.recentOutputs.first ?? "", "recent item 4", "recents persist across model instances")

    // clear resets input and output
    capModel.clear()
    expectEqual(capModel.input, "", "clear empties input")
    expectEqual(capModel.output, "", "clear empties output")

    // canCleanClipboard tracks pasteboard state
    pasteboard.clearContents()
    expectTrue(!capModel.canCleanClipboard, "canCleanClipboard is false for an empty pasteboard")
    pasteboard.setString("something", forType: .string)
    expectTrue(capModel.canCleanClipboard, "canCleanClipboard is true when text is available")

    defaults.removePersistentDomain(forName: suiteName)
}

@main
struct TextCleanerTests {
    @MainActor
    static func main() {
        runTransformTests()
        runModelTests()

        if failures.isEmpty {
            print("ALL TESTS PASSED (\(passCount) checks)")
            exit(0)
        }

        print("FAILED \(failures.count) of \(failures.count + passCount) checks:\n")
        for failure in failures {
            print("- \(failure)\n")
        }
        exit(1)
    }
}
```

### 2. Create `Makefile` at the repo root

Exactly this content. **Recipe lines (the indented ones) must start with a real TAB character, not spaces** — `make` fails with `missing separator` otherwise.

```makefile
.PHONY: verify build test clean

verify: build test

build:
	xcodebuild -scheme TextCleaner -configuration Release -derivedDataPath .build/DerivedData -quiet build

test:
	@mkdir -p .build
	swiftc -parse-as-library TextCleaner/TextCleaner.swift TextCleaner/TextCleanerModel.swift Tests/TextCleanerTests.swift -o .build/textcleaner-tests
	.build/textcleaner-tests

clean:
	rm -rf .build
```

### 3. Append to `.gitignore`

Add this single line at the end of the existing `.gitignore` (keep the four lines already there):

```
.build/
```

### 4. Run the gate

```bash
make verify
```

Expected: xcodebuild completes silently (exit 0), then the test runner prints `ALL TESTS PASSED (45 checks)`.

### 5. Prove the gate can fail (canary check)

Temporarily edit one expectation in `Tests/TextCleanerTests.swift` — change `"a\nb\nc"` to `"a\nb\nWRONG"` — and run `make verify` again. It must print a `FAILED 1 of 45 checks` block and exit nonzero (`echo $?` → not 0). Then **revert that edit** and confirm `make verify` is green again. A gate that cannot fail is not a gate; this step catches a silently miswired harness.

## Edge cases a weaker model would miss

- **Do not add `Tests/TextCleanerTests.swift` to the Xcode project.** The file declares `@main`, and `TextCleaner/TextCleanerApp.swift` also declares `@main`. If the test file gets added to the app target, the app no longer builds ("multiple @main"). The tests are compiled ONLY by the `swiftc` line in the Makefile. This is also why you must not edit `project.pbxproj` at all in this plan.
- **`-parse-as-library` is mandatory in the swiftc line.** Without it, swiftc treats the first file as an implicit `main` and the `@main` attribute in the test file becomes a duplicate-main compile error.
- **`TextCleaner/TextCleanerApp.swift` must NOT be in the swiftc compile list.** It imports SwiftUI and declares the app `@main`; including it breaks the test build for both reasons above.
- **The tests deliberately use a named pasteboard (`NSPasteboard(name:)`) and a defaults suite, not `.general` / `.standard`.** Using `.general` would overwrite the user's real clipboard every time `make verify` runs — the harness must never have side effects on the machine. Don't "simplify" this.
- **Expected strings are exact, including `\u{00A0}` (non-breaking space), `\t`, and `\n`.** They encode verified current behavior. If a test fails, the code changed — do not edit an expected string to make it pass (that's the forbidden gate-weakening in AGENTS.md).
- **Model tests share state in sequence.** The `capModel` block feeds the persistence check (`secondModel`) and the `copyRecentOutput` check ("recent item 3" must still be in recents from the loop). Do not reorder or split them.
- **`make verify` needs a logged-in macOS GUI session** (the pasteboard daemon). It works from Terminal on the Mac; it may fail over a bare SSH session. It opens no windows.
- **Makefile TAB trap** (repeated on purpose): each recipe line starts with a TAB. Copy-paste that converts tabs to spaces produces `Makefile:4: *** missing separator`.

## Acceptance criteria

1. `test -f Makefile -a -f Tests/TextCleanerTests.swift` exits 0.
2. `make verify` exits 0 and prints `ALL TESTS PASSED (45 checks)`.
3. The canary check in Step 5 was performed: a deliberately broken expectation made `make verify` exit nonzero, and it was reverted.
4. `git status --porcelain` lists only: `Makefile`, `Tests/TextCleanerTests.swift`, `.gitignore` (and nothing under `TextCleaner/` or the `.xcodeproj`).
5. `git diff -- .gitignore` shows exactly one added line: `.build/`.

**Suggested commit message:** `test: add make verify harness (build + unit tests)`
