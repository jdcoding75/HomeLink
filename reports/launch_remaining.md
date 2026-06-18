# Build 10 → Launch: Everything Remaining

_The one-doc map of all outstanding work, organized by bucket. This is the **index** — it points at
the detailed sources (`POINTWARD_TRUTH.md`, `reports/`) rather than duplicating them. Open here, then
follow the pointers._

_Grounded at HEAD `d977ff7` (clean tree). Update this doc as buckets clear._

---

## 0. STATUS SNAPSHOT

- **Done this stretch:**
  - **Pairing-code subsystem retirement** — full, end-to-end (server + code) across steps 2–8. LINK
    (`link_connections` / `senderID` / `short_code` / `/m/`) is now the sole connection model.
    → `reports/pairing_retire_*` + the TRUTH `_Last updated:_` log.
  - **Build 10 onboarding** — #6 name-persist, link-arriver path (bypass + compose-back + fill-via-link),
    use-current-location, walkthrough fixes, helper-text legibility. → `reports/build10_*`.
  - **Deployment target 26.5 → 17.0** (`4093623`) — installs on shipped iPhones now (was 26.5-only).
    → `reports/deployment_target_build.md`.
  - **Structural cleanup map banked** → `POINTWARD_TRUTH.md` (§"STRUCTURAL CLEANUP MAP") + `reports/structural_map.md`.
- **Apple toolchain gate: ✅ MET** — Xcode 26.5 / iOS 26.5 SDK / macOS Tahoe 26.5.1 / 17.0 floor →
  submission-ready on tooling. (No upgrade needed.)
- **Tests:** 214 green. **Tree:** clean at `d977ff7`.

---

## 1. FORWARD BUILD WORK (features/fixes still to build — none gating)

| Item | Status / effort | Pointer |
|---|---|---|
| **Hint bar v1** — content specced ("Choose Animation (tap-hold center)" · "Customize: receiver/name/message (tap)"); needs placement verify + styling | DEFERRED · non-gating · small | TRUTH Build-10 findings |
| **Settings "How to Use"** → ship a **PLACEHOLDER STUB** for now (visibly there); real content is its own later project, placement TBD | DEFERRED / LOWER | TRUTH (education-in-Settings) |
| **"thought → mini card" copy** — KEEP "thought" for now; warmer phrasing is a post-use polish call | non-gating · revisit after real usage | TRUTH ("mini card" voice) |
| **2c compose-back device-repro** — 30-sec phone diagnostic: which tap fires the receipt (send button = real bug; compass/contact tap = history replay) | LOW priority · probably nothing | `reports/build10_fixbatch_build.md` (2c STOP) |

---

## 2. SMALL PRE-LAUNCH ITEMS (Phase-2-early; non-urgent, non-gating)

| Item | What's there vs. missing | Pointer |
|---|---|---|
| **"Message opened ✦" PUSH to sender** | SMALL wire-up — infra EXISTS (APNs Edge Function, `device_tokens`, `opened`/`opened_at` flip; sender already learns via POLL = the "opened ✦" indicator). Missing: a `send-opened-notification` function variant + a messages-UPDATE webhook + a **Supabase deploy (John runs — CLI tokens revoked)** | `reports/wrapup_audit.md` (Item 2) |
| **Xcode warnings (9, none block submission)** | 3 Supabase-SDK deprecations = careful backbone-adjacent touch when convenient; 5 Swift-6 concurrency (incl the **PingPayload PATH-1 pair**) = deliberate Swift-6 pass (**staying Swift 5 through launch**); `placemark` left intentionally (replacement is iOS-26-only) | `reports/wrapup_audit.md` (Item 3) + TRUTH warnings note |
| **Send-sound** | Almost certainly a DEBUG/sim artifact — **no DEBUG-vs-RELEASE branch in the audio path**; just needs a **RELEASE-on-device LISTEN** to confirm (no code task). If distorted in release → animation track | `reports/wrapup_audit.md` (Item 4) |

---

## 3. CODE HYGIENE / CLEANUP (POST-TESTFLIGHT — ranked plan already banked)

**Pointer:** full ranked, risk-tagged map in `POINTWARD_TRUTH.md` (§"STRUCTURAL CLEANUP MAP") +
`reports/structural_map.md`. **Order:** dead-code delete (~810 lines, zero-risk) → **SupabaseService
extension-split (#1 parallelism unlock)** → duplication consolidation (sign-in + address helpers) →
CompassView subview extraction → `pairedUserID → senderID` migration (LAST, PATH-1-careful). **Goal:**
containment → cleaner Claude Code reasoning + safe parallel work. **TIMING: post-TestFlight** (don't
clean load-bearing files right before submission).

---

## 4. ANIMATION TRACK (Joshua — separate animation chat; hand-off doc owns it)

**Pointer:** the animation hand-off doc — 5 items: (1) arrival **incoming build-up** (plane fly-in →
parachute → open; relates to #12 Plane-v1-v2); (2) **full send+receipt for BOTH roles** (+ receiver
replay); (3) **randomize showcase variety**; (4) compose-back-receipt FYI (the 2c observation); (5)
**showcase → webpage marketing GIFs** + the edge-glimpses / curiosity-gap design + the prior webpage
transcript. **Owned by the animation chat**, not this build track. → TRUTH (animation-track items).

---

## 5. WEB / MARKETING (mostly animation-track + Phase 3)

- **Show-the-message web page** — EXISTS + deployed (live at pointward.app, `get_message` RPC). → TRUTH §Build-12 WEB PAGE.
- The **GIF-enriched / edge-glimpse marketing version** is animation-track (hand-off item 5).
- The **rich animated-in-browser** version stays **Phase 3**.

---

## 6. DEFERRED TESTING

- **Real 2-phone send/receive round-trip** (needs a second phone) — the big one.
- Fresh-arriver bypass in a truly not-onboarded state (verified-in-code at Shot 2 Step 1; eyeball on device).
- Unread-badge visual clear.
- The **2c device-repro** (bucket 1).
- **TestFlight beta** — gates real-world testing, precedes the cleanup pass + submission.

---

## 7. PHASE 3 (fresh chat — large, leave for later)

Rich web preview (animated-in-browser) · interactive animations (ball/glove catch) · Special Moments
(Valentine's / Graduation / …) · server-side moderation · deferred deep linking (only if users
complain) · identity hardening (duplicate `users` rows) · message expiry / ~30-day lifespan.
→ TRUTH §Phase-2/Phase-3 deferred notes.

---

## ROUTE TO LAUNCH (suggested sequence)

**Small pre-launch items (as desired)** → **TestFlight beta** (real-world + the 2-phone test) →
**post-TestFlight cleanup pass** (the ranked structural plan, bucket 3) → **App Store submission**
(toolchain already met). **Nothing in buckets 1–2 is gating** — the real gates are **TestFlight
validation** + the **cleanup pass**.
