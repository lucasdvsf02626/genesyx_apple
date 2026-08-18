---
type: "query"
date: "2026-08-14T13:07:41.033947+00:00"
question: "give me a checklist to make it happe and piblish this app"
contributor: "graphify"
outcome: "useful"
source_nodes: ["APP_STORE_SUBMISSION.md", "RELEASE_ROADMAP.md", "TestFlight — Genesyx 1.2.0 (18)", "PRIVACY_POLICY.md", "prepare_store_screenshots.sh"]
---

# Q: give me a checklist to make it happe and piblish this app

## Answer

Expanded from original query via graph vocab: app, store, testflight, release, archive, signing, privacy, review, build, version, submission, screenshots. Current source is 1.2.0 build 18 at HEAD 1b61e81 with a large uncommitted working tree. Build 18 is archived but not uploaded and excludes H21/H22, so the release candidate needs a reviewed commit and a new unique build number, likely 19 after checking App Store Connect. Public submission remains blocked by the guide PDF corrections and medical review, Article 9 lawful-basis or auditable explicit-consent decision, Sign in with Apple token revocation and honest waitlist cleanup, disposable-account deletion QA, password-reset completion, fresh screenshots, and incomplete App Store Connect privacy, age-rating, regulated-medical, DSA, metadata, build-selection, review-access and submission fields. Physical iPhone QA is deferred due unavailable hardware but is a release risk rather than an Apple upload prerequisite. Existing production migration must be checked into source before freezing. Final path: finish tests, commit product files excluding graphify tooling, bump build, archive Release, upload to TestFlight, complete metadata and compliance, Add for Review, Submit for Review, then manually release after approval.

## Outcome

- Signal: useful

## Source Nodes

- APP_STORE_SUBMISSION.md
- RELEASE_ROADMAP.md
- TestFlight — Genesyx 1.2.0 (18)
- PRIVACY_POLICY.md
- prepare_store_screenshots.sh