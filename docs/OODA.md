# OODA — How We Build genesyx With Claude

> **OODA** = Observe → Orient → Decide → Act.
> A military decision loop, repurposed as the working rhythm for building and
> shipping a native SwiftUI app to the Apple App Store with Claude.
>
> The goal: never write code blindly, never waste tokens, never lose a working
> version, and always know the *next single action*.

---

## Why a loop (not a checklist)

Building an app is not linear. You build a screen, test it, find a bug, fix it,
realize the design is off, adjust, ship a slice, get feedback, iterate. A
checklist assumes you know everything up front. The OODA loop assumes you don't —
it forces a tight cycle of *look → understand → choose → do* on every unit of work
(one screen, one feature, one bug).

One loop = one small, shippable, reversible unit of work.

---

## The Loop

### 1. OBSERVE — *What is true right now?*
Gather raw state before doing anything.

- What does the app currently do? (Run it in the Simulator.)
- What's the exact error / what's missing / what feels wrong?
- What did the last working version look like? (See "Save Every Working Version".)
- Paste **only** the relevant file(s) or error — never the whole project.

> ❌ "It's broken, fix it."
> ✅ "`HomeView.swift` crashes on launch. Here is the file and the Xcode console
> output. Nothing else changed since the last working build."

### 2. ORIENT — *What does this mean, and what are my options?*
Turn raw state into understanding.

- Is this a **design** problem, a **logic** problem, or a **build/signing** problem?
  (They have totally different fixes.)
- Which layer does it touch — View, ViewModel, Model, or Xcode config?
- Does this need deep reasoning (architecture, a stubborn bug) or is it
  mechanical (write a known view)? → picks the model (see table below).

### 3. DECIDE — *What is the single next action?*
Commit to ONE move.

- One file. One feature. One fix. One message to Claude.
- Write the action as a sentence: *"Add a filled-heart state to the Save button
  in `TipCardView.swift` when the tip is already a favorite."*
- If you can't say it in one sentence, you haven't oriented enough — go back.

### 4. ACT — *Do it, then verify.*
- Ask Claude for the one thing (using the prompt patterns in `PLAYBOOK.md`).
- Build & run on Simulator / device.
- **If it works:** mark it (`// WORKING v1 — <date>`), commit to git, loop again.
- **If it doesn't:** the failure is your new OBSERVE input. Loop again.

---

## Model Selection (the Swift equivalent of the Kotlin guide)

| Task | Model | Why |
|---|---|---|
| Plan app architecture / data flow | **Opus** | Deep reasoning about structure |
| Generate a SwiftUI `View` | **Sonnet** | Fast, accurate for known UI code |
| Generate a `ViewModel` / model struct | **Sonnet** | Mechanical, well-specified |
| Fix a crash or compile error | **Sonnet** | Efficient on isolated problems |
| A bug Sonnet can't crack in ~3 tries | **Opus** | Deeper analysis needed |
| Pre-submission review (App Store rules, privacy) | **Opus** | Catches subtle rejection risks |
| Add a major new feature | **Opus** (plan) → **Sonnet** (build) | Plan first, then execute |

---

## Token Discipline (carried over from your Kotlin workflow)

These rules cut token use sharply *and* produce better code:

1. **Start every session with a Context Block** (see template below). Claude has
   no memory between chats — this is its persistent memory.
2. **One file per message.** Never "build the whole app" in one prompt.
3. **Paste only what's needed.** The failing function, not the 500-line file.
4. **Save every working version.** Comment `// WORKING v1 — <date>` and commit.
5. **Use "Continue from where you stopped"** if Claude is cut off — never restart
   the file from the top.
6. **Use specific names.** "Fix the crash in `HomeView.swift` line 47," not
   "fix the crash."

### Context Block — paste at the start of every session

```
PROJECT: genesyx
LANGUAGE: Swift, SwiftUI (native iOS)
DEPLOYMENT TARGET: iOS 16+   (confirm)
BUNDLE ID: com.<yourorg>.genesyx
ARCHITECTURE: MVVM, single-app SwiftUI App lifecycle
MONETIZATION: None — free app, NO ads, NO AdMob, NO tracking
STATUS: [Building first version / Fixing a bug / Adding a feature]
CURRENT FILE: [e.g. HomeView.swift]
TASK: [one sentence]

Output rules:
- Swift / SwiftUI only
- Complete files only — no "..." or partial snippets
- Do NOT add features I did not ask for
- Include all imports at the top of every file
```

---

## One full loop, worked example

1. **Observe:** Favorites list shows duplicates after re-saving a tip.
2. **Orient:** Logic problem, in the ViewModel layer (not the View). Sonnet-sized.
3. **Decide:** "Make `FavoritesViewModel.add(_:)` ignore a tip whose id is already
   saved."
4. **Act:** Ask Sonnet for the updated function only → build → confirm no dupes →
   `// WORKING — <date>` → `git commit` → next loop.

---

See **`PLAYBOOK.md`** for the full zero-to-App-Store path that this loop runs inside.
