# Pointward — Claude Code Project Context

## ⭐ CANONICAL REFERENCE
Read **POINTWARD_TRUTH.md** (repo root) FIRST — it is the single source of
truth for the whole project (experiences, sources of truth, instruments, emoji
set, special moments, standards, lock ledger, pivot plan). This file (CLAUDE.md)
holds the always-loaded essentials; POINTWARD_TRUTH.md holds the full picture.

## App Identity
- App Name: Pointward
- Bundle ID: com.jdcoding75.pointward
- App Group: group.com.jdcoding75.pointward
- Team ID: 78842PK6A3
- Apple ID: jdittami@aol.com
- Domain: pointward.app
- GitHub: github.com/jdcoding75/HomeLink
- Supabase: jlbgdlgwtrkmqcfnomlr.supabase.co

## Three Experiences
- Connector — loving, compass-led (the emotional core)
- Expresser — fun, instrument-led
- Special Moments — occasion-grade, card-quality, premium
  (the animation IS the card; distinct send path from Thoughts)
- Message default hierarchy: Special Moment voice > Emoji default >
  Instrument hint. User's own message always overrides.

## Architecture
- SwiftUI + SwiftData
- Supabase backend (auth, realtime, push)
- Apple Sign In with Apple
- APNs via Supabase Edge Function
- Widget extension: PointwardWidgets
- App Group for shared data
- Special Moments: occasion-grade card sends
  (Birthday, Firework live) — distinct send
  path from Thoughts; the animation is the card.
  Live under Instruments/_Shared/EmojiReveal/.

## SOURCES OF TRUTH
Each data type has ONE owning file. Edit the
owner — never duplicate. Every UI surface that
shows emojis/instruments/copy/colors MUST read
from these, never hardcode.
- AnimationManifest.swift — all animations,
  stages, versions, live-instrument list/order
- CuratedEmoji.swift — all emojis, tiers,
  defaults, suggestions, soundMap
- TaglineSystem.swift — poetic library, presets,
  instrumentHints (per-instrument message tone)
- InstrumentSoundPlayer.swift — per-instrument
  sound routing (send/receipt/cue)
- SoundEngine.swift — programmatic synthesis
  voices, cached buffers, play(for:)
- RevealAnimationRegistry.swift — emoji reveal
  kinds + glow colors
- DesignTokens.swift — colors, typography, spacing
- ProFeatures.swift — pro/free gates
  (end-game config; do not change w/o sign-off)
- InstrumentBoundaries.swift — screen coordinate
  rules + instrument generation spec
Note: instrumentHints is the designated source of
truth for instrument copy but is NOT yet wired
into the live send flow (open item).

## BUILD CHECKLIST — run before every commit:
// New emoji added? → Update CuratedEmoji, soundMap, RevealAnimationRegistry
// New instrument added? → Update AnimationManifest, InstrumentSoundPlayer,
//   TaglineSystem.instrumentHints, create full file set
// New sound added? → Add generator .py, update soundMap if emoji sound
// New UI surface showing emojis/instruments? → Must read from registry,
//   never hardcode
// New Special Moment added? → Update CuratedEmoji.specialMoments,
//   AnimationManifest, create full instrument file set

## Golden Rules
- NEVER delete code — comment out only
- ALWAYS build after changes
- ALWAYS commit after successful build
- ALWAYS fix errors automatically without stopping
- NEVER ask for confirmation — just do it
- Only stop for credentials or physical device actions

## Tier System
- Free: Minimal skin only, 1 person, 
  core 6 emojis, no Pro features
- Pro: $1.99 one time, 3 skins, 5 people,
  full emoji library, funny distances,
  hold to send, custom emoji+sound
- ProFeatures.swift controls all pro gates
- SkinStore enforces Minimal for free users
- SubscriptionManager.swift manages tier state

