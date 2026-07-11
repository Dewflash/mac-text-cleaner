# PLAN-final-polish — self-verified 1.1.0 release

- **Rank:** 4 of 4 — **always the last plan executed**, regardless of which earlier plans landed.
- **Dependencies:** run AFTER `PLAN-verify-harness` (hard requirement) and after `PLAN-fix-transform-bugs` and `PLAN-clipboard-hotkey` have either landed or been logged to `BLOCKERS.md`. This plan adapts to what actually shipped — read `BLOCKERS.md` first.
- **Effort:** ~2 hours, most of it the manual QA run
- **Files touched:** `TextCleaner.xcodeproj/project.pbxproj` (4 version lines only), `Scripts/package.sh` (new), `README.md` (rewrite), `.gitignore` (append one line), `RELEASE-QA.md` (new), `release/TextCleaner-1.1.0.dmg` (new), `release/TextCleaner-1.1.0.zip` (new); **deletes** the tracked `build/` directory and everything currently under `release/`. **Nothing else.**

## Goal

Ship a release that a stranger could install and trust, with the QA evidence committed next to it. Today the repo's release story is broken in verifiable ways: the committed artifacts are named `TextCleaner-1.0` but the app inside reports version **0.1.0** (`MARKETING_VERSION = 0.1.0` in `project.pbxproj`); there is no packaging script, so the artifacts cannot be reproduced; and a stale `build/` directory with an old binary is tracked in git. This plan bumps the version to **1.1.0**, makes packaging one command, rebuilds the artifacts from source, QAs the *packaged* app row by row, and records an honest verdict.

Facts verified on this machine on 2026-07-11: automatic signing with no team produces an **ad-hoc** signed app (same as the currently shipped one — do not add signing steps); the existing dmg's volume root contains `TextCleaner.app` + `INSTALL.txt` directly; the existing zip wraps a `TextCleaner-<version>/` folder. The script below reproduces both layouts.

## Steps

### 0. Read `BLOCKERS.md`

If it doesn't exist, all plans landed — proceed with the full README and all QA rows. If `PLAN-clipboard-hotkey` is logged as blocked, **omit the "Hotkey" README section and mark QA rows 16–17 as `N/A (not shipped)`**. If `PLAN-fix-transform-bugs` is blocked, mark QA row 9's second pass-condition as `N/A`. Never document unshipped behavior — the README describes what the binary does, not what the plans hoped.

### 1. Bump the version in `TextCleaner.xcodeproj/project.pbxproj`

The file contains exactly two occurrences of each line below (Debug and Release configurations). Change **all four lines** and nothing else in this file:

- `MARKETING_VERSION = 0.1.0;` → `MARKETING_VERSION = 1.1.0;` (2 occurrences)
- `CURRENT_PROJECT_VERSION = 1;` → `CURRENT_PROJECT_VERSION = 2;` (2 occurrences)

Why 1.1.0: "1.0" is what the previously distributed artifacts were named, and the hotkey is a new feature on top of it. Verify with:

```bash
grep -c 'MARKETING_VERSION = 1.1.0;' TextCleaner.xcodeproj/project.pbxproj   # must print 2
grep -c 'CURRENT_PROJECT_VERSION = 2;' TextCleaner.xcodeproj/project.pbxproj # must print 2
```

### 2. Remove stale tracked artifacts

```bash
git rm -r build release
echo 'build/' >> .gitignore
```

`build/` is transient xcodebuild output that was committed by accident (it contains a 0.1.0 binary). Everything under `release/` is stale (wrong embedded version) and is regenerated in Step 4. The old artifacts remain recoverable in git history — do not try to purge history.

### 3. Create `Scripts/package.sh`

Create the `Scripts/` directory, write exactly this to `Scripts/package.sh`, then `chmod +x Scripts/package.sh`:

