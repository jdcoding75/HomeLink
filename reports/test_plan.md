# Pointward — Two-Phone Test Plan

_Repeatable, follow-it-cold test plan. DOC ONLY. Three passes; run them in order._

> ⚠️ **ORDER MATTERS.** **PASS 1 needs Phone B to be a FRESH, NO-APP install** — so **run PASS 1
> first**, before PASS 2/3 put the app on B. PASS 3 needs the **tester-unlock build** (see
> `reports/tester_unlock_spec.md`) — skip it until that exists.

---

## Install methods (what each pass is actually testing)

| Method | Build config | Paywall | Who / how | Notes |
|--------|-------------|---------|-----------|-------|
| **Xcode build** | **Debug** | **Bypassed** (DEBUG registers `subscriptionTier=unlocked` + `proFeaturesEnabled=true`) | cabled device only, run from Xcode | Dev stuff visible; **NOT how real users get the app**. Don't trust paywall/premium behavior here. |
| **TestFlight internal** | **Release** | **LIVE** | John + wife (added as **internal testers** by Apple ID) | Instant, **no review**. The everyday loop. Premium is gated (this is why PASS 3 needs the tester-unlock). |
| **TestFlight public link** | **Release** | **LIVE** | anyone taps **`testflight.apple.com/join/rjAS4cnk`** | The real **stranger** path. What PASS 1's no-app install uses. |

**Key implication:** the paywall is real in BOTH TestFlight builds. Premium animations are gated for
internal testers too — until the tester-unlock ships, exercise premium content on a Debug (Xcode)
build OR via the tester-unlock build (PASS 3).

---

## PASS 1 — EXTERNAL FUNNEL (no-app stranger install) · 2 phones

**Goal:** prove the full stranger funnel: a thought → web page → public-link install → onboard →
receive → reply.

**Setup**
- **Phone A (sender):** HAS the app (TestFlight internal or public — Release).
- **Phone B (recipient):** **MUST START WITH NO APP — delete Pointward first.** Confirm it's gone
  (and ideally sign out of any prior TestFlight install) so B is a true fresh stranger.

**Steps**
1. **A → send a thought.** On A's compass, pick a person/emoji and send to B (this is a PATH-2 link
   send since B isn't a connected contact). The **share sheet** should appear after the send
   animation; share the link to B (Messages/etc.).
2. **B → tap the link.** B has no app → the **web page** (pointward.app/m/<id>) loads and **shows the
   thought** (sender name, emoji, message).
3. **B → "get Pointward".** Tapping it opens the **public TestFlight link** → B installs.
4. **B → open + onboard.** Sign in with Apple → about-you (name, optional location) → finish.
5. **B → receives the thought.** After the **onboarding-replay fix (`435eb4f`)** the captured link
   should **auto-play the thought right after onboarding completes.** If it does NOT auto-play, fall
   back to **short-code entry** (the code from the share text).
6. **B → send one back.** From the landing "send one back to [A]" (or the compass) → B replies.
7. **A → receives B's reply.** (If A's app is open → realtime; if closed → see PASS 2.)

**Watch / capture (note it, don't stop to fix):**
- Send **animation + receipt order**; **share-sheet timing** (should be AFTER the send animation).
- Whether the thought **auto-plays after onboarding** (the `435eb4f` fix) or needed a re-tap / short
  code.
- Whether the **"✓ sent to [Name]"** confirmation shows on each send.
- Whether the **paywall EVER blocks RECEIVING** — it must **not** (receiving is always free).
- Whether B's contact for A (and A's for B) **auto-creates** and shows **"connected"** (note:
  PATH-1-receive connected-stamp is a known gap — see `reports/receive_audit.md`).

---

## PASS 2 — PUSH / CLOSED-APP RECEIVE (verifies the Track-2 fixes) · 2 phones

**Goal:** confirm closed-app push delivery now works after the stale-token purge + edge-function
auto-prune.

**Setup**
- **Both phones HAVE the app** (TestFlight internal/Release). **Both signed in.** (B can be the phone
  from PASS 1, now installed.)
- Make sure **notifications are allowed** on the recipient (Settings → Pointward → Notifications).

**Steps**
1. Make A and B **connected** (exchange at least one thought each so senderID is stamped — easiest
   after PASS 1).
2. **Fully CLOSE** the recipient's app (swipe it away — not just background).
3. The other phone **sends a thought** to the closed recipient.
4. The recipient should get a **push banner: "[name] sent you a thought ✦"**, and **tapping it plays
   the thought.**
5. Repeat in the other direction.

**Watch / capture:**
- Does the **closed-app push arrive** now (post stale-token purge + the 410/400 auto-prune)?
- Does it play on tap with the right **sender name / emoji / animation**?
- **device_tokens hygiene:** after a few sends, the table should **stay clean (≤ ~3 rows per user)** —
  the edge function self-prunes dead tokens on 410/400. (Check in Supabase if you want proof.)
- Closed-app receive is **PATH-1 only**; a PATH-2 **link** send to a closed app has **no push** (it's
  link-tap only) — that's expected, not a bug.

---

## PASS 3 — INTERNAL FEATURE PASS (all animations) · 2 phones

> ✅ **UPDATE (2026-06-22) — v1 ships 100% FREE (no paywall, no payment), so PASS 3 no longer needs the
> tester-unlock.** Once the small **"unlock everything / disable the live paywall"** change ships (all
> instruments free in Release), **every animation is testable directly** on an internal TestFlight
> build — no tester-unlock, no Debug build required. (Tester-unlock is superseded for v1; see
> `reports/tester_unlock_spec.md`.) The prerequisite note below applies only in the (deferred,
> traction-gated) world where a paywall is ever live.

**Prerequisite (only if a paywall is live):** premium animations would be paywalled even for internal
testers, so you'd need either the **"unlock everything for v1"** build (the v1 path) or a Debug
(Xcode) build, or — if a paywall ever returns — the tester-unlock (`reports/tester_unlock_spec.md`).
**No external submission / no review needed** — internal TestFlight.

**Setup:** both phones on the **fully-open internal build** (all instruments free), both signed in.

**Exercise:**
- **Premium animations** — every instrument beyond the free compass (bow, flick, rocket, wind, wand,
  plane, + Special Moments Birthday/Firework): send + receive each, both roles.
- **Paywall gating** — on a NON-unlocked Release device, confirm the **paywall still blocks** premium
  instruments (the unlock must not leak to real users).
- **Emoji / message defaults** — per-instrument defaults seed correctly (e.g. Birthday → "Happy
  Birthday"); user edits stick.
- **Demo Dan** — sending to Demo Dan plays **local-only** (no real insert / no share sheet / no DB
  write); he stays after adding a real person; deletable from People.
- **Inline add-person** — the send-time switcher's "+ add new person" opens AddPersonView; the new
  person is selectable.
- **History / bucket** — replay an item (note: history replays the reveal, not yet the full receipt
  animation — known, see `reports/receive_audit.md`); per-item delete works.

---

## Quick reference

- **Public install link:** `https://testflight.apple.com/join/rjAS4cnk`
- **Fresh-stranger requirement:** PASS 1 only works if Phone B has **no app** at the start.
- **Paywall:** LIVE in all Release/TestFlight builds; never blocks receiving; premium-send needs the
  tester-unlock (PASS 3) or a Debug build.
- **Related:** `reports/receive_audit.md` (receive/push gaps + ranked fixes),
  `reports/push_token_prune_audit.md` (token hygiene), `reports/tester_unlock_spec.md` (PASS 3
  prerequisite).