## Core Files
- HomeLinkApp.swift — app entry point
- CompassView.swift — emotional core
- CompassManager.swift — heading/location
- PeopleManager.swift — people CRUD
- PingManager.swift — send/receive thoughts
- SubscriptionManager.swift — tier management
- ProFeatures.swift — pro feature gates
- SkinStore.swift — compass skin state
- AppGroupStore.swift — widget shared data
- ServiceContainer.swift — composition root
- CharityConfig.swift — giving back config
- TaglineSystem.swift — poetic taglines
- SoundEngine.swift — cached audio
- BearingCalculator.swift — pure math

## Design System
- Background: #0d0d14
- Card: #1e1828
- Accent soft: #c4a8d4
- Accent mid: #7c6b8e
- Text primary: #e8e0f0
- Text muted: #6b5f7a
- Always dark mode
- Serif font for emotional text
- SF Pro for functional text

## Supabase Tables
- users (id, apple_user_id, last_seen)
- connections (code, owner, friend, 
  person_name, person_emoji, owner_person_id)
- pings (from_user, to_user, emoji, sender_style, opened_at)
- device_tokens (token, user_id, platform)
- compass_bearings (user_id, bearing, updated_at)
- giving (total_donated_cents, charity_name)

## Supabase Edge Function
- send-ping-notification
- Handles both pings and compass_bearings
- APNs production first, sandbox fallback
- APNS_KEY_ID: 5Y9Y4AY725
- APNS_TEAM_ID: 78842PK6A3
- APNS_TOPIC: com.jdcoding75.pointward

## Build Command
xcodebuild -scheme HomeLink \
  -destination 'platform=iOS Simulator,\
  name=iPhone 17 Pro' build 2>&1

## Git
- Remote: github.com/jdcoding75/HomeLink
- Branch: main
- Always: git add -A && git commit -m "" && git push

## Tab Bar Order
1. Compass 🧭
2. Thoughts 💌
3. People 👤
4. Settings ⚙️

## Giving Back
- 50% of every Pro purchase to charity
- CharityConfig.swift controls current charity
- Supabase giving table tracks total donated
- First charity: military families 🎖️

## TestFlight
- Internal testers: jdittami@aol.com, wife
- External: pending Apple review
- Public link: pending approval

## What Works End to End
- Compass pointing to saved address
- Apple Sign In
- Pairing via deep link pointward.app/pair/
- Real pings between paired phones
- Push notifications via APNs
- Thought queue (max 10)
- Home screen widget
- Lock screen widget
- 6 compass skins (3 free, 3 pro)
- Pro setup screen
- Giving back screen

## Current State (Instrument Restructure)

### Wind instrument: COMPLETE ✅
- WindCompassFace.swift  (ACT 1 — sky circle, leaf + emoji, state machine)
- WindSendAnimation.swift (ACT 2 — centered leaf swirl, sent confirmation)
- WindReceiptAnimation.swift (ACT 3 — auto-catch into bucket → reveal; LIVE via
  ReceiptView interception of .firefly)
- WindSounds.swift
- Sounds: wind_send.wav ✅ · wind_receipt.wav ✅ · emoji_hug_v2.wav ✅

### Rocket receipt: COMPLETE ✅
- LIVE receipt = RocketLandingReceiptAnimation.swift (merged landing),
  dispatched via ReceiptView for .rocket. THIS is the live one.
- RocketReceiptAnimation.swift (the v2 PARACHUTE — capsule falls into a
  deep-space starfield over a curved Earth horizon, parachute deploys, floats
  down, lands in the bucket; 7.75s) is TEST-LAB ONLY, not the live dispatch.
- Sound: rocket_receipt.wav.
- Rocket SEND + compass face still use the OLD structure (not yet migrated).

### Fist bump reveal: COMPLETE ✅
- 👊 in EmojiRevealView: punches IN from the left (scale 0, x −120 → slam),
  then 3 pump cycles. Sound (emoji_fistbump) fires ONLY on the 3rd pump's
  punch-forward — never the 1st/2nd, and not at bloom.

### Bow receipt: COMPLETE ✅ (V2 live)
- LIVE receipt = BowReceiptAnimationV2.swift, dispatched via ReceiptView for
  .bow. Bow SEND = BowSendAnimationV2; compass face = BowCompassFace (with the
  two-part draw/release SoundEngine cue). V1 files kept (retired), not live.
