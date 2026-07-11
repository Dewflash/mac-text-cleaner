# AGENTS.md — execution roadmap for TextCleaner

You are executing a pre-planned handover roadmap. Every decision has already been made and verified; your job is faithful execution, not improvisation. The plans were validated by running their code on this machine on 2026-07-11 — when a plan and your instinct disagree, the plan wins.

**Product promise (judge every ambiguity against this):** copy messy text, invoke TextCleaner once — a click or ⌃⇧⌘C — and paste clean text; the clipboard always holds exactly what the app shows.

## Step 0 — first session only

Before anything else, commit the roadmap documents themselves:

```bash
git add AGENTS.md PLAN-verify-harness.md PLAN-fix-transform-bugs.md PLAN-clipboard-hotkey.md PLAN-final-polish.md
git commit -m "docs: add execution roadmap"
```

This protects the plans from being lost to a stray checkout. Do this even if you only have time for Step 0.

## Execution order

One plan per session. Finish-and-commit before starting the next. Never interleave two plans in one commit.

```
PLAN-verify-harness            (1st — creates the make verify gate)
   ├── PLAN-fix-transform-bugs (2nd)
   ├── PLAN-clipboard-hotkey   (3rd — independent of 2nd; order between them is free)
   └────────► PLAN-final-polish (4th — ALWAYS last, runs even if 2nd/3rd were blocked)
```

- `PLAN-verify-harness` blocks everything: no other plan may start until `make verify` exists and is green.
- `PLAN-final-polish` adapts to reality: it reads `BLOCKERS.md` and documents/QAs only what actually shipped.

## The hard gate (after every plan, before its commit)

1. `make verify` exits 0 and prints `ALL TESTS PASSED`. (Needs a logged-in macOS session; opens no windows. Exception: the gate for `PLAN-verify-harness` itself is that plan's acceptance criteria, since it creates `make verify`.)
2. Every acceptance criterion in that plan's file passes, including the manual checks with their stated observable conditions.
3. `git status` shows only the files that plan's header lists as touched.
4. Commit with the plan's suggested commit message.

**Never weaken a gate on your own.** Weakening includes: editing an expected string to make a test pass, deleting or skipping a test, marking a manual QA row PASS without performing it, loosening an acceptance criterion, or committing with `make verify` red. If a gate seems wrong, that is a blocker — log it and stop the plan; do not negotiate with the gate.

## Failure protocol

When a step fails and the plan doesn't already prescribe the response:

1. Revert to the last green commit: `git reset --hard` (uncommitted work) — never half-land a plan. A plan is either fully landed and green, or not landed at all.
2. Append to `BLOCKERS.md` (create it if missing): the plan name, the exact failing command, the full verbatim output, and what you tried.
3. Move on only to plans that do not depend on the blocked one (see the graph). If `PLAN-verify-harness` is blocked, everything is blocked — stop entirely.
4. Feasibility probes marked "STOP and report" mean exactly that: log and stop that plan. Do not substitute your own alternative approach — choosing a different hotkey, test framework, or packaging layout is a product decision that was already made.

## House rules

- **No new dependencies of any kind** — no Swift packages, no Homebrew tools, no frameworks beyond what the code already imports (`AppKit`, `SwiftUI`, `Foundation`, `Carbon`). Everything ships with stock macOS + Xcode.
- **Never edit `TextCleaner.xcodeproj/project.pbxproj`** except the four version lines in `PLAN-final-polish` Step 1. No new files may be added to the Xcode target — plans place new code only in files the target already compiles, or outside the target (Tests/, Scripts/).
- **Match the existing style:** 4-space indent, no trailing whitespace, `guard` for early exits, no comments except where the plans include them, no force-unwraps.
- **Never commit:** anything under `build/` or `.build/`, screenshots or recordings, `.DS_Store`, secrets/tokens. The single sanctioned binary exception: `release/TextCleaner-<version>.dmg` and `.zip` produced by `Scripts/package.sh` in `PLAN-final-polish`.
- **Never `git push`, never create branches, never touch git history.** Local commits (and the `v1.1.0` tag on SHIP) only.
- **Architecture invariants:** the app is a menu-bar-only accessory (`LSUIElement`, no Dock icon); `TextCleaner` (the enum) stays pure Foundation with no AppKit imports; `TextCleanerModel` keeps its injectable `init(pasteboard:defaults:)` — that seam is what makes the tests possible; every cleaning action must end with the result on the clipboard (that's the product promise).
- Timestamps in these documents are absolute (2026-07-11 = the handover date).

## Definition of done for the whole engagement

1. All four plans are either landed (committed, gate green) or honestly blocked in `BLOCKERS.md` — no plan half-landed.
2. `make verify` is green at final HEAD.
3. `README.md` documents exactly the shipped behavior — nothing more, nothing less.
4. `RELEASE-QA.md` is committed with every row performed and an explicit SHIP / DO-NOT-SHIP verdict. Remember: **PASS only from actually performing the check — an honest FAIL committed is worth more than a green lie.**
5. Tag `v1.1.0` exists if and only if the verdict is SHIP.
6. `git status` is clean.

An engagement that ends with a committed DO-NOT-SHIP and a clear blocker log is a *successful* engagement. An engagement that ends with a green-looking repo that lies is a failed one.
