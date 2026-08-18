// Sign in with Apple token revocation.
//
// REQUIRED by App Store review for any app that offers Sign in with Apple and account deletion:
// deleting the account must also revoke the tokens Apple issued for it, or the app is rejected.
//
// WHERE THE TOKEN COMES FROM, AND WHY THIS TAKES AN AUTHORIZATION CODE.
// Apple's `/auth/revoke` needs a refresh or access token that Apple itself issued. This project has
// neither and cannot look one up. The app signs in with `signInWithIdToken` (`AuthView.handleApple`
// reads `cred.identityToken` and nothing else), which hands Supabase a finished ID token — there is
// no authorization-code exchange anywhere in the flow, so Apple never issues a refresh token and
// Supabase never stores one. `auth.identities.identity_data` holds the decoded ID-token claims
// (`sub`, `email`) and no token material.
//
// So the code cannot be found server-side; it has to be supplied. `ASAuthorizationAppleIDCredential`
// carries `authorizationCode` alongside the `identityToken` the app already reads, and it is valid
// for five minutes — long enough to be collected during the delete confirmation and spent here, and
// short enough that nothing durable is stored. That is why this module exchanges a code rather than
// reading a saved token: the alternative is persisting an Apple refresh token indefinitely, which is
// a far larger secret to hold for a step that runs once in an account's lifetime.
//
// NOTHING SENSITIVE IS EVER LOGGED. The private key, the generated client secret, the authorization
// code and the refresh token are all secrets. Only HTTP status and Apple's `error` enum
// (`invalid_client`, `invalid_grant`, ...) reach the log, because those are what actually identify a
// misconfiguration and they name no secret.

const APPLE_ISSUER = "https://appleid.apple.com";
const TOKEN_URL = `${APPLE_ISSUER}/auth/token`;
const REVOKE_URL = `${APPLE_ISSUER}/auth/revoke`;

/// Thrown when the revoke could not be completed. The message is safe to log and never contains
/// token material.
export class AppleRevokeFailed extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AppleRevokeFailed";
  }
}

interface AppleConfig {
  teamId: string;
  clientId: string;
  keyId: string;
  privateKey: string;
}

/// All four values or nothing. There are deliberately no defaults — a half-configured revoke that
/// silently targets the wrong `client_id` would fail in a way that looks like Apple's fault, and
/// `clientId` in particular is the bundle ID (`com.genesyx.app`), which is exactly the sort of value
/// that gets quietly wrong between environments.
export function appleConfig(): AppleConfig | null {
  const teamId = Deno.env.get("APPLE_TEAM_ID")?.trim();
  const clientId = Deno.env.get("APPLE_CLIENT_ID")?.trim();
  const keyId = Deno.env.get("APPLE_KEY_ID")?.trim();
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY")?.trim();
  if (!teamId || !clientId || !keyId || !privateKey) return null;
  return { teamId, clientId, keyId, privateKey };
}

/// True if this account can sign in with Apple. Checked from both `identities` and `app_metadata`
/// because a user who linked Apple to an existing email account has it in `identities` while
/// `app_metadata.provider` still names whichever provider came first.
export function hasAppleIdentity(user: {
  identities?: Array<{ provider?: string | null }> | null;
  app_metadata?: Record<string, unknown> | null;
}): boolean {
  if ((user.identities ?? []).some((i) => i?.provider === "apple")) return true;
  const meta = user.app_metadata ?? {};
  const providers = meta.providers;
  if (Array.isArray(providers) && providers.includes("apple")) return true;
  return meta.provider === "apple";
}

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/// PKCS#8 PEM -> DER. The `\\n` unescape is not cosmetic: a `.p8` pasted into a secret store usually
/// arrives with literal backslash-n rather than real newlines, and those two characters are not valid
/// base64, so `atob` would throw on an otherwise correct key.
function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN[^-]*-----/g, "")
    .replace(/-----END[^-]*-----/g, "")
    .replace(/\s+/g, "");
  let binary: string;
  try {
    binary = atob(body);
  } catch {
    throw new AppleRevokeFailed("APPLE_PRIVATE_KEY is not valid PKCS#8 PEM");
  }
  // Backed by an explicit ArrayBuffer: `new Uint8Array(length)` widens to `ArrayBufferLike`, which
  // WebCrypto's `BufferSource` no longer accepts because it could be a SharedArrayBuffer.
  const der = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i++) der[i] = binary.charCodeAt(i);
  return der;
}

/// Apple authenticates the caller with a short-lived ES256 JWT rather than a static secret. Five
/// minutes is deliberate — Apple permits up to six months, but this one is minted per request and
/// spent immediately, so a longer life would only widen the window if it ever leaked.
async function makeClientSecret(cfg: AppleConfig): Promise<string> {
  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "pkcs8",
      pemToDer(cfg.privateKey),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  } catch (e) {
    if (e instanceof AppleRevokeFailed) throw e;
    throw new AppleRevokeFailed("APPLE_PRIVATE_KEY could not be imported as an ES256 key");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: cfg.keyId, typ: "JWT" };
  const payload = {
    iss: cfg.teamId,
    iat: now,
    exp: now + 300,
    aud: APPLE_ISSUER,
    sub: cfg.clientId,
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;

  // WebCrypto's ECDSA output is the raw r||s pair, which is precisely what JWS ES256 expects. No
  // DER unwrapping here on purpose: OpenSSL-style signatures would need it, WebCrypto's do not.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

/// Apple returns JSON on error and an empty 200 on success. Only the `error` enum is surfaced —
/// never the body, which can echo back the code that was sent.
async function appleError(res: Response): Promise<string> {
  try {
    const body = await res.json();
    const code = typeof body?.error === "string" ? body.error : "unknown";
    return `HTTP ${res.status} (${code})`;
  } catch {
    return `HTTP ${res.status}`;
  }
}

/// Exchange the app's one-time authorization code for a refresh token, then revoke it. Revoking the
/// refresh token invalidates the access token issued with it, so one call retires the grant.
///
/// Throws `AppleRevokeFailed` for every failure path, including missing configuration, so the caller
/// makes a single decision about whether an unrevoked account may still be deleted.
export async function revokeAppleTokens(authorizationCode: string): Promise<void> {
  const cfg = appleConfig();
  if (!cfg) {
    throw new AppleRevokeFailed(
      "Apple revoke is not configured (need APPLE_TEAM_ID, APPLE_CLIENT_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY)",
    );
  }

  const clientSecret = await makeClientSecret(cfg);

  // No `redirect_uri`: this code came from the native `ASAuthorizationController`, where the
  // `client_id` is the bundle ID and Apple expects the parameter to be absent. Sending one here is
  // the usual cause of an `invalid_grant` that looks like an expired code.
  const exchange = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: cfg.clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!exchange.ok) {
    throw new AppleRevokeFailed(`authorization code exchange rejected — ${await appleError(exchange)}`);
  }

  const tokens = await exchange.json().catch(() => null);
  const refreshToken = typeof tokens?.refresh_token === "string" ? tokens.refresh_token : null;
  if (!refreshToken) throw new AppleRevokeFailed("Apple returned no refresh_token to revoke");

  const revoke = await fetch(REVOKE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: cfg.clientId,
      client_secret: clientSecret,
      token: refreshToken,
      token_type_hint: "refresh_token",
    }),
  });
  if (!revoke.ok) {
    throw new AppleRevokeFailed(`revoke rejected — ${await appleError(revoke)}`);
  }
}
