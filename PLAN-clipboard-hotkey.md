# PLAN-clipboard-hotkey — ⌃⇧⌘C cleans the clipboard from anywhere

- **Rank:** 3 of 4
- **Dependencies:** run AFTER `PLAN-verify-harness` (needs the `make verify` gate). Independent of `PLAN-fix-transform-bugs` — either may land first.
- **Effort:** ~1–2 hours including the manual check
- **Files touched:** `TextCleaner/TextCleanerApp.swift`, `TextCleaner/TextCleanerModel.swift`. **Nothing else.** In particular: no new `.swift` files, no `project.pbxproj` edits, no README edits (README is rewritten in `PLAN-final-polish`).

## Goal

The product promise is one action between messy copy and clean paste. Today the fastest path is: copy → click menu bar icon → click "Clean Clipboard" → click away → paste. This plan collapses that to a single keystroke: **⌃⇧⌘C anywhere smart-cleans the clipboard in place** (a soft "Pop" confirms success; the popover's output, status, and Recent list reflect the clean the next time it opens). This is the one capability that completes the product story for keyboard-centric use; nothing else new is in scope.

Feasibility and the exact code below were verified on this machine on 2026-07-11: `RegisterEventHotKey` returned `noErr` for ⌃⇧⌘C, the full diff typechecks, and the existing test suite passes unchanged against the modified model.

## Steps

### 0. Feasibility probe (cheap, do this first)

Write this to `/tmp/hotkeyprobe.swift`:

```swift
import Carbon

let signature = OSType(0x54434C4E) // "TCLN"
var hotKeyID = EventHotKeyID(signature: signature, id: 1)
var hotKeyRef: EventHotKeyRef?

let status = RegisterEventHotKey(
    UInt32(kVK_ANSI_C),
    UInt32(controlKey | shiftKey | cmdKey),
    hotKeyID,
    GetApplicationEventTarget(),
    0,
    &hotKeyRef
)

if status == noErr, let ref = hotKeyRef {
    UnregisterEventHotKey(ref)
    print("HOTKEY PROBE OK: RegisterEventHotKey returned noErr")
    exit(0)
}

print("HOTKEY PROBE FAILED: status \(status)")
exit(1)
```

Run:

```bash
swiftc /tmp/hotkeyprobe.swift -o /tmp/hotkeyprobe && /tmp/hotkeyprobe && rm /tmp/hotkeyprobe /tmp/hotkeyprobe.swift
```

Expected output: `HOTKEY PROBE OK: RegisterEventHotKey returned noErr`.

**If this fails: STOP and report — do not improvise.** Log the exact output to `BLOCKERS.md`, revert nothing (you haven't changed anything yet), and move on to the next independent plan. A failed probe most likely means another app now owns ⌃⇧⌘C; do not pick a different key combination on your own — that is a product decision.

### 1. Edit `TextCleaner/TextCleanerModel.swift`

Three exact replacements.

**1a.** Replace:

```swift
@MainActor
final class TextCleanerModel: ObservableObject {
    @Published var input = ""
```

with:

```swift
@MainActor
final class TextCleanerModel: ObservableObject {
    static let shared = TextCleanerModel()

    @Published var input = ""
```

**1b.** Replace the whole `cleanClipboard` function:

```swift
    func cleanClipboard() {
        guard let text = clipboardText else {
            status = "Clipboard has no plain text."
            NSSound.beep()
            return
        }

        input = text
        let cleaned = TextCleaner.smartClean(text)
        output = cleaned
        copyCleanedOutput(cleaned, status: "Cleaned clipboard and copied result.")
    }
```

with:

```swift
    @discardableResult
    func cleanClipboard() -> Bool {
        guard let text = clipboardText else {
            status = "Clipboard has no plain text."
            NSSound.beep()
            return false
        }

        input = text
        let cleaned = TextCleaner.smartClean(text)
        output = cleaned
        return copyCleanedOutput(cleaned, status: "Cleaned clipboard and copied result.")
    }

    func cleanClipboardFromHotKey() {
        if cleanClipboard() {
            NSSound(named: "Pop")?.play()
        }
    }
```

**1c.** Replace:

```swift
    private func copyCleanedOutput(_ value: String, status: String) {
        if copy(value, status: status) {
            addRecentOutput(value)
        }
    }
```

with:

```swift
    @discardableResult
    private func copyCleanedOutput(_ value: String, status: String) -> Bool {
        let copied = copy(value, status: status)

        if copied {
            addRecentOutput(value)
        }

        return copied
    }
```

### 2. Edit `TextCleaner/TextCleanerApp.swift`

Three exact replacements.

**2a.** Replace:

```swift
import AppKit
import SwiftUI
```

with:

```swift
import AppKit
import Carbon
import SwiftUI
```

**2b.** Replace:

```swift
    @StateObject private var model = TextCleanerModel()
```

with:

```swift
    @StateObject private var model = TextCleanerModel.shared
```

**2c.** Replace the whole `AppDelegate` class:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

with:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        HotKeyCenter.shared.registerCleanClipboardHotKey {
            Task { @MainActor in
                TextCleanerModel.shared.cleanClipboardFromHotKey()
            }
        }
    }
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    private init() {}

    func registerCleanClipboardHotKey(_ handler: @escaping () -> Void) {
        guard hotKeyRef == nil else {
            return
        }

        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                center.handler?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x54434C4E), id: 1)

        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(controlKey | shiftKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
```

### 3. Fast typecheck, then the gate

```bash
swiftc -typecheck -parse-as-library TextCleaner/TextCleanerApp.swift TextCleaner/TextCleaner.swift TextCleaner/TextCleanerModel.swift
make verify
```

Both must exit 0. (`make verify` prints 45 or 50 checks depending on whether `PLAN-fix-transform-bugs` already landed — either is fine; what matters is `ALL TESTS PASSED`.)

### 4. Manual verification (required — the hotkey cannot be exercised by the unit tests)

1. Make sure no other copy of TextCleaner is running (check the menu bar; quit it via its Quit button if present).
2. `make build && open .build/DerivedData/Build/Products/Release/TextCleaner.app`
3. In another app (Notes, TextEdit), type and copy: `THIS IS SHOUTED TEXT. IT NEEDS CLEANING.`
4. With that other app still focused, press **⌃⇧⌘C** (Control+Shift+Command+C). Pass condition: you hear a soft "Pop" sound.
5. Paste. Pass condition: `This is shouted text. It needs cleaning.`
6. Open the TextCleaner popover from the menu bar. Pass condition: output shows the cleaned text, status reads "Cleaned clipboard and copied result.", and the Recent list's first entry is the cleaned text.
7. Take a screenshot to the clipboard (⌃⇧⌘4, drag a region — this puts an image, not text, on the clipboard). Press ⌃⇧⌘C. Pass condition: error beep (not Pop); popover status shows "Clipboard has no plain text."
8. Quit the app via its Quit button.

## Edge cases a weaker model would miss

- **Do NOT create a new `HotKeyCenter.swift` file.** The Xcode target compiles only the files listed inside `project.pbxproj`; a new file on disk is invisible to `xcodebuild` until the pbxproj is edited, so the build would fail with "cannot find 'HotKeyCenter' in scope". Hand-editing pbxproj is the riskiest operation in this repo — that's why the class goes into `TextCleanerApp.swift`, which is already in the target.
- **`HotKeyCenter` must stay non-`@MainActor`, and the `InstallEventHandler` closure must stay capture-free.** The closure is converted to a C function pointer (`EventHandlerUPP`); if it captures anything (including an implicit `self`), Swift refuses the conversion with a confusing error. That is exactly why `self` travels through the `userData` pointer via `Unmanaged`. Similarly, isolating the class to the main actor would make `center.handler?()` illegal inside the C callback.
- **The `Task { @MainActor in ... }` hop is required, not optional.** `cleanClipboardFromHotKey()` is `@MainActor` (the whole model is); the registered handler closure is nonisolated synchronous code, and calling a main-actor method from there directly is a compile error. The Carbon callback already arrives on the main thread, so the hop is imperceptible.
- **`@StateObject private var model = TextCleanerModel.shared` (step 2b) is load-bearing.** If the popover keeps constructing its own `TextCleanerModel()`, the hotkey cleans a *second, invisible* model: the clipboard still changes, but the popover's output/status/Recent never show hotkey activity. Everything would look "almost working" — this is the subtlest failure mode in the plan.
- **`@discardableResult` on `cleanClipboard()` keeps existing call sites warning-free** — the UI button (`TextCleanerApp.swift`) and the unit tests call it without using the result. Removing the attribute floods the build with warnings; changing the tests instead would be gate-weakening.
- **The tests never instantiate `TextCleanerModel.shared`** (it's a lazy static, and the tests build their own instances with an injected pasteboard), so `make verify` needs no changes for this plan. If you find yourself editing `Tests/TextCleanerTests.swift`, you've gone off-plan.
- **If a previous TextCleaner instance is still running during the manual check, it owns the hotkey** (a second `RegisterEventHotKey` for the same combo fails silently in this code) and the new build will appear broken. Quit all instances first — this is step 4.1 for a reason.
- **`NSSound(named: "Pop")` may return nil** on exotic systems (the file lives at `/System/Library/Sounds/Pop.aiff`, verified present here). The optional chaining `?.play()` makes that a silent no-op — never force-unwrap it.
- ⌃⇧⌘C was chosen to dodge ⌥⌘C (Finder's "Copy as Pathname") and ⇧⌘C (browser DevTools element picker). Do not substitute a different combination.
- An empty-string clipboard (as opposed to no text at all) still counts as text: cleaning it "succeeds" vacuously and plays Pop. That matches the existing `cleanClipboard` guard (`guard let text` — an empty string is not nil) and is accepted behavior; don't add special-casing.

## Acceptance criteria

1. Step 0 probe printed `HOTKEY PROBE OK` (or the plan was stopped and logged — see Step 0).
2. `swiftc -typecheck -parse-as-library TextCleaner/TextCleanerApp.swift TextCleaner/TextCleaner.swift TextCleaner/TextCleanerModel.swift` exits 0.
3. `make verify` exits 0 and prints `ALL TESTS PASSED`.
4. All 8 manual steps in Step 4 pass with their stated observable conditions.
5. `git diff --stat` shows exactly two files changed: `TextCleaner/TextCleanerApp.swift`, `TextCleaner/TextCleanerModel.swift`.

**Suggested commit message:** `feat: add Control-Shift-Command-C global hotkey to smart-clean the clipboard`
