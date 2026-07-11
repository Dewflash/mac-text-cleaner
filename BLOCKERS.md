# Blockers

## PLAN-fix-transform-bugs — 2026-07-11

The plan is blocked at acceptance criterion 3, the required observable app spot check. The implementation was reverted to commit `d24926f` per the failure protocol.

### Failing command

```console
$ osascript -e 'tell application "System Events" to tell process "TextCleaner" to get {name, role, description} of every UI element'
70:95: execution error: System Events got an error: osascript is not allowed assistive access. (-1728)
```

Exit status: 1.

### What I tried

- Applied the plan's exact source and test edits. `make verify` exited 0 and printed `ALL TESTS PASSED (50 checks)`.
- Ran `make build` successfully and launched `.build/DerivedData/Build/Products/Release/TextCleaner.app` successfully.
- Confirmed the TextCleaner process and its menu-bar status-item window were present through Core Graphics window metadata.
- Tried screen capture for direct visual inspection. `screencapture -x /private/tmp/textcleaner-screen.png` exited 1 with the full output `could not create image from display`.
- Identified the TextCleaner status item's exact menu-bar bounds by comparing Core Graphics window metadata before and after quitting the app, then tried HID, session-level, Control Centre-targeted, and TextCleaner-targeted mouse events. `AXIsProcessTrusted()` returned `false`, the events did not open the popover, and no TextCleaner window appeared.
- Tried attaching LLDB to the locally built TextCleaner process to open and inspect its AppKit popover from inside the process. The command produced only `(lldb) process attach --pid 11129`, did not complete, and was interrupted.

Because the input box, PDF Lines click, and resulting output panel could not be observed, the manual check was not marked PASS and the plan was not landed.

## PLAN-clipboard-hotkey — 2026-07-11

The plan is blocked at acceptance criterion 4, the required eight-step live hotkey verification. The implementation was reverted to commit `184806a` per the failure protocol.

### Failing command

```console
$ osascript -e 'tell application "TextEdit" to activate' -e 'tell application "TextEdit" to make new document' -e 'tell application "System Events"' -e 'keystroke "THIS IS SHOUTED TEXT. IT NEEDS CLEANING."' -e 'keystroke "a" using command down' -e 'keystroke "c" using command down' -e 'keystroke "c" using {control down, shift down, command down}' -e 'end tell'
```

Full verbatim output: no output. The command remained running as PID 77934 until terminated, so it produced no exit status.

### What I tried

- Ran the exact feasibility probe. It exited 0 and printed `HOTKEY PROBE OK: RegisterEventHotKey returned noErr`.
- Applied all six exact replacements in the two authorized app files.
- The exact standalone `swiftc -typecheck` command exited 0, and `make verify` exited 0 with `ALL TESTS PASSED (45 checks)`.
- Confirmed no TextCleaner instance was running, then successfully ran `make build && open .build/DerivedData/Build/Products/Release/TextCleaner.app` and opened TextEdit.
- Ran the exact TextEdit type, copy, and Control-Shift-Command-C sequence shown above. It hung without producing text on the clipboard; `pbpaste` exited 1 with no output.
- Ran `swift -e 'import ApplicationServices; print(AXIsProcessTrusted())'`. It exited 0 and printed `false`, confirming this session cannot deliver the required cross-app key events or inspect the popover.
- Terminated only the hung automation, TextCleaner test instance, and temporary unsaved TextEdit document.

Because the Pop/error sounds, cleaned paste, popover output/status/Recent state, and image-clipboard failure path could not be observed, none of the eight manual steps was marked PASS and the plan was not landed.
