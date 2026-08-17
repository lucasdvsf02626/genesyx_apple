# Genesyx — App Store Connect Listing

The canonical, paste-ready App Store metadata and questionnaire guidance now lives in
[`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md). Use that file for every App Store
Connect submission so the repository does not maintain two conflicting listings.

## Current release facts

- **App:** Genesyx: Cycle & Fertility
- **Bundle ID:** `com.genesyx.app`
- **Version:** `1.2.0` — matches `MARKETING_VERSION` in `project.yml`. This line read `1.1.0` while
  the scope notes below already described 1.2.0; the version is the authoritative one in
  `project.yml`, not this file. **Build number is a separate field and must be bumped to 19** —
  build 18 was archived before the auth gate landed, so that archive is void.
- **Primary category:** Health & Fitness
- **Price:** Free
- **Accounts:** Required for cloud sync; email, Google, and Sign in with Apple are supported
- **Collected data:** Email Address, Health, and User ID
- **Tracking:** None
- **Privacy policy:** `https://genesyx.co.uk/policies/privacy-policy`
- **Support:** `https://genesyx.co.uk`
- **Medical status:** Educational wellness app; not a medical device
- **Partner behaviour:** **Out of scope for 1.2.0 — do not describe it in the listing at all.**
  Partner linking is gated off (`FeatureFlags.partnerInvites = false`); no screen, control or deep
  link reaches it in the submitted build. It is expected to return in a later release.
- **Pregnancy mode:** Coming-soon teaser only; do not advertise it as a current Store feature
- **Home Screen widget:** **Not in 1.2.0 and never built** — no extension target, nothing to gate.
  Do not list it, and do not add it to the description or keywords until a build ships one.
- **Barcode scanning / meal photos:** **Not in 1.2.0 and never built.** The binary has no camera or
  photo-library usage string, so it cannot open a capture UI at all. Do not describe food logging as
  scanning or photographing anything; it is manual entry plus food groups.
- **Health-data consent:** the app collects cycle and pH data and holds **no consent record**; the
  lawful basis is an open legal question (P0-13). Do not describe the app as consent-compliant,
  GDPR-compliant or privacy-certified in any Store field.

## Submission rule

Only describe functionality present in the submitted build. Regenerate screenshots from the
same clean build being uploaded and provide App Review with an active demo account.
