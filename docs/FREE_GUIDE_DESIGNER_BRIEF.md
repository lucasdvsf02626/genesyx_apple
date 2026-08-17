# Correction brief — *7-Day Fertility Nutrition Starter Guide* (PDF)

**For:** the designer holding the Affinity source
**Raised:** 17 August 2026
**Why it matters:** this PDF ships *inside* the Genesyx iOS app. It is the first thing a woman
opens, often before she has even created an account. Two of the four corrections below are visible
to every reader on the final page.

---

## Source file

| | |
|---|---|
| Producing application | **Affinity 3.1.0** (per the PDF's `/Creator`) |
| Author | Dieter Morton |
| Original creation | 15 April 2026 |
| Pages | 20, A4 portrait (595 × 842 pt) |
| Shipped as | `App/Genesyx/Resources/Genesyx_7_Day_Fertility_Nutrition_Starter_Guide.pdf` |

**Please correct the Affinity document and re-export.** Do not patch the PDF — a visual patch
leaves the old wording in the text layer, so a screen reader still announces the mistake, and the
file's own search still finds it.

---

## What has already been fixed, and must survive your re-export

### ✅ Document title (was blocker 1 — now closed)

The file was supplied with its internal title set to **"Genesyx - Recipe Book"**. A woman who saved
or shared the guide got a document titled something other than what the app had just shown her.

It now reads **`7-Day Fertility Nutrition Starter Guide`**, corrected in both the Info dictionary
and the XMP metadata without re-encoding a single page.

> **Action for you:** before exporting, set **File → Document Setup → Metadata → Title** to
> exactly:
>
> ```
> 7-Day Fertility Nutrition Starter Guide
> ```
>
> Affinity writes that field into the exported PDF. If it is left blank or left as "Genesyx -
> Recipe Book", the regression will ship again.
>
> An automated test now fails the build if it does:
> `App/GenesyxTests/FreeGuideBundleTests.swift` →
> `testTheBundledPdfCarriesTheTitleTheAppShows`.

Please also leave **Author** as *Dieter Morton* and **Creation date** as *15 April 2026* if Affinity
lets you; they are correct and worth keeping.

---

## Correction 1 — page 20 typo

**Blocker 2.** Page 20, the closing page, the bold line beneath the GENESYX wordmark.

**Currently reads:**

> Download **out** free app now for ongoing personalised fertility support.

`out` should be `our`. This is in the exported text layer as well as the artwork, which is why it
must be fixed at source.

---

## Correction 2 — page 20 QR code and app-download call to action

**Blocker 3.** Same page. Please **remove both** the QR code and the download line.

**Why.** Everyone reading this PDF is already inside the Genesyx app — it is bundled with the app
and opened from within it. So:

- The line asks a reader who is already using the app to go and download the app.
- The QR code encodes `https://genesyx.co.uk/`. Even if a reader could scan a screen she is
  holding, the in-app reader deliberately **blocks** taps on embedded links, because the guide is
  designed to open before registration and with no internet connection. Sending her out to Safari
  would break both of those promises.

### What to put there instead

Keep the page's shape — the wordmark and the calm closing tone are right. Replace the download line
and the QR block with a single line of the same weight:

> Everything here carries on inside Genesyx. Track how you feel, log what you eat and drink, and
> read a little more each week.

That is the wording the app's own accessible text version already uses, so the two will match.

If the layout looks empty without the QR block, prefer whitespace or the existing bubble motif over
adding new content — the last page is meant to feel like a soft landing, not a sales page.

---

## Correction 3 — accessibility tagging (optional, but valuable)

**Blocker 4 is already closed in the app**, so this is no longer release-blocking. The app now
carries a full text equivalent of all 20 pages, rendered as native, navigable, resizable text
(`Sources/GenesyxCore/Content/FreeGuideContent.swift`), and VoiceOver users are shown it by
default with a **Text / Pages** toggle in the reader.

But the text equivalent only helps *inside the app*. Anyone who saves the PDF and opens it in Files,
Books or on a desktop still gets an untagged document. If Affinity's export offers **PDF/UA** or
"tagged PDF" / "include structure", please enable it. Two specific things to check if you do:

1. **Headings should be real headings.** Every page's title ("Day 3: Add more colour", "A simple
   starter shopping list") should be tagged as a heading so a screen reader can jump between pages.
2. **The running footer should be artifacted.** The letter-spaced `FOODS FOR FERTILITY` device at
   the bottom of every page currently exports into the text layer as
   `FO O D S FO R F E RT I L I TY`, which a screen reader reads out letter by letter, twenty times.
   Marking it as a background artifact (decoration) stops that.

---

## One layout note, not a blocker

On **page 18** ("A simple starter shopping list"), *Sweet Potatoes* and *Avocados* sit in a fourth
column of the **Fruit & vegetables** group. Visually this is clear. In the exported text layer they
come out detached from that group, after the page footer, which is how a screen reader and any
copy-paste would receive them.

If it is easy, reflowing them into the same column flow as the other Fruit & vegetables items would
make the exported text match what the page shows. If it is fiddly, leave it — the app's text
version already places them correctly.

---

## When you send the corrected file back

Please return the exported PDF (not the Affinity source) and we will:

1. Confirm it is still 20 pages and opens in PDFKit.
2. Confirm the internal title is `7-Day Fertility Nutrition Starter Guide`.
3. Confirm the strings `Download out`, `Download our` and the QR code are all gone.
4. Re-record its size and hash in `docs/HANDOFF.md`.
5. Update `FreeGuideContent.swift` to note that the text version and the PDF no longer differ on
   page 20.

---

## Still outstanding, and not a design task

**The guide has not had medical or content review.** Every other piece of content in the app carries
a citation, a disclaimer and a sign-off; this PDF came in through a different route. Page 3 does
carry a good general disclaimer, and nothing in the guide makes a clinical claim — but it needs a
suitably qualified reviewer to say so in writing before the app goes to the App Store. That is
tracked separately in `docs/HANDOFF.md` §0h and is a client action, not a designer one.
