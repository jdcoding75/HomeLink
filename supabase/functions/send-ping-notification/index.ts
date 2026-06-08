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
  // [1/5] Fail loudly if a secret is missing — the #1 cause of "push stopped
  // working" is an unset/rotated APNS_KEY_P8 after a redeploy.
  const keyPem = Deno.env.get("APNS_KEY_P8");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  console.log(`push chain ④ APNs JWT: keyP8=${keyPem ? "set" : "MISSING"} ` +
    `keyId=${keyId ?? "MISSING"} teamId=${teamId ?? "MISSING"} ` +
    `topic=${Deno.env.get("APNS_TOPIC") ?? "MISSING"}`);
  if (!keyPem || !keyId || !teamId) {
    throw new Error("APNs secrets missing — run `supabase secrets set APNS_KEY_P8/APNS_KEY_ID/APNS_TEAM_ID`");
  }

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

const PROD_HOST    = "https://api.push.apple.com";
const SANDBOX_HOST = "https://api.sandbox.push.apple.com";

async function pushToDevice(host: string, token: string, jwt: string,
                            topic: string, aps: Record<string, unknown>): Promise<number> {
  const res = await fetch(`${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify(aps),
  });
  return res.status;
}

async function sendPush(toUser: string, aps: Record<string, unknown>): Promise<Response> {
  const { data: tokens, error } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", toUser);
  if (error) throw error;
  console.log(`push chain ③ tokens: ${tokens?.length ?? 0} device(s) for user ${toUser.slice(0, 8)}`);
  if (!tokens || tokens.length === 0) {
    console.log("push chain ③ tokens: NONE — recipient never registered a device token");
    return new Response("no devices", { status: 200 });
  }

  const topic = Deno.env.get("APNS_TOPIC")!;
  const jwt = await apnsJWT();
  // TestFlight/App Store devices use PRODUCTION APNs; Xcode dev builds use
  // SANDBOX. Tokens don't say which they are, so try prod first and fall
  // back to sandbox on BadDeviceToken (400/410). APNS_SANDBOX=true flips
  // the order for dev-heavy periods.
  const preferSandbox = Deno.env.get("APNS_SANDBOX") === "true";
  const order = preferSandbox ? [SANDBOX_HOST, PROD_HOST] : [PROD_HOST, SANDBOX_HOST];

  const results = await Promise.all(
    tokens.map(async (t) => {
      const first = await pushToDevice(order[0], t.token, jwt, topic, aps);
      if (first === 400 || first === 410) {
        const second = await pushToDevice(order[1], t.token, jwt, topic, aps);
        return { token: t.token.slice(0, 8), first, second };
      }
      return { token: t.token.slice(0, 8), first };
    }),
  );
  console.log("push chain ⑤ APNs:", JSON.stringify(results));
  // Surface any non-200 APNs status (400/410 BadDeviceToken, 403 bad cert…).
  const failures = results.filter((r) =>
    (r.second ?? r.first) !== 200);
  if (failures.length > 0) {
    console.error(`push chain ⑤ APNs: ${failures.length} device(s) FAILED — ${JSON.stringify(failures)}`);
  }
  return new Response(JSON.stringify({ sent: results }), { status: 200 });
}

// The RECIPIENT's name for the sender — their own person card label,
// stored on the connection row they own (owner = recipient, friend = sender).
// Falls back to the sender-side person_name, then null.
async function nameOfSender(senderId: string, recipientId: string): Promise<string | null> {
  const { data: ownRows } = await supabase
    .from("connections")
    .select("person_name")
    .eq("owner", recipientId)
    .eq("friend", senderId)
    .limit(1);
  if (ownRows?.[0]?.person_name) return ownRows[0].person_name;
  return null;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record) return new Response("no record", { status: 400 });

    // ── Pointing: compass_bearings insert/update → notify the partner ──────
    if (payload.table === "compass_bearings") {
      const userId = record.user_id;
      if (!userId) return new Response("no user", { status: 400 });

      // Who are they paired with?
      const { data: conns } = await supabase
        .from("connections")
        .select("owner, friend")
        .or(`owner.eq.${userId},friend.eq.${userId}`);
      const conn = conns?.find((c) => c.friend);
      const partner = conn
        ? (conn.owner === userId ? conn.friend : conn.owner)
        : null;
      if (!partner) return new Response("no partner", { status: 200 });

      // Respect the recipient's "notify me when someone points toward me"
      const { data: prefs } = await supabase
        .from("users")
        .select("notify_pointing")
        .eq("id", partner)
        .maybeSingle();
      if (prefs && prefs.notify_pointing === false) {
        return new Response("muted", { status: 200 });
      }

      const pointerName = await nameOfSender(userId, partner);
      console.log(`pointing: ${userId} → ${partner} (${pointerName ?? "someone"})`);
      return await sendPush(partner, {
        aps: {
          alert: {
            title: `${pointerName ?? "someone"} is pointing toward you 🧭`,
            body: "A feeling is coming your way…",
          },
          sound: "default",
        },
        type: "pointing",
        fromName: pointerName ?? "someone",
      });
    }

    // ── Pings: insert → notify the recipient ───────────────────────────────
    // First unread = full notification; a backlog collapses into a count so
    // we never spam multiple full alerts.
    if (!record.to_user) return new Response("no recipient", { status: 400 });

    const { count } = await supabase
      .from("pings")
      .select("id", { count: "exact", head: true })
      .eq("to_user", record.to_user)
      .is("opened_at", null);
    const unread = count ?? 1;

    // Resolve who it's from so the catch screen can say their name
    const senderName = record.from_user
      ? await nameOfSender(record.from_user, record.to_user)
      : null;

    console.log(`ping: ${record.from_user} → ${record.to_user} ` +
      `emoji=${record.emoji} style=${record.sender_style} id=${record.id} unread=${unread}`);

    // The payload the app needs either way — felt receipts (opened_at)
    // and the SENDER's catch animation when the push is the only path.
    const payload = {
      pingEmoji: record.emoji ?? "💜",
      fromName: senderName ?? "someone who loves you",
      pingId: record.id ?? null,
      senderStyle: record.sender_style ?? null,
      fromUserId: record.from_user ?? null,
      message: record.message ?? null,        // [5/5] optional note
    };

    // QUEUE NOTIFICATION RULE: only the FIRST unread announces itself.
    // A backlog updates the badge silently — no banner, no sound.
    if (unread > 1) {
      console.log(`ping: ${unread} unread — badge-only update`);
      return await sendPush(record.to_user, {
        aps: { badge: unread },
        ...payload,
      });
    }

    // The mystery is the gift — no emoji, no name, just the pull.
    return await sendPush(record.to_user, {
      aps: {
        alert: { title: "Pointward", body: "A feeling is coming your way…" },
        sound: "default",
        badge: unread,
      },
      ...payload,
    });
  } catch (e) {
    console.error(`handler error: ${e}`);
    return new Response(`error: ${e}`, { status: 500 });
  }
});
