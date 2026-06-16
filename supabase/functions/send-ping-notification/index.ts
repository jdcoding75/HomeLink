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

// [link-era] Resolve the SENDER's display name from public.users — pairing-
// independent, works for ANY sender. The old `connections` lookup is DEAD in the
// link era (no pairing rows) → it always returned null → the "someone who loves
// you" fallback (bug #9). The recipient's own LOCAL label isn't on the server (it
// lives in the app's SwiftData); the in-app arrival applies that local-label
// precedence (resolvedSenderName). Here we give the PUSH BANNER the sender's
// self-chosen name. `recipientId` is no longer used server-side.
async function nameOfSender(senderId: string, _recipientId: string): Promise<string | null> {
  const { data: row } = await supabase
    .from("users")
    .select("display_name")
    .eq("id", senderId)
    .maybeSingle();
  if (row?.display_name) return row.display_name;
  return null;
  // [pre-link-era — RETIRED] read the recipient's person-card label off the dead
  // pairing `connections` table (owner = recipient, friend = sender):
  // const { data: ownRows } = await supabase
  //   .from("connections")
  //   .select("person_name")
  //   .eq("owner", recipientId)
  //   .eq("friend", senderId)
  //   .limit(1);
  // if (ownRows?.[0]?.person_name) return ownRows[0].person_name;
  // return null;
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
    // [Jess model] EVERY connected (PATH-1) thought announces itself with its own
    // NAMED banner — regardless of the unread count. (The old "only the first unread
    // announces, the rest go badge-only/silent" rule is removed below: it suppressed
    // the banner whenever unread > 1, and a recipient whose unread never clears would
    // then NEVER see a banner — only the badge climbing.) The badge still increments.
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

    // The data the app needs either way — felt receipts (opened_at) and the
    // SENDER's catch animation when the push is the only path.
    // [bootfix] renamed `payload` → `pushData`: the outer `const payload =
    // await req.json()` (the webhook envelope) already owns `payload` in this
    // scope, so a second `const payload` here was a duplicate declaration that
    // crashed boot ("Identifier 'payload' has already been declared"). Same
    // object/fields — only the local name changed.
    const pushData = {
      pingEmoji: record.emoji ?? "💜",
      // [link-era] was: senderName ?? "someone who loves you"  ← bug #9 old-phase copy.
      // Now a neutral last-resort name (matches the app's resolvedSenderName /
      // pointing-branch convention) when the sender truly has no display_name.
      fromName: senderName ?? "someone",
      pingId: record.id ?? null,
      senderStyle: record.sender_style ?? null,
      fromUserId: record.from_user ?? null,
      message: record.message ?? null,        // [5/5] optional note
      tagline: record.tagline ?? null,        // sender's per-person tagline
    };

    // The notification body grows more personal when a tagline (or message)
    // rides along: tagline first ("near is a feeling ✦"), then the message,
    // then the gentle generic pull.
    const notifBody = record.tagline
      ? `${record.tagline} ✦`
      : (record.message ?? "A feeling is coming your way…");

    // [Jess model] The banner is NAMED: "<sender> sent you a thought ✦". Only when
    // the sender truly has no name (users.display_name null — the onboarding #6 bug)
    // do we fall back to a gentle generic — NEVER "Pointward", NEVER "someone who
    // loves you" (bug #9).
    const notifTitle = senderName
      ? `${senderName} sent you a thought ✦`
      : "A thought is on its way ✦";

    // [always-alert fix] SILENT badge-only branch REMOVED — every PATH-1 thought
    // gets a visible named banner now (the badge below still reflects `unread`).
    // The old branch sent `aps: { badge }` with NO `alert`, so iOS showed no banner /
    // no Notification-Center entry; with a stuck-high unread it suppressed EVERY
    // banner. (Note: `pushToDevice` always sends `apns-push-type: alert` — there was
    // no background/content-available push here to preserve.) Reversible.
    // [pre-fix] QUEUE NOTIFICATION RULE: only the FIRST unread announces itself.
    // [pre-fix] A backlog updates the badge silently — no banner, no sound.
    // if (unread > 1) {
    //   console.log(`ping: ${unread} unread — badge-only update`);
    //   return await sendPush(record.to_user, {
    //     aps: { badge: unread },
    //     ...pushData,
    //   });
    // }

    // Every PATH-1 thought → a VISIBLE NAMED alert (badge still rides along).
    return await sendPush(record.to_user, {
      aps: {
        // [pre-Jess-model] generic title:
        // alert: { title: "Pointward", body: notifBody },
        alert: { title: notifTitle, body: notifBody },
        sound: "default",
        badge: unread,
      },
      ...pushData,
    });
  } catch (e) {
    console.error(`handler error: ${e}`);
    return new Response(`error: ${e}`, { status: 500 });
  }
});
