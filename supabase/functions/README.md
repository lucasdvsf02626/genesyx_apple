# Supabase Edge Functions (v1.x)

Privileged operations that cannot run from the app with the anon key (they need the service
role). The iOS `SupabaseBackend` calls these by name. Deploy with the Supabase CLI:

```bash
supabase functions deploy accept_partner_invite
supabase functions deploy unlink_partner
supabase functions deploy delete_account
```

Each function expects the caller's JWT in the `Authorization` header (the supabase-swift client
sends it automatically). They are **stubs with the intended logic** — review against your real
schema/RLS before deploying. Required env (auto-provided to Edge Functions):
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.

Mirrors the Android `docs/ARCHITECTURE.md` Open Decisions (privileged ops via Edge Functions).
