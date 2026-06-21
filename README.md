# Genesyx (iOS)

*Fertility Prep, Gently Guided* — a native **SwiftUI** rebuild of the Genesyx fertility-prep &
cycle-tracking app for the Apple App Store. **Free, no ads, no tracking.** A faithful port of the
existing Android (Kotlin/Compose) client.

## Status — local-only v1 is code-complete
All 13 screens, the tested domain logic, on-device persistence, deep links, theming, privacy
manifest, CI, and a flip-on Supabase backend are in place. Remaining to ship: a first Mac build,
brand assets (icon/fonts), and Apple submission. See **`docs/DEPLOYMENT_REPORT.md`**.

## Quick start (Mac)
```bash
swift test                 # domain-layer tests (no Xcode needed)
brew install xcodegen
xcodegen generate          # creates Genesyx.xcodeproj from project.yml
open Genesyx.xcodeproj      # set your signing Team, then ⌘R
```
Full walkthrough: **`docs/MAC_SETUP.md`**.

## Architecture
SwiftUI · MVVM over Clean Architecture · iOS 16+ · online-first ready (Supabase deferred).

```
Sources/GenesyxCore/   Pure, UI-free domain layer (cycle engine, pH, content, models) + tests
App/Genesyx/           SwiftUI app: Theme, Data (LocalStore + repositories + Remote scaffold),
                       UI (all screens), App (entry, DI, deep links)
App/GenesyxTests/      Repository / DTO / deep-link / backend-swap tests
supabase/functions/    Edge Function stubs for v1.x (partner accept/unlink, account delete)
project.yml            XcodeGen manifest (reproducible Xcode project)
.github/workflows/     CI: swift test + xcodebuild test on macOS
```

## Docs
| Doc | What |
|---|---|
| `ARCHITECTURE.md` | Source-of-truth SwiftUI architecture (read first) |
| `docs/DEPLOYMENT_REPORT.md` | Where we are → App Store |
| `docs/WHATS_LEFT.md` | Live status & gap checklist |
| `docs/MAC_SETUP.md` | Run on your Mac, step by step |
| `docs/RELEASE_ROADMAP.md` | Zero → App Store submission |
| `docs/APP_STORE_LISTING.md` | Paste-ready listing copy + answers |
| `docs/PRIVACY_POLICY.md` | Ready-to-host privacy policy |
| `docs/SUPABASE.md` | How to switch the backend on (v1.x) |
| `docs/OODA.md`, `docs/PLAYBOOK.md` | Working method + the build playbook |

## Notes
- v1 is **local-only** (on-device storage, mock auth) — simplest, fastest App Store path.
- Every repository takes an optional backend; turning Supabase on = link the package + set
  `Secrets.xcconfig` (no call-site changes).
- ⚠️ iOS apps require a **Mac with Xcode** to build, sign, and submit.
