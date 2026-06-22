# Tester Unlock — Design Spec (NOT an implementation)

> ⚠️ **SUPERSEDED FOR V1 (2026-06-22).** The v1 monetization decision is to **ship FULLY OPEN — no
> paywall, all animations/instruments free** (a small "unlock everything for v1" app change replaces
> the live paywall gating). With everything open, **internal testers can exercise all animations with
> NO special unlock**, so this tester-unlock is **NOT the near-term path.** This spec is **retained**
> (unchanged below) **in case a paywall is later reintroduced** (only if the app gains traction). See
> POINTWARD_TRUTH → **LAUNCH / MONETIZATION STRATEGY — v1 = FULLY OPEN**.

_Design only. DOC ONLY — no code. Grounded in the live gating code (file:line). (Was: prerequisite for
`reports/test_plan.md` PASS 3 — no longer needed for v1; see the banner above.)_

---

## The problem
The paywall (`PaywallView`) is **LIVE in Release/TestFlight** and gates premium instruments at point
of use — **correct for real users.** But that same gating **blocks John + wife (internal testers)
from exercising the premium animations** in a Release build.

The old "off for testing" was a **`#if DEBUG` bypass**: `HomeLinkApp.swift:18-24` registers
`UserDefaults` defaults `subscriptionTier = "unlocked"` (= `SubscriptionTier.pro`) and
`proFeaturesEnabled = true` — but it's wrapped in `#if DEBUG`, which is **stripped from
Release/TestFlight builds.** So in TestFlight, testers fall back to `.free` and hit the paywall.

## How gating actually works (grounded)
- **The unlock state is just two UserDefaults values:** `subscriptionTier` (`"unlocked"` ⇒ `.pro`,
  `SubscriptionTier.swift:11`) and `proFeaturesEnabled` (`ProFeatures.storageKey`). Premium is on when
  **tier == `.pro` AND `ProFeatures.isOn`** (`SubscriptionManager.swift:28-31`).
- **Many surfaces read `subscriptionTier` directly** — `SkinStore`, `InstrumentStore`, `SenderStyle`,
  `SoundEngine`, `HapticEngine` — so flipping the tier flips everything consistently.
- **Real unlock today = StoreKit:** `SubscriptionManager.purchase()` / `checkEntitlements()` set
  `tier = .pro` (`SubscriptionManager.swift:98, 130`). A tester unlock should reuse this same
  end-state (set `.pro` + `ProFeatures.set(true)`) — **without faking a StoreKit purchase.**

## Requirement
A mechanism that **unlocks premium content for SPECIFIC testers in a RELEASE build**, while **real
users still see the paywall**. It must:
- **NOT** be a `#if DEBUG` flag (stripped in Release — the exact thing that broke).
- **NOT** unlock for everyone.
- Be **revocable** and **not leak** to real users.

---

## Options (trade-offs)

### Option 1 — Allow-list of tester user IDs (app- or server-side)
On launch, if the signed-in user's id / `apple_user_id` is in a known tester list → apply the unlock.
- **Real users stay gated:** their id isn't in the list → no unlock.
- **Set for testers:** add the tester's stable id to the list.
- **Leak risk:** LOW-ish. If the list is **hardcoded in the app**, it ships in the binary
  (reverse-engineerable) — but it only unlocks the *listed* ids, so a stranger can't self-unlock by
  reading it. If **server-side**, no exposure.
- **Build / maintain:** MEDIUM. Needs each tester's stable id; a **hardcoded list requires a new
  build** to add/remove a tester (annoying). Server-side list avoids the rebuild but is basically
  Option 3 with extra steps.

### Option 2 — Hidden settings toggle behind a non-obvious gesture/code
A secret gesture / code in Settings sets the unlock flag locally.
- **Real users stay gated:** only if they never discover the gesture.
- **Set for testers:** the tester performs the gesture once.
- **Leak risk:** **HIGHEST.** A secret gesture is a **shareable bypass** — once known (or guessed,
  or posted), **anyone defeats the paywall for free** = direct revenue leak. No per-user control; no
  revocation.
- **Build / maintain:** LOW to build, but the risk makes it unacceptable for a shipping paywall.

### Option 3 — Server flag `is_tester` on the user record ✅ recommended
A boolean column on `public.users`; the app reads it on launch and, if true, applies the unlock.
- **Real users stay gated:** `is_tester` defaults **false** → no unlock; the flag is **server-only**,
  not in the binary, can't be guessed or shared.
- **Set for testers:** flip the boolean in Supabase for the tester's row — **no rebuild**, instant,
  **revocable** (flip it back).
- **Leak risk:** **LOWEST.** Per-user, server-controlled, invisible to clients other than its owner.
- **Build / maintain:** MEDIUM to build (one column + one read + apply); **trivial to maintain**
  (toggle a DB boolean per tester). The app already fetches the user row on sign-in
  (`ensureUser`/`checkEntitlements`), so there's a natural place to read it.

| | Real users gated | Set for testers | Leak risk | Build / maintain |
|---|---|---|---|---|
| 1 allow-list | yes (not listed) | add id to list | low (server) / low-but-shipped (hardcoded) | medium; hardcoded needs a rebuild |
| 2 secret gesture | only if undiscovered | do the gesture | **HIGH (shareable)** | low build / unacceptable risk |
| 3 server `is_tester` | yes (default false) | flip a DB boolean | **LOW** | medium build / trivial maintain |

---

## Recommendation
**Option 3 — a server `is_tester` flag.** It's the only option that is per-user, revocable without a
rebuild, can't leak into the binary, and keeps real users gated by default. (Option 1 server-side is
effectively a list-shaped version of the same thing; Option 2 is out — a shareable bypass against a
live paywall.)

### Minimal build outline (audit-first; implement later)
1. **AUDIT FIRST** — confirm the single place the app applies an unlock (the `.pro` end-state in
   `SubscriptionManager`), and confirm `checkEntitlements()` (real StoreKit restore) and a tester
   unlock won't fight: the tester unlock should **re-apply on every launch** so a StoreKit "not
   entitled" pass can't strip a tester, and a **real** purchase still works for everyone else.
2. **Schema (one migration):** `alter table public.users add column if not exists is_tester boolean
   not null default false;` (default false = real users untouched; RLS unchanged — the user reads
   their own row).
3. **App read:** where the app already loads the user (post-`ensureUser` / in the
   `SubscriptionManager` entitlement flow), read `is_tester`. If true → apply the **same end-state as
   a successful purchase** (`tier = .pro` + `ProFeatures.set(true)`) — **not** a faked transaction,
   and **not** `#if DEBUG`.
4. **Precedence + revocation:** `is_tester == true` always unlocks on launch; if it's later flipped
   **false**, the next launch should fall back to the real StoreKit entitlement (so revocation works).
   Make sure a tester unlock never writes a permanent "purchased" record that survives revocation.
5. **Verify:** a tester device (flag on) shows premium unlocked in a Release build; a non-tester
   Release device still hits the paywall; flipping the flag off re-gates on next launch.

**Effort:** small-to-medium, low-risk (additive column + one read + reuse of the existing `.pro`
apply path). No paywall logic for real users changes.

---

## Prerequisite note
This unlock is the **prerequisite for `reports/test_plan.md` PASS 3** (the internal premium-feature
pass). Until it ships, exercise premium animations on a **Debug (Xcode)** build (paywall bypassed
there) or wait for the tester-unlock build.