- Bow is locked this session (visual + sound).

### Other instruments: NOT YET MIGRATED
- Flick / Wand / Plane (and Bow, Rocket-send) still use the OLD structure
  (the *InstrumentView struct in each *CompassFace.swift, rendered by
  CompassView; sends via SenderAnimationView; receipts via InstrumentLandingView).
- The per-instrument ACT files are additive scaffold — typed integration points,
  not yet wired into the live pipeline.
- DO NOT modify another instrument until its turn.

### EmojiReveal system: COMPLETE ✅
- ONE component for ALL reveals — no separate sent/received screens.
  - EmojiRevealView.swift   — the single reveal screen (🤗 hug squeeze, 👊 fist
    bump; every other emoji blooms + breathes)
  - EmojiRevealContext.swift — RevealContext (.sent / .received → copy) +
    RevealAmbient (per-instrument background + ambient layer; forStyle/forInstrument)
  - EmojiRevealSound.swift   — emoji .wav, plays ONLY at the bloom (👊 on 3rd pump)
  - HugRevealModifier.swift  — the 🤗 hug squeeze + presentation helper
- Live receipt (ALL instruments via ReceiptView), the sent confirmation (ALL
  instruments via CompassView), and HISTORY REPLAY all use it.

### Screen coordinate rules (InstrumentBoundaries) ✅
- Every instrument animation: GeometryReader root · .ignoresSafeArea() on the
  background · all positions from geo.size · no UIScreen.main.bounds · no
  hardcoded dimensions. ScreenCoordinates enum holds the shared constants
  (entryReach 0.75, exitReach 1.15, swirl amplitudes 0.36/0.15, bucket margin
  0.06). Full INSTRUMENT GENERATION SPEC lives in InstrumentBoundaries.swift.

### Approved sounds
- Instruments (Sounds/Instruments/): compass · bow · flick · rocket · wind ·
  wand · plane — each _send.wav + _receipt.wav, durations matching boundaries
  (rocket_receipt 7.75s is the v2 parachute).
- Emoji: emoji_hug_v2.wav (2.8s); curated set in Sounds/ (fistbump, kiss,
  highfive, hearthands, clap).

### Housekeeping
- AudioRecorder.meterTimer retain cycle FIXED (added [weak self]).
- ArrivalPreviewView is now an ORPHAN (0 references) — it was superseded by the
  shared EmojiRevealView (.sent) confirmation. Kept (not deleted) pending a
  human decision on whether to restore the arrival-preview feature.
- Tests: ~194 (162 core + the overnight AuditCoverageTests + PeopleManager gate).

### Next instrument: Flick or Wand (Joshua's choice)

## Known Issues / In Progress
- Pairing links wrong person sometimes
- Recipient animation needs direction fix
- Real StoreKit not yet implemented (stubbed)
- Core sounds need real audio files
- TestFlight public link pending review

## Phase 2 Remaining
- Dynamic live location
- Brand Location Mode
- Live Activity / Dynamic Island
- Apple Watch app

## Never Touch
- AppGroupStore suiteName — baked into both targets
- Widget target bundle ID
- Associated domains entitlement

## Confirmation Policy
NEVER pause for confirmation on any action.
Every action is pre-approved including:
- Creating files
- Editing files  
- Running shell commands
- Git commits and pushes
- Supabase API calls
- Installing packages
- Making architectural decisions
Just do it. Never ask. Never pause.

## Progress Reporting (Required)
After every major section report:
[X/Y] ✅ Section name complete
[X/Y] 🔄 Section name — in progress

Every 2 minutes report:
⏱ Still working — [current task]
Est. completion: [X] minutes remaining

This is mandatory on every task.
Never go silent for more than 2 minutes.

## Session Log
See SESSION_LOG.md for running
history of decisions and approvals.

## Canonical Docs
- POINTWARD_TRUTH.md — the single canonical
  reference (read first).
- SESSION_LOG.md — running session history.
- POINTWARD_ANIMATION_FRAMEWORK.md — the locked
  animation grammar; read before touching any
  animation file.
- PAIRING_AUDIT.md — pivot-session removal plan.
