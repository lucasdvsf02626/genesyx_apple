# Genesyx — Backend Live Test Plan (Supabase)

Run this once the app is connected to Supabase (packages added, `Secrets.xcconfig` wired,
Edge Functions deployed). Drive steps in the app (simulator/device); a dashboard watcher
(Supabase Table Editor + Auth → Users + Edge Function logs) verifies each step.

Project ref: `epltxklawpcxxbaleswg`

## Preconditions
- [ ] `supabase-swift` + `GoogleSignIn` packages added to the Genesyx target
- [ ] "Sign in with Apple" capability enabled on the target
- [ ] `Secrets.xcconfig` set as Debug+Release base config; empty inline `SUPABASE_*` removed
- [ ] Edge Functions deployed: `accept_partner_invite`, `unlink_partner`, `delete_account`
- [ ] App build links cleanly (`canImport(Supabase)` + `canImport(GoogleSignIn)` true)

## Test matrix

| # | Action (in app) | Expected in Supabase |
|---|-----------------|----------------------|
| 1 | Sign up with email A (`test-a+…`) | Auth → Users has A; `profiles` row auto-created (trigger `on_auth_user_created`) with same id |
| 2 | Save cycle settings · log a day · add a pH reading (as A) | one row each in `cycle_settings` / `daily_logs` / `ph_readings`, all `user_id = A` |
| 3 | Sign out, then Sign in with Apple | Apple user in Auth → Users; `profiles` row exists |
| 4 | Sign in with Google (iOS) | Google user in Auth → Users; `profiles` row exists |
| 5 | Send partner invite from A to email B | `partner_invites` row: inviter_id=A, invitee_email=B, status=`pending` |
| 6 | Sign up B, accept invite (as B) | invite status → `accepted`; BOTH `profiles.partner_id` cross-linked |
| 7 | Delete account (B) | B removed from Auth → Users; B's rows gone from all 5 tables |
| 8 | RLS isolation | A cannot read B's rows (verify via a signed-in-as-A read + a SQL group-by user_id) |

## Notes
- Confirm-email is OFF, so step 1 signs in immediately.
- Apple sign-in requires a real device or a simulator signed into an Apple ID.
- Partner accept requires the invitee to sign up with the exact invited email (403 otherwise).
- Apple client-secret JWT expires ~180 days after generation (~early Jan 2027) — regenerate before then.
