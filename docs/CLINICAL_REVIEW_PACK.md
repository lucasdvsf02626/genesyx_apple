# Clinical review pack — 17 August 2026

**For:** the qualified clinician reviewing Genesyx content before the 1.2.0 App Store submission.
**From:** Lucas Valença, Genesyx.
**What is being asked:** a read and a sign-off on four items. Three are drafted and waiting; one
cannot be written until you rule on it.

Nothing in this pack ships until you have signed it off. Items 2 and 3 are hard-blocked: the app
contains links that will 404 in front of an App Store reviewer if the pages are not live, so the
links are currently withheld from the build.

---

## Why you are being asked

Genesyx is a **wellness app, not a medical device**, and the whole content set is written to stay
on the wellness side of that line: it names no condition, diagnoses nothing, and prescribes no
treatment. That framing is enforced in code — an automated guard fails the build if banned clinical
vocabulary appears in the pH copy.

That guard protects us from saying too much. It cannot tell us whether what we *do* say is
**correct, proportionate, and safe**. That is what we need you for.

---

## Item 1 — New in-app copy: supporting vaginal health

**Status:** written, in the build, awaiting your read.
**Where she sees it:** the pH tab, at the bottom of the tracker card, **before she has logged
anything**. Shown unconditionally.
**Source file:** `Sources/GenesyxCore/Ph/PhCopy.swift`

### Why it was added

Before this, the pH tab could tell a woman **when to worry** in five separate places and could not
tell her **one thing she might do herself**. The only "support" on the tab was a link to our own
supplements. That is a poor answer to "what do I do with this?", and it made the tab read as a
sequence of warnings with a product attached.

### The copy, verbatim

> **Supporting your vaginal health**
>
> Your body keeps its own balance, and it usually does that best when left alone. Warm water is
> enough for washing — the outside only, as the inside looks after itself. Unscented products,
> breathable cotton underwear, and changing out of damp swimwear or gym kit all help. Douching and
> scented washes work against that balance rather than for it.
>
> If you notice a change in discharge, smell, or comfort that is new for you, a pharmacist can help
> — no appointment needed, and it's a very ordinary thing to ask about.

It carries the same NHS citation as the "Why pH matters" section above it.

### What we would like you to check

1. **Is the guidance itself right?** It is intended to be ordinary NHS public-health advice, and it
   is deliberately mostly about leaving well alone.
2. **Is the pharmacist signpost set at the right threshold?** It triggers on *"a change… that is
   new for you"* — no reading value, no duration. We set it low on purpose, to lower the bar for
   asking. Tell us if that is too low and will send well women to a pharmacy counter unnecessarily,
   or too high.
3. **Is anything missing that you would expect to see** in a section with this title?

### A related gap you should know about

Our Learn content signposts help only when readings stay high **and** she notices symptoms. A woman
with symptoms but perfectly normal readings was previously told nothing. The pharmacist line above
is the first place in the app that triggers on symptoms alone. If you think that combination is
still wrong, say so — the Learn wording is ours to change.

---

## Item 2 — Website page: vaginal pH and fertility

**Status:** drafted, **not published**, not linked from the app.
**File:** `docs/website/vaginal-ph-fertility-science.md`
**Target URL:** `https://genesyx.co.uk/pages/vaginal-ph-fertility-science`

The page carries two required disclaimer blocks which must not be removed, shortened, or moved
below the fold. The draft states plainly that a home pH reading **cannot diagnose** an infection or
any other condition.

**Please review the whole page**, but in particular that the claims about what pH *can* suggest are
not stronger than the evidence supports.

---

## Item 3 — Website page: the Shettles method

**Status:** drafted, **not published**, not linked from the app.
**File:** `docs/website/shettles-method-evidence-limitations.md`
**Target URL:** `https://genesyx.co.uk/pages/shettles-method-evidence-limitations`

We cover Shettles because customers ask about it and because much of what is online overstates it.
The draft's position is that it is **a 1960s hypothesis, not shown to work, and not to be relied
on**. Genesyx does not offer sex selection and the app makes no claim to influence a baby's sex —
this is enforced by an automated content guard.

**Please confirm the debunking is accurate and sufficiently firm**, and that covering the topic at
all is the right call rather than a risk.

---

## Item 4 — The bundled PDF guide

**Status:** usable internally; **not App Store-ready**.

Two of the four corrections are already closed. Two remain with the designer (artwork, not
content): title metadata and accessibility tagging. Separately, the page-20 typo and the QR code
are being removed — see `docs/FREE_GUIDE_DESIGNER_BRIEF.md`.

**What we need from you is the medical sign-off on the guide's content**, which has never been
formally given. The corrections above are cosmetic and do not depend on your review; the sign-off
does, and the guide ships inside the app.

---

## Item 5 — A decision only you can unblock

There is one piece of copy we have **deliberately not written** pending your ruling.

The pH section currently describes vaginal pH as *"a simple, everyday signal of intimate
wellbeing"* and stops there. It never connects pH **to fertility** — which is the section's entire
purpose within a fertility app.

We did not write that connection ourselves, because it is precisely the sentence most likely to
overstate the evidence. **If you are willing to tell us what can be said accurately, we will write
to that and no further.** If your answer is that nothing can responsibly be claimed, that is an
acceptable answer and the section stays as it is.

---

## What "sign-off" means here

For each item, we need one of:

- **Approved as written**, or
- **Approved with these changes** (specific wording), or
- **Not approved** — with the reason, so we remove or rewrite rather than guess.

A reply naming each item and one of those three outcomes is sufficient. We do not need a formal
report.

**Please do not approve by silence.** Items 2 and 3 stay unpublished and unlinked until you have
said yes explicitly.