```bash
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' TextCleaner.xcodeproj/project.pbxproj | head -1)
if [ -z "$VERSION" ]; then
    echo "Could not read MARKETING_VERSION from project.pbxproj" >&2
    exit 1
fi

xcodebuild -scheme TextCleaner -configuration Release -derivedDataPath .build/DerivedData -quiet build

APP=".build/DerivedData/Build/Products/Release/TextCleaner.app"
if [ ! -d "$APP" ]; then
    echo "Missing built app at $APP" >&2
    exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

FOLDER="$STAGE/TextCleaner-$VERSION"
mkdir -p "$FOLDER"
ditto "$APP" "$FOLDER/TextCleaner.app"

cat > "$FOLDER/INSTALL.txt" <<EOF
TextCleaner $VERSION

To install:
1. Open TextCleaner-$VERSION.dmg or unzip TextCleaner-$VERSION.zip.
2. Drag TextCleaner.app to your Applications folder.
3. Launch TextCleaner from Applications.

If macOS warns that the app was downloaded from the internet, open it from Finder with Control-click > Open.
EOF

mkdir -p release
rm -f "release/TextCleaner-$VERSION.dmg" "release/TextCleaner-$VERSION.zip"
hdiutil create -volname "TextCleaner $VERSION" -srcfolder "$FOLDER" -ov -format UDZO "release/TextCleaner-$VERSION.dmg"
ditto -c -k --keepParent "$FOLDER" "release/TextCleaner-$VERSION.zip"

echo "Built release/TextCleaner-$VERSION.dmg and release/TextCleaner-$VERSION.zip"
```

### 4. Gate, then build the artifacts

```bash
make verify
Scripts/package.sh
```

Both must exit 0. Then verify the artifacts mechanically:

```bash
unzip -l release/TextCleaner-1.1.0.zip | grep -q 'TextCleaner-1.1.0/TextCleaner.app/Contents/MacOS/TextCleaner' && echo ZIP-OK
hdiutil attach -nobrowse -readonly release/TextCleaner-1.1.0.dmg
plutil -p "/Volumes/TextCleaner 1.1.0/TextCleaner.app/Contents/Info.plist" | grep CFBundleShortVersionString   # must show 1.1.0
```

Keep the dmg mounted for Step 5.

### 5. Install the packaged app

1. Quit any running TextCleaner instance (menu bar → Quit). If a copy exists in `/Applications`, delete it first.
2. Drag `TextCleaner.app` from the mounted `TextCleaner 1.1.0` volume to `/Applications` (Finder), or: `cp -R "/Volumes/TextCleaner 1.1.0/TextCleaner.app" /Applications/`
3. `hdiutil detach "/Volumes/TextCleaner 1.1.0"`
4. Launch `/Applications/TextCleaner.app`. **Every QA row in Step 7 runs against this installed copy — never against the dev build.** Packaging bugs (missing icon, wrong version, broken resources) are invisible in the dev build; that is the entire point of QA-ing the artifact.

### 6. Rewrite `README.md`

