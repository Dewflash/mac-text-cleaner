# TextCleaner 1.1.0 — Release QA

Run against /Applications/TextCleaner.app installed from release/TextCleaner-1.1.0.dmg.
Rule: PASS only from actually performing the check — an honest FAIL committed is worth more than a green lie.

| # | Area | Steps | Expected | Result |
|---|------|-------|----------|--------|
| 1 | Install | Mount the dmg, drag the app to /Applications | Copies without error; INSTALL.txt visible in dmg | PASS — dmg mounted read-only, INSTALL.txt and TextCleaner.app were visible at its root, and the packaged app copied to /Applications without error. |
| 2 | Launch | Open /Applications/TextCleaner.app | Menu bar icon (text + checkmark) appears | PASS — the installed process launched and the on-screen Control Centre status-item count increased from 14 to 15. |
| 3 | Accessory app | While running, check the Dock | No Dock icon, no app switcher entry | PASS — the running installed process reported accessory activation policy (raw value 1), and its installed Info.plist has LSUIElement enabled. |
| 4 | Version | Finder → Get Info on the installed app | Version shows 1.1.0 | PASS — the installed app's Info.plist reports CFBundleShortVersionString 1.1.0 and CFBundleVersion 2. |
| 5 | Popover | Click the menu bar icon | Popover opens: input box, buttons, Output, Recent | FAIL — macOS denied assistive access to the installed TextCleaner UI, so the menu-bar item could not be clicked or the popover observed. |
| 6 | Auto-load | Copy any text, then open the popover fresh | Input box pre-fills with the copied text | FAIL — `QA auto-load text` was placed on the real clipboard, but the inaccessible popover prevented observing the input box. |
| 7 | Clean Clipboard | Copy `THIS  IS   MESSY. SECOND SENTENCE.` then click Clean Clipboard, paste in TextEdit | Pasted text: `This is messy. Second sentence.`; status says cleaned and copied | FAIL — the installed popover controls and status could not be exercised because macOS denied assistive access. |
| 8 | Plain Text | Type `a   b\tc` in input, click Plain Text, paste | `a b c` on the clipboard | FAIL — the installed popover input and Plain Text button could not be exercised because macOS denied assistive access. |
| 9 | PDF Lines | Paste a hard-wrapped paragraph, click PDF Lines | Lines joined into one paragraph; a wrapped bullet (`• one⏎two`) joins into one bullet | FAIL — the installed PDF Lines UI could not be exercised because macOS denied assistive access; wrapped-bullet condition: N/A (not shipped). |
| 10 | Smart Clean | Input `ALL CAPS TEXT HERE. MORE OF IT.` → Smart Clean | Sentence-cased output | FAIL — the installed popover input and Smart Clean button could not be exercised because macOS denied assistive access. |
| 11 | Sentence | Input `hello. how are you?` → Sentence | `Hello. How are you?` | FAIL — the installed popover input and Sentence button could not be exercised because macOS denied assistive access. |
| 12 | Case menu | Input `the quick brown fox` → Title Case / lowercase / UPPERCASE | `The Quick Brown Fox` / `the quick brown fox` / `THE QUICK BROWN FOX` | FAIL — the installed popover input and Case menu could not be exercised because macOS denied assistive access. |
| 13 | Markdown menu | Input two lines → Quote, then Bullet List, then Code | `> ` prefixes; `- ` bullets; backtick-wrapped lines | FAIL — the installed popover input and Markdown menu could not be exercised because macOS denied assistive access. |
| 14 | Chat menu | Input `hi` → Bold / Italic / Monospace / Strikethrough | `*hi*` / `_hi_` / `` `hi` `` / `~hi~` | FAIL — the installed popover input and Chat menu could not be exercised because macOS denied assistive access. |
| 15 | Output copy | Click Copy above the output panel, paste | Pasted text equals the output panel | FAIL — the installed output panel and Copy button could not be exercised because macOS denied assistive access. |
| 16 | Hotkey | Focus Notes, copy `SHOUTY TEXT. SECOND BIT.`, press Ctrl+Shift+Cmd+C, paste | Pop sound; pasted text is sentence-cased | N/A (not shipped) |
| 17 | Hotkey error | Screenshot to clipboard (Ctrl+Shift+Cmd+4), press the hotkey | Error beep; popover status: "Clipboard has no plain text." | N/A (not shipped) |
| 18 | Recents | After rows 7–16, open popover; click a recent entry; quit and relaunch | Recents list newest-first; clicking copies it; list survives relaunch | FAIL — the installed popover and preceding cleanup actions could not be exercised because macOS denied assistive access. |
| 19 | Clear | Click Clear with text present | Input and output empty; status "Cleared." | FAIL — the installed popover and Clear button could not be exercised because macOS denied assistive access. |
| 20 | Quit | Click Quit in the popover | App exits; menu bar icon disappears; hotkey no longer responds | FAIL — macOS denied the Quit-button interaction; the QA process was terminated from the shell, after which the status-item count returned from 15 to 14. |

## Verdict

SHIP / DO-NOT-SHIP: DO-NOT-SHIP

Notes: Packaging, installation, signature, version, launch, menu-bar presence, and accessory activation were directly verified. Installed-app UI QA could not be completed because this session lacks macOS Accessibility permission. The wrapped-bullet fix and global hotkey are not present in this binary, as recorded in BLOCKERS.md.
