// send-ping-notification — Supabase Edge Function
//
// Triggered by a Database Webhook on INSERT into public.pings.
// Looks up the recipient's device tokens and sends a minimal APNs push:
// the emoji + "someone sent you a thought".
//
// Deploy:   supabase functions deploy send-ping-notification
// Secrets:  supabase secrets set \
//             APNS_KEY_P8="$(cat AuthKey_XXXXXXXXXX.p8)" \
//             APNS_KEY_ID=XXXXXXXXXX \
//             APNS_TEAM_ID=78842PK6A3 \
//             APNS_TOPIC=com.jdcoding75.pointward \
//             APNS_SANDBOX=true
// Webhook:  Dashboard → Database → Webhooks → on INSERT public.pings →
//           HTTP POST to this function's URL (include service role auth header).

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── APNs JWT (ES256), cached for ~50 min ────────────────────────────────
let cachedJWT: { token: string; createdAt: number } | null = null;

async function apnsJWT(): Promise<string> {
  const now = Date.now();
  if (cachedJWT && now - cachedJWT.createdAt < 50 * 60 * 1000) {
    return cachedJWT.token;
  }
  const keyPem = Deno.env.get("APNS_KEY_P8")!;
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;

  const pkcs8 = keyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const keyData = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const b64url = (data: string | Uint8Array) => {
    const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
    return btoa(String.fromCharCode(...bytes))
      .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  };

  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = b64url(JSON.stringify({ iss: teamId, iat: Math.floor(now / 1000) }));
  const signingInput = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const token = `${signingInput}.${b64url(new Uint8Array(signature))}`;
  cachedJWT = { token, createdAt: now };
  return token;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const ping = payload.record; // { from_user, to_user, emoji, ... }
    if (!ping?.to_user) {
      return new Response("no record", { status: 400 });
    }

    // Recipient's devices
    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", ping.to_user);
    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      return new Response("no devices", { status: 200 });
    }

    const host = Deno.env.get("APNS_SANDBOX") === "true"
      ? "https://api.sandbox.push.apple.com"
      : "https://api.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;
    const jwt = await apnsJWT();

    const aps = {
      aps: {
        alert: {
          title: ping.emoji ?? "💜",
          body: "someone sent you a thought",
        },
        sound: "default",
      },
      pingEmoji: ping.emoji ?? "💜",
      fromName: "someone who loves you",
    };

    const results = await Promise.all(
      tokens.map((t) =>
        fetch(`${host}/3/device/${t.token}`, {
          method: "POST",
          headers: {
            "authorization": `bearer ${jwt}`,
            "apns-topic": topic,
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          body: JSON.stringify(aps),
        }).then((r) => r.status)
      ),
    );

    return new Response(JSON.stringify({ sent: results }), { status: 200 });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
