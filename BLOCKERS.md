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
