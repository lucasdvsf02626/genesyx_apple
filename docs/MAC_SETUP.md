# Run Genesyx on your Mac — Checklist

Everything you need to go from this repo to the app running on your iPhone.

## 0. Prerequisites (one-time)
- [ ] **macOS** with **Xcode 15+** installed (from the App Store).
- [ ] Open Xcode once and accept the license / install components.
- [ ] Install **XcodeGen** (generates the Xcode project from `project.yml`):
  ```bash
  brew install xcodegen        # needs Homebrew: https://brew.sh
  ```

## 1. Get the code
- [ ] Clone the branch (once repo write access is sorted and commits are pushed):
  ```bash
  git clone https://github.com/lucasdvsf02626/genesyx_apple.git
  cd genesyx_apple
  git checkout claude/blissful-carson-wsdb54
  ```
  *(Or unzip the snapshot I sent.)*

## 2. Verify the domain layer (no Xcode UI needed)
- [ ] Run the pure-logic test suite:
  ```bash
  swift test
  ```
  Expect green: `CycleEngineTests`, `PhInsightLogicTests`, `ContentTests`, `CalendarDateTests`.

## 3. Generate & open the app
- [ ] Generate the Xcode project and open it:
  ```bash
  xcodegen generate
  open Genesyx.xcodeproj
  ```

## 4. Signing (first build only)
- [ ] In Xcode: select the **Genesyx** target → **Signing & Capabilities**.
- [ ] Check **Automatically manage signing**, pick your **Team** (your Apple ID works for device testing).
- [ ] If the bundle id `com.genesyx.app` is taken, change it (e.g. `com.<you>.genesyx`).

## 5. Run
- [ ] Pick an **iPhone 15 simulator** → press ⌘R. The app should launch into onboarding.
- [ ] To run on your **real iPhone**: plug it in, trust the Mac, select it as the run target, ⌘R.
  (First time: on the phone, Settings → General → VPN & Device Management → trust your developer cert.)

## 6. If the build fails
This SwiftUI code has not yet hit a real Swift compiler (it was written on Linux). A few
small fix-ups are normal on first build. **Copy the Xcode error(s) and send them to me** — I'll
turn them around quickly. Most likely areas: minor SwiftUI modifier signatures or an `onChange`
API nuance on your Xcode version.

## 7. Drop in assets (anytime)
- [ ] `AppIcon-1024.png` → `App/Genesyx/Resources/Assets.xcassets/AppIcon.appiconset/`
- [ ] Optional future branding only: follow `App/Genesyx/Resources/Fonts/README.md` before
      switching the shipping system-font type scale to custom fonts.

## 8. Tests in Xcode (optional)
- [ ] ⌘U runs both the `GenesyxCore` tests and the `GenesyxAppTests` (repository/DTO) suite.

---
**Next after a clean run:** archive → TestFlight → App Store Connect (see `RELEASE_ROADMAP.md`).
