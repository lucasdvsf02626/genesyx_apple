# Supabase Edge Functions (v1.x)

Privileged operations that cannot run from the app with the anon key (they need the service
role). The iOS `SupabaseBackend` calls these by name. Deploy with the Supabase CLI:

```bash
supabase functions deploy accept_partner_invite
supabase functions deploy decline_partner_invite
supabase functions deploy revoke_partner_invite
supabase functions deploy send_partner_invite
supabase functions deploy unlink_partner
supabase functions deploy delete_account
```

`decline_partner_invite` requires `20260812_partner_invite_hardening.sql` to have been applied
first — it writes `status = 'declined'`, which the pre-migration CHECK constraint rejects. Deploy
it after the migration, never before.

Each function expects the caller's JWT in the `Authorization` header (the supabase-swift client
sends it automatically). Required env (auto-provided to Edge Functions): `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_ANON_KEY` — the last one is what `requireUser` builds
its client from, so a function without it fails every call as unauthenticated.

## `verify_jwt` is ON as of 2026-08-13 — but never write a function that relies on it

**There is no `supabase/config.toml` in this repo**, so `supabase functions deploy` takes the CLI
default, which is `verify_jwt: true`. That is how it got turned on: it was a side effect of the
13 Aug deploy, taken deliberately rather than suppressed with `--no-verify-jwt`.

Confirmed by unauthenticated probe immediately after that deploy — all six now answer an anonymous
POST with the **gateway's** shape:

```
401  {"code":"UNAUTHORIZED_NO_AUTH_HEADER","message":"Missing authorization header"}
```

Note that shape. It is not any `catch` block in this directory — those return
`{"error":"Not authenticated"}` or `{"ok":false,...,"reason":"not_authenticated"}`. Telling the two
apart is the only way to know which layer answered, and therefore the only way to check this
setting from outside. **It was OFF until 13 Aug**, and it is a deploy-time flag with no trace in a
diff, so re-probe rather than trusting this paragraph.

**Keep `requireUser` in every function anyway — `verify_jwt` on is a narrower gate than it sounds.**
Probed 13 Aug against `unlink_partner`, all four cases:

| Request | Answered by | Status |
|---|---|---|
| no headers | gateway — `UNAUTHORIZED_NO_AUTH_HEADER` | 401 |
| `apikey:` only, no `Authorization` | **the function** — `{"error":"Not authenticated"}` | 401 |
| `Authorization: Bearer <publishable key>` | **the function** — `{"error":"Not authenticated"}` | 401 |
| `Authorization: Bearer <bad-signature JWT>` | gateway — `UNAUTHORIZED_LEGACY_JWT` | 401 |

Read rows 2 and 3. **The publishable key alone is enough to reach the function body**, `verify_jwt`
or not — it is a public key, shipped in the app bundle, and anyone can read it out. All the gateway
buys you is that a *malformed or badly-signed* token is rejected early. `requireUser` is still what
stands between a stranger and anything that matters, and one `--no-verify-jwt` on a future deploy
removes even the narrow part silently.

Rows 2 and 3 are also the live proof that the `NotAuthenticated` split works: that is this
directory's own 401, returned from a real deployed function, not a typecheck.

### Why the `NotAuthenticated` split still matters

`send_partner_invite` and `revoke_partner_invite` were written on the assumption that a gateway was
in front of them — which was false at the time — and on that premise mapped the auth failure to
**500 "unhandled"**, so a caller with an expired token was told the server was broken. The other
four had the mirror bug: a blanket **401** for *every* throw, reporting a malformed body or a
database outage as an auth problem and sending the app to a sign-in screen that could not fix it.

Both are fixed by the same thing. `requireUser` throws `NotAuthenticated` (`_shared/client.ts`) and
nothing else does, so each `catch` tests for it: that type is 401, everything else is 500 with the
detail logged rather than returned. **Mirror this in any new function.** It is correct whichever way
`verify_jwt` is set, which is the whole point — the setting is not visible from the code, so the
code must not depend on knowing it.

## Sign in with Apple revocation (`delete_account`)

Apple requires that deleting an account also revokes the grant it issued. `delete_account` does this
first, before anything is destroyed, so a failed revoke leaves the account intact and retryable.

**It needs an authorization code from the client, and the shipping build does not send one.**
`AuthView.handleApple` reads `cred.identityToken` and calls `signInWithIdToken`, so there is no
code exchange anywhere in the flow: Apple never issues a refresh token, Supabase never stores one,
and `auth.identities.identity_data` holds only decoded claims. Nothing server-side can be looked up
and revoked. The app must read `cred.authorizationCode` at the delete confirmation and POST it as
`{"appleAuthorizationCode": "..."}`. Until it does, **Apple's requirement is not met**.

Set these four secrets, none of which have defaults:

```bash
supabase secrets set APPLE_TEAM_ID=XXXXXXXXXX          # Apple Developer team id
supabase secrets set APPLE_CLIENT_ID=com.genesyx.app   # the BUNDLE id for a native app, not a Services ID
supabase secrets set APPLE_KEY_ID=XXXXXXXXXX           # key id of the Sign in with Apple .p8
supabase secrets set APPLE_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
```

The `.p8` goes into Supabase secrets and nowhere else — never a commit, never a chat. Literal `\n`
in `APPLE_PRIVATE_KEY` is handled, so a pasted single-line key works.

`APPLE_REVOKE_REQUIRED` is the enforcement switch and **defaults to off**. Off, a missing or failed
revoke is logged and deletion proceeds; on, it returns 500 and deletes nothing. It defaults off
because turning it on before the client sends a code would break deletion for every existing Apple
user — trading a Sign in with Apple violation for a 5.1.1(v) one, which is the requirement this
function exists to satisfy. Order of operations:

1. Deploy with the four secrets set. Inert for accounts that send no code.
2. Ship the client that sends `appleAuthorizationCode`.
3. `supabase secrets set APPLE_REVOKE_REQUIRED=true`.

Step 3 is what actually closes the Apple requirement. Steps 1 and 2 alone do not.

Non-Apple accounts skip all of this — `hasAppleIdentity` checks both `identities` and
`app_metadata`, and email/Google deletions behave exactly as before.

Mirrors the Android `docs/ARCHITECTURE.md` Open Decisions (privileged ops via Edge Functions).