Replace the whole file with the following, adjusted per Step 0 (omit the Hotkey section if it didn't ship):

```markdown
# TextCleaner

TextCleaner is a small macOS menu bar app for cleaning and reformatting copied text before pasting it elsewhere.

It strips rich formatting by reading and writing plain clipboard text, fixes PDF-style broken line breaks (including wrapped bullet lines), normalizes spaces, converts capitalization, creates Markdown snippets, formats chat text, and keeps your five most recent cleaned outputs.

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

### Hotkey

Press `Control+Shift+Command+C` in any app to smart-clean the clipboard in place — no popover needed. A soft "Pop" confirms success; an error beep means the clipboard had no plain text.

## Tools

- Plain text, PDF lines, and Smart Clean
- Sentence button, plus Case menu: title case, lowercase, uppercase
- Markdown menu: quote, bullet list, comma list, bold, italic, code
- Chat menu: bold, italic, monospace, strikethrough
- Recent cleaned outputs: click any recent item to copy it again

## Build from source

    make verify            # release build + unit tests (needs a logged-in macOS session)
    Scripts/package.sh     # rebuild release/TextCleaner-<version>.dmg and .zip
```

### 7. Run the QA checklist and commit it as `RELEASE-QA.md`

Create `RELEASE-QA.md` with the table below and fill the **Result** column by *actually performing each row* against `/Applications/TextCleaner.app`. Record `PASS`, `FAIL (what happened)`, or `N/A (not shipped)`.

> **PASS only from actually performing the check — an honest FAIL committed is worth more than a green lie.**

```markdown
# TextCleaner 1.1.0 — Release QA

Run against /Applications/TextCleaner.app installed from release/TextCleaner-1.1.0.dmg.
Rule: PASS only from actually performing the check — an honest FAIL committed is worth more than a green lie.

| # | Area | Steps | Expected | Result |
|---|------|-------|----------|--------|
| 1 | Install | Mount the dmg, drag the app to /Applications | Copies without error; INSTALL.txt visible in dmg | |
| 2 | Launch | Open /Applications/TextCleaner.app | Menu bar icon (text + checkmark) appears | |
| 3 | Accessory app | While running, check the Dock | No Dock icon, no app switcher entry | |
| 4 | Version | Finder → Get Info on the installed app | Version shows 1.1.0 | |
| 5 | Popover | Click the menu bar icon | Popover opens: input box, buttons, Output, Recent | |
| 6 | Auto-load | Copy any text, then open the popover fresh | Input box pre-fills with the copied text | |
| 7 | Clean Clipboard | Copy `THIS  IS   MESSY. SECOND SENTENCE.` then click Clean Clipboard, paste in TextEdit | Pasted text: `This is messy. Second sentence.`; status says cleaned and copied | |
| 8 | Plain Text | Type `a   b\tc` in input, click Plain Text, paste | `a b c` on the clipboard | |
| 9 | PDF Lines | Paste a hard-wrapped paragraph, click PDF Lines | Lines joined into one paragraph; a wrapped bullet (`• one⏎two`) joins into one bullet | |
| 10 | Smart Clean | Input `ALL CAPS TEXT HERE. MORE OF IT.` → Smart Clean | Sentence-cased output | |
| 11 | Sentence | Input `hello. how are you?` → Sentence | `Hello. How are you?` | |
| 12 | Case menu | Input `the quick brown fox` → Title Case / lowercase / UPPERCASE | `The Quick Brown Fox` / `the quick brown fox` / `THE QUICK BROWN FOX` | |
| 13 | Markdown menu | Input two lines → Quote, then Bullet List, then Code | `> ` prefixes; `- ` bullets; backtick-wrapped lines | |
| 14 | Chat menu | Input `hi` → Bold / Italic / Monospace / Strikethrough | `*hi*` / `_hi_` / `` `hi` `` / `~hi~` | |
| 15 | Output copy | Click Copy above the output panel, paste | Pasted text equals the output panel | |
| 16 | Hotkey | Focus Notes, copy `SHOUTY TEXT. SECOND BIT.`, press Ctrl+Shift+Cmd+C, paste | Pop sound; pasted text is sentence-cased | |
| 17 | Hotkey error | Screenshot to clipboard (Ctrl+Shift+Cmd+4), press the hotkey | Error beep; popover status: "Clipboard has no plain text." | |
| 18 | Recents | After rows 7–16, open popover; click a recent entry; quit and relaunch | Recents list newest-first; clicking copies it; list survives relaunch | |
| 19 | Clear | Click Clear with text present | Input and output empty; status "Cleared." | |
| 20 | Quit | Click Quit in the popover | App exits; menu bar icon disappears; hotkey no longer responds | |

## Verdict

SHIP / DO-NOT-SHIP: <one of the two, based only on the table above>

Notes: <anything a future release should know>
```

### 8. Verdict, commit, tag

- Every row PASS or justified N/A → verdict **SHIP**.
- Any FAIL → verdict **DO-NOT-SHIP**, commit the honest table anyway, and log the failing row to `BLOCKERS.md`. **A committed DO-NOT-SHIP is a successful outcome of this plan** — do not "re-run" rows until they pass without a code change that explains the first failure.

Commit everything from this plan in one commit. Then, **only if the verdict is SHIP**:

```bash
git tag v1.1.0
```

Never `git push` — the repo owner pushes.

## Edge cases a weaker model would miss

- **`project.pbxproj` has TWO copies of every build setting** (Debug + Release blocks). Editing only one ships a Release app with the right version but leaves Xcode's Debug runs mismatched — or vice versa. Both greps in Step 1 must print exactly `2`. Do not let an editor "reformat" any other line of this file; Xcode is intolerant of structural changes.
- **The QA target is the installed `/Applications` copy, not `.build/DerivedData/...`.** The dev build skips the dmg/zip path entirely, so it cannot catch packaging mistakes (missing `Assets.car`, stale Info.plist, wrong folder layout). Rows performed against the dev build are green lies even if every step "passed".
- **Quit all other TextCleaner instances before QA.** Two copies running means two menu bar icons (you'll QA the wrong one) and the hotkey belongs to whichever registered first (row 16 would fail mysteriously).
- **`hdiutil create -srcfolder "$FOLDER"` puts the folder's *contents* at the volume root** — app + INSTALL.txt directly visible, matching the shipped 1.0 dmg. Don't "fix" the script to nest a `TextCleaner-1.1.0` folder inside the volume; the zip (via `ditto --keepParent`) is the one that keeps the wrapper folder, also matching 1.0.
- **No codesign step is missing.** Automatic signing with no team yields an ad-hoc signature, byte-for-byte the same situation as the shipped 1.0 artifacts. Do not add `codesign`/notarization steps; there is no Developer ID certificate on this machine (verified — only Apple Development identities exist, which don't help Gatekeeper on other machines).
- **A locally built dmg carries no quarantine flag**, so Gatekeeper won't exercise the Control-click>Open path during QA on this machine. That's expected — INSTALL.txt still documents it for real downloaders; don't chase it as a FAIL.
- **Step order is load-bearing:** version bump (1) must precede packaging (4), because `package.sh` reads `MARKETING_VERSION` from the pbxproj to name the artifacts. Running the script first produces `TextCleaner-0.1.0.*` artifacts.
- **The `release/*.dmg` and `release/*.zip` files are the one sanctioned binary commit in this repo** (that is the project's distribution channel). Everything else binary — `build/`, `.build/`, screenshots — must never be committed.
- **README describes shipped behavior only.** If the hotkey plan was blocked, delete that section entirely; a README promising a hotkey that isn't there is exactly the kind of lie this engagement exists to prevent.

## Acceptance criteria

1. `make verify` exits 0 at the final tree.
2. `Scripts/package.sh` exits 0 and prints the two artifact paths; `release/TextCleaner-1.1.0.dmg` and `release/TextCleaner-1.1.0.zip` exist.
3. The mounted dmg's app reports `CFBundleShortVersionString => "1.1.0"` (Step 4 plutil check).
4. `git ls-files build` prints nothing (stale build dir untracked); `git ls-files release` lists only the two 1.1.0 artifacts.
5. `RELEASE-QA.md` is committed with every row's Result filled and an explicit `SHIP` or `DO-NOT-SHIP` verdict.
6. Tag `v1.1.0` exists if and only if the verdict is SHIP (`git tag -l v1.1.0`).
7. `README.md` contains no reference to behavior that is absent from the binary (cross-check against BLOCKERS.md).

**Suggested commit message:** `release: v1.1.0 — packaging script, README, QA sign-off`
