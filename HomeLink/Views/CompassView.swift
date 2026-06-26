// CompassView.swift
// Pointward › Views
//
// The emotional core of the app. Every system converges here:
//   - Skin system (NeedleView dispatches to the active skin's ring/face renderer)
//   - Emoji Presence System (center emoji, glow, scale-up on lock)
//   - Compass Lock Moment (±5° haptic + glow + lock badge)
//   - Breathing Ring (always-on ambient animation)
//   - Ping Overlay (emoji burst + ring pulse on ping receipt)
//   - Return Home Glow (warm background when > 500 km away)
//   - Tagline (per-person or skin default, fades in on person change)
//   - Quiet Mode (read from environment, slows all animations + dims glows)
//
// Rule from spec: the compass is always visible. This view is never pushed
// off-screen — other screens are sheets or overlays on top of it.

import SwiftUI
import CoreLocation
import Combine
import os

struct CompassView: View {

    static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "compass")

    @EnvironmentObject var compass:  CompassManager
    @EnvironmentObject var people:   PeopleManager
    @EnvironmentObject var pings:    PingManager
    @EnvironmentObject var skinStore: SkinStore
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var instrumentStore: InstrumentStore
    @EnvironmentObject var appEnv:   AppEnvironment
    @EnvironmentObject var appState: AppStateManager

    // @AppStorage("quietMode") private var quietMode = false   // retired
    private let quietMode = false

    // Lock moment — fires once per lock edge, resets when unlocked
    @State private var lockGlowActive = false
    @State private var emojiScaled    = false
    @State private var lockBadgeShown = false
    // [hands-free] Aim → hold → AUTO-FIRE (no tap). After a fire DISARM; re-arm only after the phone swings
    // AWAY past compassReArmThreshold (~30°), then re-aims → fires ONCE per aim, no rapid-fire. This is viable
    // now because the holdTick timer is FIXED (e47912e: it was a recreated `private let` publisher that never
    // ticked on device — the real root cause behind both "never locks when held" AND the set-down false-fire).
    // Starts DISARMED so opening the app (or setting the phone down) while ALREADY aligned can't auto-fire —
    // a fire requires a deliberate turn-away-past-30°-then-re-aim. Normal first use re-arms instantly (you start
    // pointed away from the person and turn ONTO them).
    @State private var compassArmed = false
    // [compass-grace] Set when the compass becomes active (app open / screen appear / person change). The
    // holdTick suppresses ALL firing for `compassGrace` seconds after it, so the startup heading settle
    // (currentHeading 0 → actual sweeps past 30° then aligns) can't auto-send on open. Device-tunable.
    @State private var compassReadyAt = Date.distantPast
    private let compassGrace: TimeInterval = 1.5   // covers the heading settle; short enough not to block a deliberate aim. Device-tunable.
    // [hands-free] Tap-to-send retired (auto-fire on hold). Preserved as a one-line fallback:
    // @State private var compassAwaitingTap = false
    // @State private var isPressingCompass = false        // [compass-touch] finger/touch gate (removed)

    // Ping animation
    @State private var pingRingActive  = false
    @State private var badgePulse      = false

    // Empty state
    @State private var showAddPerson = false
    // [5/6] The demo-person "replace with someone real" hint — shown once,
    // then dismissed forever (tapped or once a real person is added).
    @AppStorage("demoHintDismissed") private var demoHintDismissed = false

    // Tagline animation trigger
    @State private var taglineKey: UUID = UUID()

    // Layered distance system — random per launch, lockable in Settings
    @AppStorage("funnyUnitLocked")      private var funnyUnitLocked      = -1
    @AppStorage("thoughtTaglineLocked") private var thoughtTaglineLocked = -1
    @AppStorage("showLightSpeed")       private var showLightSpeed       = true
    @State private var funnyIndex   = Int.random(in: 0..<DistanceFun.funnyCount)
    @AppStorage(ProFeatures.storageKey) private var proOn = false

    // Tagline: shuffled walk through the library — never repeats until
    // the whole library has been seen, then reshuffles
    @State private var taglineOrder: [Int] = TaglineSystem.poeticLibrary.indices.shuffled()
    @State private var taglinePosition = 0
    private var taglineIndex: Int { taglineOrder[taglinePosition] }

    // [1/4][4/4] PER-PERSON tagline shown on the compass — mirrors the
    // selected person's tagline so the UI updates instantly on tap/pick;
    // nil means "no tagline" (none travels with their thoughts).
    @State private var personTagline: String? = nil
    @State private var showTaglinePicker = false

    // [copy-declutter] discovery hint retired (vestigial — predates the bottom picker UI)
    // Discovery hint — "tap the words to change them", first three launches
    // @AppStorage("discoveryHintCount") private var discoveryHintCount = 0
    // @State private var showDiscoveryHint = false

    // Person switcher sheet (tap the name)
    @State private var showPersonSwitcher = false

    // [9b · B4] presenceGlowVisible removed with the mutual-pointing edge-glow.

    // [1/6] Thought history — lives on the compass now. Bottom-left icon opens
    // a drawer of recent thoughts; tapping one replays it on the compass while
    // it points toward that person.
    @State private var showThoughtsDrawer = false
    @State private var compassThoughts: [SupabaseService.PingRecord] = []
    @State private var thoughtsLoaded = false
    @State private var thoughtsIconPulse = false
    @State private var replayCaption: String? = nil   // "from X · 2h ago"
    @State private var pendingReplayCaption: String? = nil
    private var hasThoughts: Bool { !compassThoughts.isEmpty }

    // Needle emotional state — steady lock breathes warmer
    @State private var steadyLock = false
    @State private var breathePulse = false

    // Shareable compass moment
    // [copy-declutter ITEM 7] Share-card affordance disabled for v1 (preserved).
    // @State private var showShareMoment = false
    // @State private var shareCard: Image? = nil

    // Bottom-zone distance line: 0 standard · 1 funny (Pro) · 2 light speed
    @State private var distanceMode = 0

    // Face interactions — tap pulse + brief bearing readout, long-press skins
    @State private var faceTapPulse = false
    @State private var bearingFlash = false
    @State private var showSkinOverlay = false
    @State private var showSkinPaywall = false
    @State private var showConnectSheet = false
    @State private var showOnboardForSend = false   // [§C PART 2] not-signed-in real send → route to onboarding
    // @State private var showScopeReticle = false   // [4/6] scope retired

    /// The three alignment layers wake whenever aiming or catching.
    private var alignmentActive: Bool {
        (selectedToken != nil || pings.nowPlaying != nil) && compass.isHeadingAvailable
    }
    // (subscription env object already declared at the top)

    // ── Send a thought — merged onto the compass (thoughts tab retired) ──
    @ObservedObject private var customStore = CustomThoughtStore.shared
    @AppStorage("holdToSendEnabled") private var holdToSendEnabled = false
    @State private var personalSixRow: [String] = PersonalSet.load()
    @State private var selectedToken: String? = nil
    @State private var messageText: String = ""             // [5/5] optional note (≤30)
    @FocusState private var messageFocused: Bool
    @State private var composing = false                    // [5/7] message editor open
    @State private var showEmojiPicker = false              // [redesign] [Emoji] box toggles the strip
    // [custom-text lock] True once the user HAND-EDITS the message — while true,
    // the default message no longer follows the emoji/animation (their custom
    // text is preserved across emoji changes). Session/per-send only: @State, so
    // it resets on a fresh launch; an empty field clears it (default may refill).
    @State private var messageEdited = false
    @State private var longPressLabel: String? = nil        // [1/3] curated-emoji label on long-press
    @State private var loadFlightToken: String? = nil       // [1/5] load flight
    @State private var loadFlightProgress: CGFloat = 0
    @State private var flightToken: String? = nil
    // [5/6] Arrival preview — a brief glimpse of the recipient's catch.
    // [arrival-preview removed] `@AppStorage("arrivalPreviewEnabled")` DELETED — its
    // setting is gone and all readers here were already commented out (R2 / be59c38
    // suppressed the sender-side preview). The remaining arrivalPreview* machinery below
    // is inert (commented) and left for a future cleanup pass — not deleted here.
    @AppStorage("arrivalPreviewCount")   private var arrivalPreviewCount   = 0
    @State private var arrivalPreview: ArrivalPreviewData? = nil
    @State private var sentMessage: String? = nil   // [2/3] for the sent confirmation
    @State private var sentTagline: String? = nil
    @State private var sentNotice = false
    // [sent-confirmation] The recipient's name captured at send time, so the post-send
    // toast can read "sent to [Name] ✦" (falls back to "sent ✦" when there's no name).
    @State private var sentToName = ""
    @State private var showKeepPreviewPrompt = false
    // Full-compass sender styles dim the skin to 20 % while they play
    @State private var faceDimmedForInstrument = false
    @State private var faceSendPulse = false           // [4/4] compass send pulse
    @State private var flightFly = false
    @State private var holdProgress: Double = 0
    // [1/3] Bumped by cancelInstrument — folded into the instrument's .id so a
    // cancel REBUILDS the instrument fresh in its idle state, guaranteeing a
    // clean reset for all 7 (fuel/draw/charge/wind counters reset to zero) no
    // matter what mid-send state the instrument was holding internally.
    @State private var instrumentResetID = 0
    private let holdDuration = 1.33   // [6/7] reduced 1/3 (was 2.0) — more responsive
    // [hands-free] After a fire the compass disarms; it re-arms only once the phone swings AWAY past this
    // angle (then a re-aim fires again). 30° sits clearly above the 15° fire window → a deliberate turn-away
    // resets it, an in-aim wobble never does. Device-tunable (John: ~30 is enough).
    private let compassReArmThreshold: Double = 30
    // [compass-timer-fix] Was `private let` — recreated on EVERY re-render, which restarted the 0.05s
    // countdown before it could fire, so the hold loop NEVER ran on device (constant heading re-renders).
    // That's why it never locked when held, AND why it only "fired" when set down (re-renders stopped →
    // timer survived → false-fire). @State persists ONE publisher across re-renders → it ticks reliably.
    @State private var holdTick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var holdToSendActive: Bool {
        holdToSendEnabled && subscription.tier != .free
    }
    private var sendAlignDiff: Double {
        BearingCalculator.alignmentError(relativeBearing: compass.state.bearingDegrees)
    }

    // ── [bottom-band redesign] Default-emoji payload + helper-line copy ──────

    /// The current animation's default feeling (from AnimationManifest, never
    /// hardcoded here). All animations default to 🤗 for now; the `?? "🤗"` is a
    /// pure safety net should the lookup ever miss.
    private var defaultEmojiForCurrentAnimation: String {
        AnimationManifest.instruments
            .first { $0.instrument == instrumentStore.selected }?
            .defaultEmoji ?? "🤗"
    }

    /// The feeling that will actually send. A default ALWAYS supplies a payload,
    /// so the send is never gated on an explicit emoji choice. Used at every
    /// send site and in the preview line.
    private var effectiveToken: String { selectedToken ?? defaultEmojiForCurrentAnimation }

    /// Aim instruments need the phone pointed; the magic ones (wind · wand)
    /// charge inside the instrument, so they show no aim hint. Mirrors the
    /// non-aim split used by `instrumentStep`.
    private var isAimInstrument: Bool {
        // [plane aim fix] ONLY the compass aims by PHYSICALLY TURNING THE PHONE,
        // so it is the only instrument that shows the live directional aim hint.
        // Canonical source: Instrument.alignsByPhoneRotation (true only for
        // compass). On-screen aimers (bow · rocket · flick) and the no-aim
        // instruments (wind · wand · plane) get the mechanism hint only — no
        // directional/aim hint. This fixes the regression where plane showed an
        // aim hint, contradicting the locked "Plane: no aiming" spec.
        instrumentStore.selected.alignsByPhoneRotation
        // PRIOR (bottom-band build) — true for all except wind/wand:
        //   switch instrumentStore.selected {
        //   case .firefly, .wand: return false   // wind · wand — charge inside
        //   default:              return true
        //   }
    }

    /// The gesture TAIL only (no "choose emoji · message ·" prefix) — the
    /// mechanism recipe helper line. Birthday/Firework are emoji sub-modes of
    /// the compass instrument; their mechanic lives on the face, so their
    /// recipe is the face's own instruction (BirthdayCakeCompassFaceV2 /
    /// FireworkCompassFace), not a compass "point · hold".
    private var mechanismRecipe: String {
        if instrumentStore.selected == .compass {
            switch sendRemoteEmoji(for: effectiveToken) {
            case "🎂": return "tap each candle to light it"
            case "🎆": return "drag the match up to the fuse"
            default:  break
            }
        }
        return universalInstruction   // now the stripped gesture tail
    }

    /// [2/5] Best-effort current step for the progress dots. Load is done once
    /// a thought is selected; aim-based instruments advance toward their final
    /// action as the phone lines up; the magic instruments (wind · wand) sit
    /// on their action step since their charge lives inside the instrument.
    private var instrumentStep: Int {
        // [4/6] Step 0 = choose emoji. Step 1 = message (auto-filled the moment
        // an emoji is chosen, so it completes immediately and the flow advances
        // to orient/aim at step 2). Skipping the message is automatic.
        guard selectedToken != nil else { return 0 }   // still choosing the emoji
        let inst = instrumentStore.selected
        let total = StepProgressView.stepNames(for: inst).count
        switch inst {
        case .firefly, .wand:
            return 2                                    // breathe / shake — first action step
        default:
            // [compass-window 15→10] match the fire gate (:1221). PRIOR: sendAlignDiff <= 15
            let aimed = compass.isHeadingAvailable ? sendAlignDiff <= 10 : true
            return aimed ? total - 1 : 2                // orient → final send action
        }
    }

    /// [1/5] + [5/5] A per-instrument confirmation as the thought loads in.
    private func loadHaptic() {
        switch instrumentStore.selected {
        case .flick: HapticEngine.flickLoad()
        default:     HapticEngine.personSelected()
        }
    }

    private func triggerLoadFlight(_ token: String) {
        loadFlightToken = token
        loadFlightProgress = 0
        loadHaptic()
        withAnimation(.easeOut(duration: 0.4)) { loadFlightProgress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            loadFlightToken = nil
            faceSendPulse = true                        // soft pulse when loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { faceSendPulse = false }
        }
    }

    // The compass content (the ZStack of zones + instrument). Split out of
    // `body` so the long modifier chain below stays within the SwiftUI
    // type-checker's per-expression budget.
    private var compassRoot: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────────
            // Phase 1: steady deep purple — the far-from-home colour shift is
            // gone, only the text label remains.
            DesignTokens.Color.background
                .ignoresSafeArea()
                // [mechanism-reset PART 3] Tap OUTSIDE the compass circle = universal cancel.
                // Reaches the existing cancelInstrument() (self-guards selectedToken != nil →
                // no-op/no haptic when nothing is armed). Anything reaching this back layer is
                // outside the face circle and off all controls; the compose scrim (on top) still
                // owns outside-taps while composing, and the face's own tap owns inside-circle.
                .contentShape(Rectangle())
                .onTapGesture { cancelInstrument() }

            if people.people.isEmpty {
                // ── Warm empty state — no one to point toward yet ────────────
                emptyState
            } else {
                VStack(spacing: 0) {
                    // ── TOP ZONE: name, then distance right under it ──────────
                    nameHeader
                        .padding(.top, 16)

                    // [build7] Seeded contacts (no real location) have no real
                    // distance — hide the number entirely (rawBearingToTarget == nil
                    // is the seeded signal). Keeps the bogus null-island km / funny /
                    // light-speed lines off the compass; the seeded DIRECTION stays.
                    if compass.rawBearingToTarget != nil {
                        distanceLine
                            .padding(.top, 6)
                        // [§B3] degree readout MOVED to instrumentHelperLines (replaces the old "is to your
                        // {direction}" aim line) — no longer here in the top zone.
                    }

                    Spacer(minLength: 12)

                    // ── MIDDLE ZONE: the compass, dominant, nothing on it ─────
                    // Skins render at a fixed 240pt design size; scale the whole
                    // composition so every face grows together.
                    // ── FOUR INSTRUMENTS: only the middle changes ─────────
                    Group {
                        switch instrumentStore.selected {
                        case .compass:
                            // [special moments — TRANSITION FALLBACK, retire in Stage 4]
                            // Legacy path: picking 🎂/🎆 from the emoji strip while on
                            // the compass still swaps to the birthday/firework face.
                            // The first-class entry is now `case .birthday/.firework`
                            // below (selection-keyed). Kept so a legacy emoji pick keeps
                            // working during the transition.
                            if (selectedToken.map { sendRemoteEmoji(for: $0) }) == "🎂" {
                                // [birthday V2] HERO — tap each candle to LIGHT it.
                                // (V1 BirthdayCakeCompassFace kept as fallback.)
                                BirthdayCakeCompassFaceV2(
                                    bearingDegrees: compass.state.bearingDegrees,
                                    personName: compass.state.personName,
                                    onSend: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                                )
                                .frame(width: 240, height: 240)
                                .scaleEffect(370.0 / 240.0)
                                .frame(width: 370, height: 370)
                            } else if (selectedToken.map { sendRemoteEmoji(for: $0) }) == "🎆" {
                                // [firework] 🎆 — drag the lit match to the fuse;
                                // the fuse burns down, then the send fires.
                                FireworkCompassFace(
                                    bearingDegrees: compass.state.bearingDegrees,
                                    personName: compass.state.personName,
                                    onSend: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                                )
                                .frame(width: 240, height: 240)
                                .scaleEffect(370.0 / 240.0)
                                .frame(width: 370, height: 370)
                            } else {
                                compassFace
                                    .frame(width: 240, height: 240)
                                    .scaleEffect(370.0 / 240.0)
                                    .frame(width: 370, height: 370)
                                    // [4/4] SEND — the face pulses once on launch
                                    .scaleEffect(faceSendPulse ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 0.18), value: faceSendPulse)
                                    // Where they are — marker · arc · hint
                                    .overlay(
                                        DirectionIndicator(
                                            bearingDegrees: compass.state.bearingDegrees,
                                            personName: compass.state.personName,
                                            personEmoji: compass.state.personEmoji,
                                            ringRadius: 180,
                                            distanceText: compass.state.formattedDistance   // [3/5]
                                        )
                                    )
                                    // Full-compass send styles dim the skin
                                    .opacity(faceDimmedForInstrument ? 0.2 : 1.0)
                                    .animation(faceDimmedForInstrument
                                               ? .easeOut(duration: 0.3)
                                               : .easeIn(duration: 0.4),
                                               value: faceDimmedForInstrument)
                            }
                        // [special moments — peer animations] SELECTION-keyed faces:
                        // selecting Birthday/Firework brings its face directly (the
                        // animation is the entry point, not the emoji). The 🎂/🎆
                        // emoji-check inside `case .compass` above is KEPT as a
                        // transition fallback (legacy emoji pick) — retire in Stage 4.
                        case .birthday:
                            BirthdayCakeCompassFaceV2(
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                onSend: { sendThought(effectiveToken) }
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(370.0 / 240.0)
                            .frame(width: 370, height: 370)
                        case .firework:
                            FireworkCompassFace(
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                onSend: { sendThought(effectiveToken) }
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(370.0 / 240.0)
                            .frame(width: 370, height: 370)
                        case .bow:
                            BowInstrumentView(
                                // [default-payload] was `selectedToken` / `selectedToken.map{…}`
                                // — now the defaulted `effectiveToken`, so the face GATE engages
                                // and the DISPLAYED glyph is the default with no manual emoji
                                // (display + payload agree; send already uses effectiveToken).
                                loadedToken: effectiveToken,
                                loadedSymbol: AnyView(sendSymbol(effectiveToken, size: 26)),
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onSend: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                            )
                        case .firefly:
                            // 🌬️ WIND — replaced the firefly (same mechanic as
                            // compass made it redundant; view kept in the repo)
                            WindInstrumentView(
                                // [default-payload] was `selectedToken` — now defaulted effectiveToken
                                // (the wind face starts breath on appear for this non-nil value).
                                loadedToken: effectiveToken,
                                loadedSymbol: AnyView(sendSymbol(effectiveToken, size: 26)),
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onSend: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                            )
                            // FireflyInstrumentView(
                            //     loadedToken: selectedToken,
                            //     loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                            //     bearingDegrees: compass.state.bearingDegrees,
                            //     personName: compass.state.personName,
                            //     onSend: { if let token = selectedToken { sendThought(token) } }
                            // )
                        case .flick:
                            // [live 2026-06-13] FLICK V2 (DESK) is now the live
                            // face — the built FlickDeskCompassFace, no longer the
                            // old post-it FlickInstrumentView. autoPlay:false makes
                            // it the interactive live face (tap to flick → send,
                            // then it re-arms). Old face commented out (never delete).
                            FlickDeskCompassFace(
                                personName: compass.state.personName,
                                // [default-payload] was `selectedToken.map{…} ?? "💜"` — the audit's
                                // display/payload MISMATCH (showed 💜, sent 🤗). Now the face shows
                                // exactly what sends: the defaulted effectiveToken glyph.
                                emoji: sendRemoteEmoji(for: effectiveToken),
                                bearingDegrees: compass.state.bearingDegrees,
                                onSend: { sendThought(effectiveToken) },   // [redesign] default supplies a payload
                                autoPlay: false
                            )
                            // FlickInstrumentView(
                            //     loadedToken: selectedToken,
                            //     loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                            //     loadedEmoji: selectedToken.map { sendRemoteEmoji(for: $0) },
                            //     bearingDegrees: compass.state.bearingDegrees,
                            //     personName: compass.state.personName,
                            //     personEmoji: compass.state.personEmoji,
                            //     onSend: { _ in if let token = selectedToken { sendThought(token) } }
                            // )
                        case .rocket:
                            // 🚀 ROCKET — tap-to-fuel, then blast off. The
                            // mechanic owns emoji loading + alignment, then
                            // calls back to fire the shared send pipeline.
                            RocketInstrumentView(
                                // [default-payload] was `selectedToken` / `selectedToken.map{…}` —
                                // now defaulted effectiveToken (gate engages, glyph = payload).
                                loadedToken: effectiveToken,
                                loadedSymbol: AnyView(sendSymbol(effectiveToken, size: 24)),
                                loadedEmoji: sendRemoteEmoji(for: effectiveToken),
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onLaunch: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                            )
                        case .wand:
                            // 🪄 WAND — load into the crystal, shake to charge,
                            // release at full charge within 15°. Owns its own
                            // mechanic, then fires the shared send pipeline.
                            WandInstrumentView(
                                // [default-payload] was `selectedToken` — now defaulted effectiveToken
                                // (the wand face starts shake on appear for this non-nil value).
                                loadedToken: effectiveToken,
                                loadedSymbol: AnyView(sendSymbol(effectiveToken, size: 22)),
                                loadedEmoji: sendRemoteEmoji(for: effectiveToken),
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onSend: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                            )
                        case .plane:
                            // ✈️ PLANE — wind the propeller (8 winds), let fly.
                            // Owns its winding mechanic, then fires the send pipeline. [3/5]
                            PlaneInstrumentView(
                                // [default-payload] was `selectedToken` / `selectedToken.map{…}` —
                                // now defaulted effectiveToken (gate engages, glyph = payload).
                                loadedToken: effectiveToken,
                                loadedSymbol: AnyView(sendSymbol(effectiveToken, size: 22)),
                                loadedEmoji: sendRemoteEmoji(for: effectiveToken),
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onLaunch: { sendThought(effectiveToken) }   // [redesign] default supplies a payload
                            )
                        }
                    }
                    // [1/3] CANCEL — the X used to live here, as an overlay on
                    // the instrument Group. During an in-progress send some
                    // instruments lay their own gesture surface across this
                    // region and swallowed the tap, so the X "did nothing."
                    // It's now a TOP-LEVEL overlay (see body root, zIndex 30)
                    // that always sits above every instrument and gesture.
                    .id(instrumentIdentity)                    // crossfade on switch · reset on cancel
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: instrumentStore.selected)
                    // [1/6] LAYER 2 — the 8-segment ring scanner, alive
                    // whenever the user is aiming or catching
                    .overlay {
                        if alignmentActive {
                            RingScannerView(relativeBearing: compass.state.bearingDegrees)
                                .frame(width: 388, height: 388)
                                .transition(.opacity)
                        }
                    }
                    // [1/5] LOAD FLIGHT — the chosen emoji arcs up from the row
                    // into the instrument, scaling 0.5 → 1.0 over 400 ms.
                    .overlay {
                        if let token = loadFlightToken {
                            sendSymbol(token, size: 30)
                                .scaleEffect(0.5 + loadFlightProgress * 0.5)
                                .offset(x: CGFloat(sin(Double(loadFlightProgress) * .pi)) * 26,
                                        y: 230 * (1 - loadFlightProgress))
                                .opacity(loadFlightProgress < 0.92 ? 1 : 0)
                                .shadow(color: Color(hex: "#c4a8d4").opacity(0.6), radius: 8)
                                .allowsHitTesting(false)
                        }
                    }
                    // [dots removed] RETIRED — the obsolete per-step completion
                    // dot row (emoji ✓ · message ✓ · aim ✓ …). The 4 picker boxes
                    // now show state directly and the default emoji removes the
                    // "must add emoji" step, so the dots are redundant. Its slot
                    // (just under the instrument) is now the mechanism-recipe line.
                    // Preserved (commented, never deleted); StepProgressView.swift
                    // and `instrumentStep` are left intact for a clean restore.
                    // .overlay(alignment: .bottom) {
                    //     StepProgressView(instrument: instrumentStore.selected,
                    //                      currentStep: instrumentStep)
                    //         .offset(y: 22)
                    //         .opacity(pings.nowPlaying == nil ? 1 : 0)
                    // }
                    // [3/6] The compass hold-to-send progress rings the face
                    .overlay {
                        if instrumentStore.selected == .compass && holdProgress > 0 {
                            Circle()
                                .trim(from: 0, to: holdProgress)
                                .stroke(Color(hex: "#e0ccee"),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 352, height: 352)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Color(hex: "#c4a8d4").opacity(0.6), radius: 8)
                                .allowsHitTesting(false)
                        }
                    }
                    // [4/6] 🎯 scope button + targeting reticle RETIRED — every
                    // instrument now carries the person-initial marker (the
                    // crosshaired circle in DirectionIndicator) instead.
                    // .overlay(alignment: .bottomTrailing) {
                    //     ScopeButton(active: showScopeReticle) {
                    //         HapticEngine.personSelected()
                    //         withAnimation(.easeOut(duration: 0.25)) {
                    //             showScopeReticle.toggle()
                    //         }
                    //     }
                    //     .padding(6)
                    // }
                    // .overlay {
                    //     if showScopeReticle {
                    //         ScopeReticleOverlay(
                    //             relativeBearing: compass.state.bearingDegrees,
                    //             personName: compass.state.personName,
                    //             onDismiss: {
                    //                 withAnimation(.easeOut(duration: 0.25)) {
                    //                     showScopeReticle = false
                    //                 }
                    //             }
                    //         )
                    //         .transition(.opacity)
                    //     }
                    // }
                    // The catch dims the instrument beneath it, slightly
                    .opacity(appState.currentState == .catchMode ? 0.55 : 1.0)
                    .animation(.easeInOut(duration: 0.3),
                               value: appState.currentState == .catchMode)
                        // STEADY LOCK (5 s+): warm breathing halo behind the face
                        .background(
                            Circle()
                                .fill(Color(hex: "#c4845a").opacity(steadyLock ? (breathePulse ? 0.16 : 0.09) : 0))
                                .frame(width: 330, height: 330)
                                .scaleEffect(breathePulse ? 1.05 : 0.97)
                                .blur(radius: 42)
                                .allowsHitTesting(false)
                        )
                        // Tap: alive — pulse, brief bearing readout, soft haptic
                        .scaleEffect(faceTapPulse ? 1.015 : 1.0)
                        .overlay(
                            Text("\(Int(compass.state.bearingDegrees.rounded()))°")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(DesignTokens.Color.textSecondary.opacity(0.9))
                                .monospacedDigit()
                                .offset(y: -52)
                                .opacity(bearingFlash ? 1 : 0)
                                .allowsHitTesting(false)
                        )
                        .contentShape(Circle())
                        .onTapGesture { tapFace() }
                        // [restore-tap] REMOVED the isPressingCompass DragGesture (the touch gate broke
                        // hands-free aiming). The compass hold is the phone-AIM (alignment-based holdTick),
                        // and the TAP is this .onTapGesture → tapFace → send. Preserved:
                        // .simultaneousGesture(DragGesture(minimumDistance: 0)
                        //     .onChanged { _ in isPressingCompass = true }
                        //     .onEnded   { _ in isPressingCompass = false })
                        // [2/6] SIMULTANEOUS long-press → instrument picker, so it
                        // fires on EVERY instrument even when the instrument owns
                        // its own drag gesture (e.g. the plane's circular swirl).
                        // A still 0.5 s press opens the picker; any rotation feeds
                        // the swirl instead — no conflict.
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    // [restore-tap] picker works on ALL instruments incl. compass again
                                    // (the compass hold is hands-free phone-aim, not a finger-press, so no
                                    // conflict). PRIOR (removed): guard instrumentStore.selected != .compass else { return }
                                    HapticEngine.personSelected()
                                    withAnimation(.easeOut(duration: 0.3)) { showSkinOverlay = true }
                                }
                        )

                    // [recipe moved up] Mechanism recipe (+ compass-only aim hint),
                    // sitting JUST UNDER the instrument it describes — it took the
                    // retired dots' slot. (Previously lived in bottomBandRedesign.)
                    instrumentHelperLines
                        .padding(.top, 26)

                    Spacer(minLength: 12)

                    // ── [bottom-band redesign] NEW STACK ──────────────────────
                    // compass face (above, UNCHANGED) → helper lines (aim hint +
                    // mechanism recipe) → preview line (emoji + full message) →
                    // picker row [Animation] [Emoji] [Message] [To]. No send
                    // button — the instrument gesture sends, always with a payload.
                    bottomBandRedesign
                        .padding(.top, 20)
                        // The catch owns the screen — the band recedes to 30 %.
                        .opacity(appState.currentState == .catchMode ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3),
                                   value: appState.currentState == .catchMode)

                    // ── Catch badge — KEPT (per scope) until the History tab is built ──
                    if pings.queueCount > 0 && pings.nowPlaying == nil {
                        CatchBadgeView(count: pings.queueCount) {
                            pings.playNext()
                        }
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // ── RETIRED (preserved — commented, never deleted) ──────────
                    // Replaced by `bottomBandRedesign` above. The emoji STRIP
                    // (`emojiRow`) is NOT retired — it is reused inside the [Emoji]
                    // picker box; only its in-band placement here is removed. The
                    // word block (`bottomZone`) and the instruction line
                    // (`sendControl`) are fully retired. Restore by uncommenting:
                    //   bottomZone
                    //       .padding(.top, 24)
                    //   emojiRow
                    //       .padding(.top, pings.queueCount > 0 && pings.nowPlaying == nil ? 8 : 26)
                    //       .opacity(appState.currentState == .catchMode ? 0.3 : 1.0)
                    //       .animation(.easeInOut(duration: 0.3),
                    //                  value: appState.currentState == .catchMode)
                    //   sendControl
                    //       .padding(.top, 10)
                    //       .padding(.bottom, 12)

                    // (connect link removed — connection UI lives in the
                    //  People tab only; the compass stays clean)

                    // (send pill retired — the row replaced it; view kept)
                    // sendPill

                    // (lock badge + always-on bearing readout retired from the
                    //  layout — bearing now appears on face tap; views kept)
                    // lockBadge
                    // bearingReadout
                }
            }

            // ── The flight — the chosen sender style carries the thought
            // out in the real compass direction (glow · star · firefly) ──────
            if let token = flightToken {
                let previewEmoji = sendRemoteEmoji(for: token)
                let previewStyle = instrumentStore.selected.senderStyle
                // [instrument versioning] V1 is the active send path: every style
                // routes through the shared SenderAnimationView (its proven inline
                // journeys: bowArrowSend · fingerFlickSend · planeSend · wandSend …).
                // The today's full-screen ACT redesigns (BowSendAnimationV2 /
                // FlickSendAnimationV2 / PlaneSendAnimationV2) are parked for the
                // Animation Test Lab and NOT wired live until explicitly promoted.
                //
                // [wand] EXCEPTION — Wand owns a dedicated full-screen magical send
                // cut scene (the previously-missing blaze across the screen). It is
                // approved and wired live here, the same way the rocket v2 parachute
                // receipt is. All paths call the SAME completion → pipeline unchanged.
                Group {
                    // [special moments — peer animations] STYLE-keyed first (the
                    // animation is the entry point, any emoji); the emoji check is
                    // KEPT as a transition fallback (legacy 🎂/🎆 pick) — retire in
                    // Stage 4. PRIOR conditions were emoji-only:
                    //   if previewEmoji == "🎆" { … }
                    //   else if previewEmoji == "🎂" { … }
                    // [arrival-parity stage0] Selector now comes from the PURE
                    // AnimationDispatch.sendAnimationKind — IDENTICAL conditions/order to the
                    // original if/else chain; each case renders the SAME view + onComplete (moved
                    // verbatim). ZERO behavior change. The ORIGINAL chain is preserved verbatim in
                    // the `#if false` block just below (comment-don't-delete).
                    switch AnimationDispatch.sendAnimationKind(for: previewStyle, emoji: previewEmoji) {
                    case .firework:
                        FireworkSendAnimation(
                            emoji: previewEmoji,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    case .birthday:
                        BirthdayCakeSendAnimationV2(
                            emoji: previewEmoji,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    case .wand:
                        WandSendAnimation(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .wand,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    case .bowArrow:
                        BowSendAnimationV2(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .bow,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    case .plane:
                        PlaneSendAnimation(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .plane,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    case .fingerFlick:
                        FlickSendAnimationV2(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .flick,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    case .shared:
                        SenderAnimationView(
                            style: previewStyle,
                            emoji: previewEmoji,
                            bearingDegrees: compass.state.bearingDegrees,
                            symbol: sendSymbol(token, size: 45)   // [5/5] 50% bigger base
                        ) {
                            flightToken = nil
                            flightFly   = false
                            finishSend(emoji: previewEmoji, style: previewStyle)
                        }
                    }
                    #if false  // [arrival-parity stage0] ORIGINAL if/else chain — preserved verbatim:
                    if previewStyle == .firework || previewEmoji == "🎆" {
                        // [firework] the spectacular deep-space launch → small pops →
                        // massive burst → embers, then back to the pipeline.
                        FireworkSendAnimation(
                            emoji: previewEmoji,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else if previewStyle == .birthday || previewEmoji == "🎂" {
                        // [birthday V2] the cake + confetti burst, then back to the
                        // pipeline (no EmojiRevealView here).
                        BirthdayCakeSendAnimationV2(
                            emoji: previewEmoji,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else if previewStyle == .wand {
                        WandSendAnimation(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .wand,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else if previewStyle == .bowArrow {
                        // [bow] The approved visual-bible rebuild — promoted live.
                        BowSendAnimationV2(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .bow,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else if previewStyle == .plane {
                        // [plane] The approved visual-bible send (Screen 3) — the
                        // top-down plane climbs NE on a dark sky, then hands back
                        // to the finishSend pipeline (no EmojiRevealView here).
                        PlaneSendAnimation(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .plane,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else if previewStyle == .fingerFlick {
                        // [flick] [ROOT-2 promote] The locked V2 (DESK) send — the
                        // paper ball spins across a twilight sky, then hands back to
                        // the finishSend pipeline (NO embedded reveal — verified).
                        // PRIOR: flick fell to the inline V1 `SenderAnimationView`
                        // (the else branch below); that path is unchanged for the
                        // remaining styles (glow · star · wind · rocket).
                        FlickSendAnimationV2(
                            transition: InstrumentTransition(
                                exitBearing: compass.state.bearingDegrees,
                                exitPoint: .zero,
                                instrument: .flick,
                                emoji: previewEmoji,
                                message: sentMessage,
                                tagline: sentTagline),
                            personName: compass.state.personName,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else {
                        SenderAnimationView(
                            style: previewStyle,
                            emoji: previewEmoji,
                            bearingDegrees: compass.state.bearingDegrees,
                            symbol: sendSymbol(token, size: 45)   // [5/5] 50% bigger base
                        ) {
                            flightToken = nil
                            flightFly   = false
                            finishSend(emoji: previewEmoji, style: previewStyle)
                        }
                    }
                    #endif
                }
                .zIndex(6)
            }
            // (previous straight-line flight retired — curves only now)
            // if let token = flightToken {
            //     let rad  = compass.state.bearingDegrees * .pi / 180
            //     let edge = CGSize(width: CGFloat(sin(rad)) * 430,
            //                       height: -CGFloat(cos(rad)) * 430)
            //
            //     ForEach(0..<4, id: \.self) { i in
            //         sendSymbol(token, size: 13)
            //             .opacity(flightFly ? 0 : 0.65 - Double(i) * 0.14)
            //             .offset(flightFly ? edge : .zero)
            //             .animation(.easeIn(duration: 1.1).delay(0.10 + Double(i) * 0.08),
            //                        value: flightFly)
            //     }
            //     sendSymbol(token, size: 30)
            //         .scaleEffect(flightFly ? 1.7 : 0.7)
            //         .opacity(flightFly ? 0 : 1)
            //         .offset(flightFly ? edge : .zero)
            //         .animation(.easeIn(duration: 1.2).delay(0.05), value: flightFly)
            //         .shadow(color: Color(hex: "#9b7fc0").opacity(0.8), radius: 12)
            //         .allowsHitTesting(false)
            // }

            // ── Sender caught confirmation — the emoji they sent appears
            // briefly at the compass center. No text. No timestamp. No read
            // receipt. Just a warm symbolic moment (600 ms, then gone). ──────
            if let caught = pings.caughtMoment {
                CaughtConfirmationView(emoji: caught.emoji)
                    .id(caught.at)
                    .zIndex(6)
            }

            // ── Send failed — the flight played but the thought did NOT
            // travel. Quiet, honest, 4 s. ─────────────────────────────────────
            if let failure = pings.sendFailedNotice {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 10))
                        Text(failure)
                            .font(.system(size: 12, design: .serif).italic())
                    }
                    .foregroundColor(Color(hex: "#e08a3c"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Color.background.opacity(0.9))
                            .overlay(Capsule().stroke(Color(hex: "#e08a3c").opacity(0.35), lineWidth: 1))
                    )
                    .padding(.top, 64)
                    Spacer()
                }
                .zIndex(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.4), value: pings.sendFailedNotice)
            }

            // [phase2 stage A] LIVE — link create failed. The flight already
            // played (sacred); offer a quiet, tappable retry. Mirrors the
            // sendFailedNotice capsule. Never blocks; auto-clears via re-run.
            if let linkFailure = pings.linkFailedNotice {
                VStack {
                    Button { pings.retryLinkSend() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                            Text(linkFailure)
                                .font(.system(size: 12, design: .serif).italic())
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(Color(hex: "#e08a3c"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.background.opacity(0.9))
                                .overlay(Capsule().stroke(Color(hex: "#e08a3c").opacity(0.35), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 64)
                    Spacer()
                }
                .zIndex(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.4), value: pings.linkFailedNotice)
            }

            // (felt-receipt text capsule retired — replaced by the symbolic
            //  caught confirmation above; view kept for reference)
            // if let notice = pings.feltNotice {
            //     VStack {
            //         HStack(spacing: 6) {
            //             Image(systemName: "heart.fill")
            //                 .font(.system(size: 10))
            //             Text(notice)
            //                 .font(.system(size: 12, design: .serif).italic())
            //         }
            //         .foregroundColor(Color(hex: "#5dcaa5"))
            //         .padding(.horizontal, 14)
            //         .padding(.vertical, 8)
            //         .background(
            //             Capsule()
            //                 .fill(DesignTokens.Color.background.opacity(0.85))
            //                 .overlay(Capsule().stroke(Color(hex: "#5dcaa5").opacity(0.35), lineWidth: 1))
            //         )
            //         .padding(.top, 64)
            //         Spacer()
            //     }
            //     .transition(.opacity.combined(with: .move(edge: .top)))
            //     .animation(.easeInOut(duration: 0.4), value: pings.feltNotice)
            // }

            // (badge moved into the layout above the emoji row — every tier,
            //  count always shown; old top-floating pro-only version retired)

            // ── Arrival            // ── Arrival → CATCH MODE ──────────────────────────────────────────
            // Only the newest thought triggers the catch; the orb waits at
            // the sender's edge until you physically turn toward them.
            // opened_at is set at the reveal — felt means felt.
            // THE RECEIPT is now a dedicated full-screen cover over the TabView
            // (see MainTabView) — the inline BucketCatchView is retired so the
            // tab bar hides and the compass isn't visible during a receipt.
            // (kept for reference:)
            // if let playing = pings.nowPlaying {
            //     BucketCatchView(ping: playing,
            //         style: SenderStyle.from(playing.senderStyle),
            //         onRevealed: { pings.markOpened(playing) },
            //         onFinished: { pings.finishedPlaying(playing); appState.transition(to: .idle) })
            //         .transition(.opacity).zIndex(7)
            // }
            // (previous arrival flows retired — views kept for reference:
            //  proOn → ThoughtArrivalView, core → DirectionalArrivalView)

            // ── [1/6] LAYER 3: screen-edge glow on the person's side ──────────
            if alignmentActive {
                AlignmentEdgeGlowView(relativeBearing: compass.state.bearingDegrees)
                    .transition(.opacity)
            }

            // [9b · B4] ambient-presence edge-glow layer REMOVED (presenceGlowVisible
            // never became true — see the removed onChange + the no-op pointing source).

            // ── "✦ Pro" indicator — top right, tap → Pro tab [6/6] ─────
            if proOn {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            NotificationCenter.default.post(name: .pointwardOpenPro, object: nil)
                        } label: {
                            Text("✦ Pro")
                                .font(.system(size: 10, design: .serif).italic())
                                .foregroundColor(DesignTokens.Color.accentMid.opacity(0.75))
                        }
                        .padding(.trailing, 18)
                        .padding(.top, 10)
                    }
                    Spacer()
                }
            }

            // ── [copy-declutter ITEM 7] Shareable compass moment disabled for v1 (preserved) ──
            #if false
            // ── Shareable compass moment — appears briefly after lock ─────────
            if showShareMoment, let card = shareCard {
                VStack {
                    Spacer()
                    ShareLink(
                        item: card,
                        preview: SharePreview("Pointward — \(compass.state.personName)", image: card)
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10))
                            Text("share this moment")
                                .font(.system(size: 11, design: .serif).italic())
                        }
                        .foregroundColor(DesignTokens.Color.accentMid)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.backgroundLift.opacity(0.9))
                                .overlay(Capsule().stroke(DesignTokens.Color.border, lineWidth: 1))
                        )
                    }
                    .padding(.bottom, 46)
                }
                .transition(.opacity)
            }
            #endif

            // ── [copy-declutter] Discovery hint retired (vestigial) ───────────
            /*
            // ── Discovery hint — first three launches only ────────────────────
            if showDiscoveryHint {
                VStack {
                    Spacer()
                    Text("tap the words to explore")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid.opacity(0.8))
                        .padding(.bottom, 18)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
            */

            // ── THE ONE PICKER — long-press any instrument, choose your
            // style: compass variants (free) + instruments (pro) ──────────────
            if showSkinOverlay {
                InstrumentOptionPicker(
                    isPro: subscription.tier != .free,
                    onLockedTap: {
                        showSkinOverlay = false
                        showSkinPaywall = true
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) { showSkinOverlay = false }
                    }
                )
                .transition(.opacity)
                .zIndex(5)
            }
            // (previous skin-only picker retired; SkinQuickPicker kept)

            // ── Pointing toast retired — ambient presence glow replaced it ────
            // if let notice = pings.pointingNotice {
            //     VStack {
            //         HStack(spacing: 7) {
            //             Text("🧭").font(.system(size: 14))
            //             Text(notice)
            //                 .font(.system(size: 13, design: .serif).italic())
            //                 .foregroundColor(DesignTokens.Color.textPrimary)
            //         }
            //         .padding(.horizontal, 16).padding(.vertical, 10)
            //         .background(Capsule().fill(DesignTokens.Color.backgroundLift.opacity(0.95)))
            //         .padding(.top, 14)
            //         Spacer()
            //     }
            // }
        }
    }

    // compassRoot + its overlays. Split from the reaction modifiers (.onChange/
    // .task/.sheet…) below so each half type-checks within budget.
    private var decoratedRoot: some View {
        compassRoot
        // [1/3] CANCEL (X) — top-level overlay so it sits above EVERY instrument
        // surface and gesture; tapping it always works, mid-send, on all 7.
        .overlay(alignment: .topTrailing) { cancelButton }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedToken != nil)
        // ── Reactions to state changes ────────────────────────────────────────
        // [9b · B4] ambient-presence edge-glow onChange REMOVED — it was keyed on
        // pings.partnerPointingAt, which never changed (the mutual-pointing source,
        // reportPointing, is a no-op), so the glow never fired. The compass's core
        // reactions below (lock handling, drawer, overlays) are untouched.
        .onChange(of: compass.state.isLocked)        { _, locked in handleLock(locked) }
        // [1/6] Thought history on the compass — icon, drawer, replay caption.
        // [3/5] Moved top-left (below the nav bar), clear of the send controls.
        .overlay(alignment: .topLeading) { thoughtsIcon }
        .overlay { thoughtsDrawerLayer }
        .overlay { messageComposeOverlay }   // [5/7] top-of-screen message editor
        .overlay { sendFeedbackLayer }       // [5/6] arrival preview + "sent ✦" + keep-prompt
        .overlay(alignment: .top) { replayCaptionView }
    }

    var body: some View {
        decoratedRoot
        // [build9] Unified bucket is sender-agnostic → reload keys off caughtHistory
        // (the local source), not selectedPerson. Runs once on appear + on change.
        .task(id: pings.caughtHistory.count) { await loadCompassThoughts() }
        .onChange(of: pings.queueCount) { _, _ in
            Task { await loadCompassThoughts() }   // a new thought just landed
        }
        .onChange(of: pings.replayRequest) { _, req in
            // When the app-wide replay finishes (request clears), fade in the
            // "from [name] · [time ago]" caption for 2 s, then return to normal.
            guard req == nil, let caption = pendingReplayCaption else { return }
            pendingReplayCaption = nil
            withAnimation(.easeIn(duration: 0.5)) { replayCaption = caption }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.6)) { replayCaption = nil }
            }
        }
        .sheet(isPresented: $showSkinPaywall) { PaywallView() }
        // [3/6] Compass send mechanic: hold within 15° for 2 s → auto-send.
        // Built-in, every tier — the tap button is gone.
        .onReceive(holdTick) { _ in
            // [redesign] No longer gated on `selectedToken` — a default always supplies a payload.
            guard instrumentStore.selected == .compass, flightToken == nil else {
                if holdProgress > 0 { holdProgress = 0 }
                return
            }
            // [compass-grace] Suppress EVERYTHING (no arm, no accumulate, no fire) for the first few seconds
            // after the compass becomes active — so the startup heading settle (or re-opening the app while
            // aimed) can't auto-send. After the grace, normal hands-free logic resumes (disarmed → needs a
            // deliberate turn-away-then-aim).
            if Date.now.timeIntervalSince(compassReadyAt) < compassGrace {
                if holdProgress > 0 { holdProgress = 0 }
                return
            }
            // [hands-free] DISARMED after a fire — do NOT accumulate or re-fire. Re-arm ONLY once the phone
            // swings AWAY past compassReArmThreshold (~30°), then a re-aim fires again. This is the reset that
            // makes it fire ONCE per aim (no rapid-fire) AND enables repeat sends.
            if !compassArmed {
                if holdProgress > 0 { holdProgress = 0 }
                if sendAlignDiff >= compassReArmThreshold { compassArmed = true }
                return
            }
            // SOFT LOCK — the hold STARTS within 15°, then tolerates drift up to 30° (aim hysteresis) so a
            // small wobble never breaks it.
            let holding = holdProgress > 0
            if sendAlignDiff <= 15 || (holding && sendAlignDiff <= 30) {
                holdProgress += 0.05 / holdDuration
                if holdProgress >= 1.0 {
                    holdProgress = 0
                    compassArmed = false            // [hands-free] disarm AT fire — fires once; re-arm via turn-away
                    HapticEngine.compassSend()
                    sendThought(effectiveToken)     // [hands-free] AUTO-SEND on hold complete — no tap
                }
            } else if holdProgress > 0 {
                withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
            }
        }
        .onChange(of: compass.state.personID)        { _, _      in handlePersonChange() }
        .onChange(of: pings.queue.isEmpty)           { _, empty  in
            withAnimation(AnimationSystem.pingGlow) { pingRingActive = !empty }
        }
        .onAppear {
            // Hard guard — free tier renders Minimal only. Silent and
            // immediate, before the compass face appears.
            skinStore.enforceTier(subscription.tier)
            compassReadyAt = .now   // [compass-grace] start the no-auto-fire window on app open / screen appear
            if let person = people.selectedPerson {
                compass.start(tracking: person)
            }
            #if DEBUG
            runCompassSelfTestIfRequested()   // [restore-tap selftest] -compassSelfTest
            #endif
            syncPersonTagline()            // [4/4] show the selected person's tagline
            // Locked favourites override the per-launch randomization
            if funnyUnitLocked >= 0 && funnyUnitLocked < DistanceFun.funnyCount {
                funnyIndex = funnyUnitLocked
            }
            if thoughtTaglineLocked >= 0 && thoughtTaglineLocked < TaglineSystem.poeticLibrary.count {
                // Locked favourite leads; the rest still cycle behind it
                taglineOrder = [thoughtTaglineLocked]
                    + TaglineSystem.poeticLibrary.indices.filter { $0 != thoughtTaglineLocked }.shuffled()
                taglinePosition = 0
            }
            // [copy-declutter] Discovery hint trigger retired (vestigial)
            /*
            // Discovery hint — first three launches only
            if discoveryHintCount < 3 {
                discoveryHintCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeIn(duration: 0.6)) { showDiscoveryHint = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation(.easeOut(duration: 0.8)) { showDiscoveryHint = false }
                }
            }
            */
        }
        .onChange(of: people.selectedPerson) { _, newPerson in
            if let person = newPerson {
                compass.start(tracking: person)
            }
            syncPersonTagline()            // [4/4] switch people → switch tagline
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonView(geocodingService: appEnv.geocodingService)
        }
        // [4/4] The full tagline picker — long-press the tagline to open.
        .sheet(isPresented: $showTaglinePicker) {
            if let person = people.selectedPerson {
                TaglinePickerSheet(current: personTagline) { chosen in
                    applyTagline(chosen, to: person)
                }
            }
        }
    }

    // MARK: - Empty state

    @State private var emptyGlowPulse = false

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Compass emoji with a soft pulsing glow
            ZStack {
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(emptyGlowPulse ? 0.30 : 0.14))
                    .frame(width: 110, height: 110)
                    .blur(radius: 22)
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                    .frame(width: 124, height: 124)
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.12), lineWidth: 1)
                    .frame(width: 148, height: 148)
                Text("🧭")
                    .font(.system(size: 52))
                    .scaleEffect(emptyGlowPulse ? 1.04 : 1.0)
            }
            .padding(.bottom, 32)
            .onAppear {
                guard !quietMode else { return }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                    emptyGlowPulse = true
                }
            }

            Text("the needle is ready")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.bottom, 6)

            Text("add someone to point toward")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .padding(.bottom, 10)

            Text("Thinking of you.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.accentMid)
                .padding(.bottom, 28)

            Button {
                showAddPerson = true
            } label: {
                Text("who do you point toward?")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(DesignTokens.Color.accentStrong)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DesignTokens.Color.accentMid, lineWidth: 1))
            }

            Spacer()
        }
    }

    // MARK: - Person header

    // ── TOP ZONE ──────────────────────────────────────────────────────────

    /// The name — largest text on screen, a dedication in a book.
    /// ✦ marks it tappable when there's more than one person.
    private var nameHeader: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Text(compass.state.personName)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: compass.state.personName)
                // [5/6] Subtle "demo" badge on Alex's card — quietly says
                // "this one's a placeholder," never shouts.
                if isDemoSelected {
                    Text("demo")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().stroke(DesignTokens.Color.accentMid.opacity(0.6),
                                                     lineWidth: 1))
                } else if people.people.count > 1 {
                    Text("✦")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.accentMid.opacity(0.7))
                }
            }
            .onTapGesture {
                // [sole-contact switcher] Always open the switcher when there's at least one
                // person (incl. the sole-Demo-Dan case). PRIOR `count > 1` suppressed it for a
                // single contact — outdated now that the switcher carries an inline
                // "+ add new person" row, so tapping with one contact is useful (add another).
                guard !people.people.isEmpty else { return }
                HapticEngine.personSelected()
                showPersonSwitcher = true
            }

            // [5/6] One-time gentle nudge — shown only while Alex is the only
            // card and not yet dismissed. Tapping opens "add someone real"
            // and retires the hint forever.
            if isDemoSelected && !demoHintDismissed {
                Button {
                    withAnimation { demoHintDismissed = true }
                    HapticEngine.personSelected()
                    showAddPerson = true
                } label: {
                    Text("replace with someone real →")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPersonSwitcher) {
            PersonSwitcherSheet()
                .presentationDetents([.height(min(420, CGFloat(people.people.count) * 64 + 90))])
                .presentationDragIndicator(.visible)
        }
        // [§C PART 2] not-signed-in real send → minimal onboarding (ComposeBackView reuse).
        // onEntered: dismiss back to compose; the now-signed-in user re-taps send → guard passes.
        .fullScreenCover(isPresented: $showOnboardForSend) {
            ComposeBackView(
                senderName: people.selectedPerson?.name ?? "them",
                onEntered: { showOnboardForSend = false }
            )
            .environmentObject(people)
        }
    }

    /// [5/6] True when the compass is showing the auto-created demo person (Alex).
    private var isDemoSelected: Bool {
        // [concurrency 2026-06-13] Call DemoPerson.isDemo directly on the main actor
        // instead of passing it as a function value to `.map` — the latter strips
        // its main-actor isolation (a Swift 6 error: "main actor-isolated static
        // method 'isDemo' in a synchronous nonisolated context").
        guard let person = people.selectedPerson else { return false }
        return DemoPerson.isDemo(person)
    }

    /// [§C PART 2] A not-signed-in user tried a REAL send → route to the minimal
    /// onboarding (reuse ComposeBackView, no new screen). onEntered just dismisses;
    /// the now-signed-in user re-taps send and the guard passes. Demo Dan never reaches
    /// here (exempted in the guard). Reply-shaped copy is acceptable for now (refine later).
    private func routeToOnboardingForSend() {
        showOnboardForSend = true
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - [bottom-band redesign] Helper lines · preview · picker row
    // ════════════════════════════════════════════════════════════════════

    /// [recipe moved up] The two helper lines that sit JUST UNDER the instrument:
    /// the mechanism recipe (always) and — for the compass ONLY — the live
    /// directional aim hint. Relocated here out of `bottomBandRedesign` so the
    /// recipe sits with the instrument it describes (it also fills the slot the
    /// retired stage-completion dots used to occupy).
    private var instrumentHelperLines: some View {
        // [tagline rework 2026-06-26] ONE single line now (was the 2-line `mechanismRecipe`
        // recipe + compass `degreeReadout`). Reserve the prior 2-line height and CENTER the one
        // line in it → it "drops to center", reads intentional, and the slot height stays
        // constant so nothing below reflows (incl. the compass nil-hide). `instrumentTagline`
        // is nil for the compass when there's no fix → the line hides, the slot holds.
        // Preserved original (restore by swapping back):
        //   VStack(spacing: 6) {
        //       Text(mechanismRecipe)
        //           .font(.system(size: 20, weight: .semibold))
        //           .foregroundColor(DesignTokens.Color.accentSoft)
        //           .multilineTextAlignment(.center)
        //       if isAimInstrument, compass.rawBearingToTarget != nil { degreeReadout }
        //   }
        VStack(spacing: 0) {
            if let tagline = instrumentTagline {
                Text(tagline)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)   // ≈ prior 2-line block height; centers the 1 line. TUNABLE (device-check).
        // Recede during a receipt, exactly as the dots did.
        .opacity(pings.nowPlaying == nil ? 1 : 0)
    }

    /// The redesigned bottom band, beneath the (unchanged) compass face:
    /// preview line (feeling + full message) → picker row [Animation] [Emoji]
    /// [Message] [To]. No send button — the instrument gesture sends, always
    /// with a payload. (The helper lines moved up to `instrumentHelperLines`.)
    private var bottomBandRedesign: some View {
        VStack(spacing: 12) {

            // [recipe moved up] The aim hint + mechanism-recipe helper lines used
            // to render here; they now live in `instrumentHelperLines`, just under
            // the instrument. The band now begins at the preview line.

            // ── Preview line — the feeling + the FULL typed message ───────
            previewLine
                .padding(.top, 2)

            // ── Picker row — [Animation] [Emoji] [Message] [To] ──────────
            pickerRow
                .padding(.horizontal, 16)
                .padding(.top, 4)

            // ── Emoji strip — REUSED verbatim, toggled by the [Emoji] box ─
            if showEmojiPicker {
                emojiRow
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    /// The chosen (or default) feeling next to the full message text. The
    /// message is emotional → serif, per the design system.
    private var previewLine: some View {
        HStack(spacing: 8) {
            sendSymbol(effectiveToken, size: 24)
            if !messageText.isEmpty {
                Text(messageText)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    /// Four labeled boxes, each showing its current value and opening its
    /// EXISTING selector. No new data sources — every box reads/writes the
    /// same state the old surfaces did.
    private var pickerRow: some View {
        HStack(spacing: 8) {
            pickerBox(label: "animation") {
                pickerValue(instrumentStore.selected.displayName)
            } action: {
                HapticEngine.personSelected()
                withAnimation(.easeOut(duration: 0.3)) { showSkinOverlay = true }
            }
            pickerBox(label: "emoji") {
                sendSymbol(effectiveToken, size: 22)
            } action: {
                HapticEngine.personSelected()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showEmojiPicker.toggle()
                }
            }
            pickerBox(label: "message") {
                pickerValue(messageText.isEmpty ? "add" : messageText)
            } action: {
                // The compose overlay needs a non-nil token — commit the
                // default feeling first so a message can be written even before
                // an explicit emoji choice (messageComposeOverlay stays unchanged).
                if selectedToken == nil { selectedToken = defaultEmojiForCurrentAnimation }
                composing = true
                messageFocused = true
            }
            pickerBox(label: "to") {
                pickerValue(compass.state.personName)
            } action: {
                HapticEngine.personSelected()
                showPersonSwitcher = true
            }
        }
    }

    /// One labeled picker box: the current value on top, the label beneath.
    private func pickerBox<C: View>(label: String,
                                    @ViewBuilder content: () -> C,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                content()
                    .frame(height: 26)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(DesignTokens.Color.backgroundCard.opacity(0.7))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DesignTokens.Color.border.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// The value text inside a picker box — single line, truncated.
    private func pickerValue(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(DesignTokens.Color.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
    }

    // ── BOTTOM ZONE ───────────────────────────────────────────────────────

    /// The mode line 1 cycles through: standard → funny (Pro) → light speed.
    /// [§B3] TOP ZONE — "{name} is at {N}°": the ABSOLUTE bearing to the person
    /// (`compass.rawBearingToTarget`), raw 0–360 integer, no cardinal word. Only rendered inside the
    /// `rawBearingToTarget != nil` gate (hidden for seeded / Demo-Dan / no-GPS, like the distance).
    private var degreeReadout: some View {
        Text("\(compass.state.personName) is at \(Int((compass.rawBearingToTarget ?? 0).rounded()))°")
            .font(.system(size: 20, weight: .medium))   // [§B] +~50% field-text size (was 14)
            .foregroundColor(DesignTokens.Color.textMuted)
            .monospacedDigit()
            .multilineTextAlignment(.center)
    }

    private var distanceLineText: String {
        switch distanceMode {
        case 1:  return DistanceFun.funnyText(km: compass.state.distanceKm, index: funnyIndex)
        case 2:  return DistanceFun.lightSpeedText(km: compass.state.distanceKm)
        default: return compass.state.formattedDistance
        }
    }

    /// TOP ZONE line 2 — the distance, tap cycles: standard → funny (Pro)
    /// → light speed. Number only, clean crossfade, free skips funny.
    private var distanceLine: some View {
        HStack(spacing: 5) {
            Text(distanceLineText)
                // Halfway between the old distance (15) and the name (34) —
                // important information, not a footnote
                .font(.system(size: 24, weight: .light))
                .foregroundColor(DesignTokens.Color.textSecondary)
                .monospacedDigit()
                .contentTransition(.opacity)
            Text("✦")
                .font(.system(size: 8))
                .foregroundColor(DesignTokens.Color.textDim.opacity(0.7))
        }
        .onTapGesture {
            HapticEngine.personSelected()
            withAnimation(.easeInOut(duration: 0.3)) {
                let next = (distanceMode + 1) % 3
                distanceMode = (next == 1 && !proOn) ? 2 : next
            }
        }
        .animation(.easeInOut(duration: 0.3), value: distanceMode)
    }

    /* [bottom-band redesign] RETIRED — the WORD BLOCK is replaced by the preview
       line + the [Message] picker box. Preserved verbatim (commented, never
       deleted); retires A2 "tap to add a tagline" and A5 "add a message".
       Restore by un-wrapping this block comment.
    private var bottomZone: some View {
        VStack(spacing: 12) {
            // [1/6] ONE text zone above the emoji row — never a second box below.
            //  · no feeling chosen → the per-person tagline (tap to cycle,
            //    long-press for the picker)
            //  · feeling chosen → that feeling's message in the SAME spot
            //    (tap to edit — custom text or a suggestion)
            if selectedToken != nil {
                Button {
                    HapticEngine.personSelected()
                    withAnimation(.easeOut(duration: 0.25)) { composing = true }
                } label: {
                    HStack(spacing: 5) {
                        Text(messageText.isEmpty ? "add a message" : messageText)
                            .font(.system(size: 26, design: .serif).italic())
                            .foregroundColor(messageText.isEmpty
                                             ? DesignTokens.Color.accentMid.opacity(0.5)
                                             : DesignTokens.Color.accentMid)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.accentMid.opacity(0.55))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentTransition(.opacity)
            } else {
                HStack(spacing: 5) {
                    Text(personTagline ?? "tap to add a tagline")
                        .font(.system(size: 26, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid
                                            .opacity(personTagline == nil ? 0.5 : 1))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("✦")
                        .font(.system(size: 8))
                        .foregroundColor(DesignTokens.Color.accentMid.opacity(0.55))
                }
                .contentTransition(.opacity)
                .onTapGesture { cycleTagline() }
                .onLongPressGesture(minimumDuration: 0.4) {
                    HapticEngine.personSelected()
                    showTaglinePicker = true
                }
            }

            if compass.state.isFarFromHome {
                Text("across the distance")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Color(hex: "#c4845a"))
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.45), value: compass.state.isFarFromHome)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: distanceMode)
        .animation(.easeInOut(duration: 0.3), value: selectedToken)
    }
    */

    // [4/4] Per-person tagline management.

    /// Tap the tagline → cycle to the next one for the selected person.
    private func cycleTagline() {
        guard let person = people.selectedPerson else { return }
        HapticEngine.personSelected()
        applyTagline(TaglineSystem.next(after: personTagline), to: person)
    }

    /// Set (or clear, when nil) the selected person's tagline and persist it.
    private func applyTagline(_ tagline: String?, to person: Person) {
        withAnimation(.easeInOut(duration: 0.4)) { personTagline = tagline }
        person.tagline = tagline
        try? people.save()
    }

    /// Keep the displayed tagline in step with whoever is selected.
    private func syncPersonTagline() {
        personTagline = people.selectedPerson?.tagline
    }

    /// Line 4 — the thin pill that opens the emoji drawer (thoughts tab).
    private var sendPill: some View {
        Button {
            HapticEngine.personSelected()
            NotificationCenter.default.post(name: .pointwardOpenThoughts, object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .medium))
                Text("send a thought")
                    .font(.system(size: 13, design: .serif).italic())
            }
            .foregroundColor(DesignTokens.Color.accentSoft)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(DesignTokens.Color.backgroundLift.opacity(0.9))
                    .overlay(Capsule().stroke(DesignTokens.Color.border, lineWidth: 1))
            )
        }
        // Swipe up on the pill also opens the drawer
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    if value.translation.height < -18 {
                        NotificationCenter.default.post(name: .pointwardOpenThoughts, object: nil)
                    }
                }
        )
    }

    /// Tap the face: it answers — pulse, brief bearing readout, soft haptic.
    #if DEBUG
    /// [restore-tap selftest] -compassSelfTest: force alignment so the LIVE holdTick locks, then
    /// auto-tap — exercising the whole point→hold→lock→tap→send chain in the Simulator and logging
    /// each stage. Temporary scaffold; remove once the mechanic is verified on a real device.
    private func runCompassSelfTestIfRequested() {
        guard CommandLine.arguments.contains("-compassSelfTest") else { return }
        CompassView.log.notice("[compass-diag] SELFTEST: forcing alignment in 2.5s (hands-free → should AUTO-FIRE)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            compass.forceAlignedTest = true
            compass.pokeStateForTest()
            CompassView.log.notice("[compass-diag] SELFTEST: alignment forced (alignDiff=\(sendAlignDiff, format: .fixed(precision: 1))) — live holdTick should accumulate → FIRE on its own")
            // Hands-free: no tap; the holdTick should reach 1.0 and auto-send within ~1.33s.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                compass.forceAlignedTest = false
                CompassView.log.notice("[compass-diag] SELFTEST: done — armed=\(compassArmed) holdProgress=\(holdProgress, format: .fixed(precision: 2))")
            }
        }
    }
    #endif

    private func tapFace() {
        // [restore-tap] When the compass has LOCKED and is awaiting the tap, a single tap SENDS
        // (point → hold → lock → tap). Otherwise the bearing-flash answer below.
        // [hands-free] Tap is NOT a send (auto-fires on hold). A tap just "answers" with the bearing flash.
        // Tap-to-send fallback preserved (flip back here + restore compassAwaitingTap if hands-free is ever
        // reverted):
        // if compassAwaitingTap { compassAwaitingTap = false; HapticEngine.compassSend(); sendThought(effectiveToken); return }
        HapticEngine.personSelected()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { faceTapPulse = true }
        withAnimation(.easeIn(duration: 0.3)) { bearingFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.4)) { faceTapPulse = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.6)) { bearingFlash = false }
        }
    }

    /// True only when the person has their own tagline — skin defaults don't count.
    private var hasCustomTagline: Bool {
        guard let t = compass.state.tagline else { return false }
        return !t.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Send a thought (merged from the thoughts tab)

    /// Free users carry the core six; Pro users their curated set.
    private var rowTokens: [String] {
        subscription.tier == .free ? PersonalSet.coreDefault : personalSixRow
    }

    // [1/6] messagePill (the separate box below the emojis) retired — the
    // message now lives in the one zone above the emoji row (bottomZone).

    /// [5/7] The compose editor — a card at the TOP of the screen (clear of the
    /// keyboard) with a focused field and 3–4 suggested messages for the chosen
    /// feeling. Tap a suggestion to use it, or keep typing a custom one.
    @ViewBuilder
    private var messageComposeOverlay: some View {
        if composing, let token = selectedToken {
            ZStack(alignment: .top) {
                // Dim scrim — tap anywhere outside to finish.
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { finishComposing() }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(token) your message")
                            .font(.system(size: 14, design: .serif).italic())
                            .foregroundColor(Color(hex: "#c4a8d4"))
                        Spacer()
                        Button("done") { finishComposing() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignTokens.Color.accentSoft)
                    }

                    HStack(spacing: 8) {
                        TextField("add a message (optional)", text: $messageText)
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .focused($messageFocused)
                            .submitLabel(.done)
                            .onSubmit { finishComposing() }
                            .onChange(of: messageText) { _, newValue in
                                let clamped = MessageRules.clamped(newValue)
                                if clamped != newValue { messageText = clamped }
                                // [custom-text lock] While the compose field is
                                // focused, any change is a hand-edit → lock it so a
                                // later emoji change won't overwrite it. Clearing
                                // the field releases the lock (default may refill).
                                if newValue.isEmpty {
                                    messageEdited = false
                                } else if messageFocused {
                                    messageEdited = true
                                }
                            }
                        Text("\(messageText.count)/30")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.textDim)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(DesignTokens.Color.backgroundLift)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(DesignTokens.Color.accentMid, lineWidth: 1))
                    )

                    // [copy-declutter] "or tap a suggestion" list removed — one
                    // defaultMessage per emoji (still pre-fills via seedMessage); the
                    // freeform field above stays. composeSuggestions/instrumentHint
                    // helpers preserved (now uncalled) for a future re-add.
                    /*
                    // Suggested alternatives for this feeling — tap to use.
                    Text("or tap a suggestion")
                        .font(DesignTokens.Font.overline)
                        .foregroundColor(DesignTokens.Color.textMuted)
                    let options = composeSuggestions(for: token)
                    VStack(spacing: 6) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                messageText = MessageRules.clamped(option)
                                messageEdited = true   // [custom-text lock] a chosen suggestion is a deliberate edit
                                HapticEngine.personSelected()
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundColor(messageText == option
                                                         ? DesignTokens.Color.textPrimary
                                                         : DesignTokens.Color.textSecondary)
                                    Spacer()
                                    if messageText == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(DesignTokens.Color.accentSoft)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(messageText == option
                                          ? DesignTokens.Color.accentStrong
                                          : DesignTokens.Color.backgroundCard))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(messageText == option
                                            ? DesignTokens.Color.accentMid
                                            : DesignTokens.Color.border, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    */
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(DesignTokens.Color.background)
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .stroke(DesignTokens.Color.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                )
                .padding(.horizontal, 16)
                .padding(.top, 60)
            }
            .transition(.opacity)
            .zIndex(20)
            .onAppear { messageFocused = true }
        }
    }

    /// The default message first, then its alternatives, then the current
    /// instrument's hint — offered as message options when composing.
    private func composeSuggestions(for token: String) -> [String] {
        var options: [String] = []
        if let def = CuratedEmoji.defaultMessage(token) { options.append(def) }
        options.append(contentsOf: CuratedEmoji.suggestions(token))
        // [hints 2026-06-13] The per-instrument default tone — TaglineSystem owns
        // these (instrumentHints, keyed by SenderStyle.rawValue). Offered as a
        // last option so the instrument's voice is always reachable.
        if let hint = instrumentHint(), !options.contains(hint) { options.append(hint) }
        return options
    }

    /// The current instrument's default-message hint (TaglineSystem.instrumentHints).
    /// nil if the instrument has no registered hint.
    private func instrumentHint() -> String? {
        TaglineSystem.hint(forStyleRaw: instrumentStore.selected.senderStyle.rawValue)
    }

    /// The starting message for a freshly-picked emoji: its curated default if it
    /// has one, otherwise the current instrument's hint (TaglineSystem). This is
    /// the single point where the message field is seeded on selection.
    /// The selected instrument's per-instrument default message (manifest), or nil when the
    /// instrument doesn't set one → falls back to the per-emoji default. Mirrors
    /// `defaultEmojiForCurrentAnimation`. Only Birthday sets a value today.
    private func instrumentDefaultMessage() -> String? {
        AnimationManifest.instruments
            .first { $0.instrument == instrumentStore.selected }?
            .defaultMessage
    }

    private func seedMessage(for item: CuratedEmoji.Item) -> String {
        // [per-instrument default message] PREFER the selected instrument's manifest
        // defaultMessage (e.g. Birthday → "Happy Birthday"). Deliberate intermediate state:
        // per-instrument preferred, per-emoji fallback — NOT a full migration. Every other
        // instrument leaves defaultMessage nil → falls through to EXACTLY today's chain
        // below (no regression). The seed stays USER-EDITABLE (the !messageEdited lock at
        // the call site still lets the user override).
        if let instrumentMessage = instrumentDefaultMessage(), !instrumentMessage.isEmpty {
            return instrumentMessage
        }
        // PRIOR (preserved) — per-emoji curated default, then the instrument's TaglineSystem hint:
        if !item.defaultMessage.isEmpty { return item.defaultMessage }
        return instrumentHint() ?? ""
    }

    private func finishComposing() {
        messageFocused = false
        withAnimation(.easeOut(duration: 0.25)) { composing = false }
    }

    /// [1/3] The curated set — base 6 (selectable), pro 5 (locked for free),
    /// occasion 3 (coming soon). Long-press shows the label; tap auto-fills the
    /// default message [3/3]. Horizontally scrollable to fit all 14.
    private var emojiRow: some View {
        VStack(spacing: 6) {
            if let longPressLabel {
                Text(longPressLabel)
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Color(hex: "#c4a8d4"))
                    .transition(.opacity)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CuratedEmoji.all) { item in emojiCell(item) }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    @ViewBuilder
    private func emojiCell(_ item: CuratedEmoji.Item) -> some View {
        let isPro = subscription.tier != .free
        let locked = item.access == .pro && !isPro
        let comingSoon = item.access == .comingSoon
        let isSelected = selectedToken == item.emoji
        Button {
            if comingSoon {
                HapticEngine.personSelected()
                showLabel("\(item.label) · coming soon")
            } else if locked {
                HapticEngine.paywallReached()
                showSkinPaywall = true                   // tap locked → upgrade
            } else if isSelected {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { selectedToken = nil }
                messageText = ""
                messageEdited = false           // [custom-text lock] clear the lock on deselect
                composing = false               // [5/7] close the message editor
                messageFocused = false
                HapticEngine.personSelected()
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { selectedToken = item.emoji }
                // [3/3] Auto-fill the warm default message (user can edit/clear).
                // [hints 2026-06-13] seedMessage falls back to the instrument's
                // TaglineSystem hint when the emoji has no curated default.
                // [custom-text lock] Only re-seed the default when the user has
                // NOT hand-edited the message — custom text survives an emoji
                // change; the animation default keeps following the emoji while
                // the field is still the default (or empty).
                if !messageEdited {
                    messageText = MessageRules.clamped(seedMessage(for: item))
                }
                triggerLoadFlight(item.emoji)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                sendSymbol(item.emoji, size: 26)
                    .frame(width: 50, height: 50)
                    .opacity(locked || comingSoon ? 0.5 : 1)
                    .background(DesignTokens.Color.backgroundCard.opacity(isSelected ? 1 : 0.7))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isSelected ? DesignTokens.Color.accentMid
                                               : DesignTokens.Color.border.opacity(0.6),
                                    lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#c4a8d4").opacity(isSelected ? 0.55 : 0), radius: 10)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#c4a8d4"))
                        .padding(2).background(Circle().fill(DesignTokens.Color.background))
                        .offset(x: 4, y: -4)
                } else if comingSoon {
                    Text("✨")
                        .font(.system(size: 11))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.3) { showLabel(item.label) }
    }

    private func showLabel(_ text: String) {
        HapticEngine.personSelected()
        withAnimation(.easeOut(duration: 0.2)) { longPressLabel = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) { if longPressLabel == text { longPressLabel = nil } }
        }
    }

    /// [1/6] LAYER 1 + [4/6]: one clear line below the instrument —
    /// alignment guidance until aligned, then the instrument's own action.
    /// (The tap-send button is GONE — compass sends by holding aligned.)
    /// [7/7] UNIVERSAL INSTRUCTION — big (22 pt), bold, bright, and step-by-step
    /// for every instrument. When nothing is loaded it tells you to pick a
    /// feeling; once loaded it shows the per-instrument steps with the "loaded"
    /// step already checked off.
    /// [6/8] Gently cancel the loaded feeling — deselect, clear the optional
    /// note, soft-haptic confirmation. Shared by the X button and tap-outside.
    private func cancelInstrument() {
        guard selectedToken != nil else { return }
        HapticEngine.caughtConfirmation()        // soft confirmation tap
        // Cut any in-flight hold/load progress so nothing fires after a cancel.
        holdProgress = 0
        compassArmed = false                     // [hands-free] cancel → disarmed (no surprise re-fire on a sitting-aligned phone; re-arm via turn-away)
        loadFlightToken = nil
        loadFlightProgress = 0
        messageFocused = false                   // [5/7] close the message editor
        messageEdited = false                    // [custom-text lock] reset on cancel
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            selectedToken = nil                  // deselect the feeling
            messageText = ""                     // clear the optional note
            composing = false                    // [5/7]
            instrumentResetID += 1               // rebuild instrument → idle
        }
    }

    /// [1/3] The instrument's view identity: changes when the user switches
    /// instruments (crossfade) AND when a cancel bumps instrumentResetID, which
    /// rebuilds the current instrument fresh in its idle state.
    private var instrumentIdentity: String {
        "\(instrumentStore.selected)-\(instrumentResetID)"
    }

    /// [1/3] The cancel (X) control — lives at the screen's top-trailing as a
    /// top-level overlay (see body root) so it ALWAYS sits above every
    /// instrument surface and gesture. Shown whenever a feeling is loaded and
    /// no receipt is playing; works identically on all 7 instruments.
    @ViewBuilder
    private var cancelButton: some View {
        if selectedToken != nil && pings.nowPlaying == nil {
            Button { cancelInstrument() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#c4a8d4"))
                    .frame(width: 38, height: 38)   // generous tap target
                    .background(Circle().fill(DesignTokens.Color.background.opacity(0.85)))
                    .overlay(Circle().stroke(Color(hex: "#7c6b8e").opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .padding(.top, 14).padding(.trailing, 18)
            .transition(.scale.combined(with: .opacity))
        }
    }

    /* [bottom-band redesign] RETIRED — the instruction line is replaced by the
       two helper lines (aim hint + mechanism recipe) in `bottomBandRedesign`.
       Preserved verbatim (commented, never deleted); retires C1 "tap above to
       add a feeling ✦". `universalInstruction` stays live — it now feeds
       `mechanismRecipe`. Restore by un-wrapping this block comment.
    @ViewBuilder
    private var sendControl: some View {
        if pings.nowPlaying != nil {
            EmptyView()
        } else if selectedToken == nil {
            Text("tap above to add a feeling ✦")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .shadow(color: Color(hex: "#c4a8d4").opacity(0.6), radius: 6)
                .frame(height: 30)
                .padding(.horizontal, 14)
        } else {
            Text(universalInstruction)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#e0ccee"))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .shadow(color: Color(hex: "#9b7fc0").opacity(0.7), radius: 6)
                .frame(height: 30)
                .padding(.horizontal, 14)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: universalInstruction)
        }
    }
    */

    /// Per-instrument step guide, shown once a feeling is loaded. The "loaded"
    /// step is checked; the rest are the steps to send.
    private var universalInstruction: String {
        // [bottom-band redesign] The "choose emoji · message · " PREFIX is retired
        // (the picker row now owns emoji + message); this returns the gesture TAIL
        // only — the mechanism recipe. Originals preserved below for restore:
        //   .compass: "choose emoji · message · point · hold"
        //   .bow:     "choose emoji · message · aim · draw · release"
        //   .firefly: "choose emoji · message · breathe"   // wind
        //   .flick:   "choose emoji · message · flick"
        //   .rocket:  "choose emoji · message · aim · fuel · blast"
        //   .wand:    "choose emoji · message · shake · release"
        //   .plane:   "choose emoji · message · wind · fly"
        // [§B1] Full per-instrument instruction blocks (John-approved 2026-06-25). `\n` = two lines;
        // \(name) = the person. COMPASS reworded for HANDS-FREE (no "tap"); the "at [x]°" is the degree
        // readout line below. PRIOR terse tails (preserved): compass "point · hold · turn away to reset" ·
        // bow "aim · draw · release" · firefly "breathe into mic" · flick "flick" · rocket "aim · fuel · blast" ·
        // wand "shake · release" · plane "wind · fly" · birthday "light the candles" · firework "light the fuse".
        let name = compass.state.personName
        switch instrumentStore.selected {
        case .compass:  return "Align the compass to \(name)'s direction\nHold on that direction to release your thought."
        case .bow:      return "Aim the bow toward \(name)\nDraw back, hold, then release your thought."
        case .firefly:  return "Blow into the mic to float your thought to \(name)."
        case .flick:    return "Flick your thought toward \(name)."
        case .rocket:   return "Point the rocket toward \(name)\nTap to fuel it up and launch your thought."
        case .wand:     return "Shake to gather magic for \(name)\nLet the magic appear toward \(name)."
        case .plane:    return "Set the plane on the runway toward \(name)\nWind it up, then let it fly with your thought."
        case .birthday: return "Light the candles for \(name)."
        case .firework: return "Light the fuse to send it toward \(name)."
        }
    }

    /// [tagline rework 2026-06-26] The SINGLE-LINE instrument tagline shown under the
    /// instrument — supersedes the 2-line `universalInstruction` block for the helper line.
    /// [name] = recipient (`compass.state.personName`). COMPASS is DYNAMIC — the ABSOLUTE
    /// bearing (`compass.rawBearingToTarget`, the same source as the B3 degree readout) — and
    /// returns nil to HIDE when there's no fix (seeded / Demo Dan / no GPS), matching the B3 /
    /// distance nil-hide rule. NB: the compass instrument shows the bearing line for ANY emoji,
    /// incl. the 🎂/🎆 sub-modes (it's still the compass — bearing is always relevant).
    private var instrumentTagline: String? {
        let name = compass.state.personName
        switch instrumentStore.selected {
        case .compass:
            guard let bearing = compass.rawBearingToTarget else { return nil }   // HIDE when seeded/no-GPS
            return "\(name) appears \(Int(bearing.rounded()))° away"
        case .bow:      return "Aiming toward \(name)…"
        case .firefly:  return "Float this toward \(name)…"
        case .flick:    return "Flicked toward \(name)…"
        case .rocket:   return "Fueling up to launch toward \(name)…"
        case .wand:     return "A little magic for \(name)…"
        case .plane:    return "Ready for takeoff toward \(name)…"
        case .birthday: return "Light the candles to send this to \(name)…"
        case .firework: return "Light the fuse to fire toward \(name)…"
        }
    }

    /// The instrument's own action verb, used once locked. (Kept for the
    /// compass hold flow + any heading-guidance callers.)
    private var instrumentAction: String {
        let name = compass.state.personName
        switch instrumentStore.selected {
        case .compass: return "hold toward \(name) to send"
        case .bow:     return "spin to aim, then draw toward \(name)"
        case .firefly: return "breathe into mic to send to \(name)"   // [wind-polish] wind — was "breathe to send to …"
        case .flick:   return "flick toward \(name) to send"
        case .rocket:  return "fuel the rocket toward \(name)"
        case .wand:    return "shake · release toward \(name)"
        case .plane:   return "wind it up, then let fly toward \(name)"
        case .birthday: return "light the candles for \(name)"
        case .firework: return "light the fuse for \(name)"
        }
    }

    /// Layer-1 text: cardinal sentence → turn hint → almost → locked·action.
    private var alignmentInstruction: String {
        // Simulator / indoors: no heading → skip the hunt, show the action
        guard compass.isHeadingAvailable else { return instrumentAction }
        let absolute: Double? = {
            guard let user = compass.userLocation,
                  let person = people.selectedPerson else { return nil }
            return BearingCalculator.bearing(from: user.coordinate,
                                             to: person.coordinate)
        }()
        return AlignmentText.guidance(relative: compass.state.bearingDegrees,
                                      absolute: absolute,
                                      personName: compass.state.personName,
                                      lockedAction: instrumentAction)
    }

    /// Renders an emoji token, the gecko, or a custom thought's emoji.
    @ViewBuilder
    private func sendSymbol(_ token: String, size: CGFloat) -> some View {
        if token == "gecko" {
            LeopardGeckoView(size: size * 1.2)
        } else if token.hasPrefix("yours:"),
                  let id = UUID(uuidString: String(token.dropFirst(6))),
                  let thought = customStore.thought(id: id) {
            Text(thought.emoji).font(.system(size: size))
        } else {
            Text(token).font(.system(size: size))
        }
    }

    private func sendRemoteEmoji(for token: String) -> String {
        if token == "gecko" { return "🦎" }
        if token.hasPrefix("yours:"),
           let id = UUID(uuidString: String(token.dropFirst(6))),
           let thought = customStore.thought(id: id) {
            return thought.emoji
        }
        return token
    }

    private func playSendSound(_ token: String) {
        if token.hasPrefix("yours:"),
           let id = UUID(uuidString: String(token.dropFirst(6))),
           let thought = customStore.thought(id: id) {
            customStore.play(thought)
        } else {
            SoundEngine.shared.play(for: token)
        }
    }

    // MARK: - [5/6] Send completion + arrival preview

    struct ArrivalPreviewData: Identifiable {
        let id = UUID()
        let emoji: String
        let style: SenderStyle
        let name: String
    }

    /// [5/6] One layer carrying the arrival preview, the "sent ✦" toast, and the
    /// keep-previews confirmation — bundled so the compass body stays within the
    /// SwiftUI type-checker's budget.
    private var sendFeedbackLayer: some View {
        ZStack(alignment: .top) {
            arrivalPreviewLayer
            sentNoticeToast
        }
        // [suppress reveal #1] RETIRED — the "Keep showing arrival previews?"
        // prompt is dead once the preview is gone (it was only triggered from
        // arrivalPreviewFinished after the 10th preview, now uncalled). Preserved:
        // .confirmationDialog("Keep showing arrival previews?",
        //                     isPresented: $showKeepPreviewPrompt, titleVisibility: .visible) {
        //     Button("Keep showing them") { arrivalPreviewEnabled = true }
        //     Button("Turn off", role: .destructive) { arrivalPreviewEnabled = false }
        // } message: {
        //     Text("You've seen 10 — a quick glimpse of what your person catches. You can change this anytime in Settings.")
        // }
    }

    @ViewBuilder
    private var arrivalPreviewLayer: some View {
        // [suppress reveal #1] RETIRED — the sender-side arrival-preview
        // presentation (the duplicate EmojiRevealView .sent) is removed. With
        // `finishSend` no longer setting `arrivalPreview`, this never presented;
        // it is now explicitly emptied. Preserved verbatim for restore:
        // if let preview = arrivalPreview {
        //     // [2/3] SENT CONFIRMATION — every instrument's send ends with the
        //     // ONE shared EmojiRevealView: context = .sent ("sent to [Name] ✦"),
        //     // ambient = the instrument's world. Same component as the receipt.
        //     EmojiRevealView(
        //         emoji: preview.emoji,
        //         message: sentMessage,
        //         tagline: sentTagline,
        //         context: .sent(recipientName: preview.name),
        //         ambient: RevealAmbient.forStyle(preview.style),
        //         onDismiss: { arrivalPreviewFinished() }
        //     )
        //     .transition(.opacity)
        // }
        EmptyView()
    }

    @ViewBuilder
    private var sentNoticeToast: some View {
        if sentNotice {
            // [sent-confirmation] Clearer post-send feedback: a soft check + "sent to
            // [Name] ✦" (falls back to "sent ✦" when there's no name). Larger + a touch
            // longer than the old faint toast, so the sender plainly sees it landed.
            // Reads for BOTH PATH-1 (direct) and PATH-2 (link) sends.
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#5dcaa5"))
                Text(sentToName.isEmpty ? "sent ✦" : "sent to \(sentToName) ✦")
                    .font(.system(size: 16, weight: .medium, design: .serif).italic())
                    .foregroundColor(Color(hex: "#c4a8d4"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(DesignTokens.Color.background.opacity(0.92))
                    .overlay(Capsule().stroke(Color(hex: "#c4a8d4").opacity(0.4), lineWidth: 1))
            )
            .padding(.top, 60)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// The flight finished. Either show a brief glimpse of the recipient's
    /// catch (the arrival preview), or just confirm "sent ✦".
    private func finishSend(emoji: String, style: SenderStyle) {
        // [suppress reveal #1] The sender-side arrival preview — the duplicate
        // EmojiRevealView(.sent) — is removed for ALL instruments. Every send now
        // ends with the "sent ✦" toast only; the emoji/message reveal happens once,
        // on the RECEIVER side (ReceiptView .received, untouched). This is the
        // single funnel — all 6 send-out onComplete closures call finishSend — so
        // gating here suppresses #1 everywhere. Original preserved below.
        // [sent-confirmation] Capture the recipient name before the toast so it can read
        // "sent to [Name] ✦" (the recipient is the selected person at send time).
        sentToName = people.selectedPerson?.name ?? ""
        showSentNotice()
        appState.transition(to: .idle)
        // [firework/birthday freeze fix] FireworkCompassFace + BirthdayCakeCompassFaceV2
        // hold one-way @State (`sent = true` after firing) and never self-reset. As
        // SELECTED instruments their face instance PERSISTS across sends → frozen after
        // one use. (The old emoji path cleared `selectedToken`, which destroyed+recreated
        // the face — the implicit reset that's now gone.) Bump `instrumentResetID` here —
        // `finishSend` is every send-out onComplete's terminal call, i.e. AFTER the send
        // flight has finished — so the face rebuilds fresh (lit/sent reset), restoring
        // exactly that reset. Gated to firework/birthday so no other instrument is touched.
        // [mechanism-reset PART 1] UNIFORM post-send reset. Every type-1/type-2 instrument
        // now rebuilds to a clean idle/ready state (was firework/birthday ONLY — that
        // asymmetry was the bug). Compass (type 3) is special-cased: it must keep its LIVE
        // bearing, so it does NOT rebuild — it disarms instead (compassArmed, added in PART 2).
        // "all type-1/2" == "!= .compass".
        if instrumentStore.selected != .compass {
            instrumentResetID += 1
        }
        // [restore-tap] compass (type 3) keeps its LIVE bearing — no rebuild. tapFace already
        // cleared compassAwaitingTap before sendThought, so nothing to reset here.
        // PRIOR (removed): else { compassArmed = false }   // [mechanism-reset PART 2] hysteresis disarm
        // PRIOR (firework/birthday only):
        // if instrumentStore.selected == .firework || instrumentStore.selected == .birthday {
        //     instrumentResetID += 1
        // }
        // [#1 share-on-animation-complete] The send flight has finished — signal PingManager
        // so a PATH-2 link send presents its share sheet NOW (or the instant the insert
        // returns, if still in flight). No-op for PATH-1 / demo sends (no pending link).
        pings.markSendAnimationComplete()
        // PRIOR — sender-side arrival preview (reveal #1), now suppressed:
        // if arrivalPreviewEnabled {
        //     arrivalPreviewCount += 1
        //     let recipient = people.selectedPerson?.name ?? "them"
        //     arrivalPreview = ArrivalPreviewData(emoji: emoji, style: style, name: recipient)
        //     // The preview view calls back when its glimpse ends.
        // } else {
        //     showSentNotice()
        //     appState.transition(to: .idle)
        // }
    }

    // [suppress reveal #1] RETIRED — the arrival-preview completion handler is
    // now uncalled (its only caller was arrivalPreviewLayer's onDismiss, removed).
    // It also drove the "Keep showing arrival previews?" prompt (now dead too).
    // Preserved verbatim for restore:
    // /// Called when the arrival preview finishes its ~2.5 s glimpse.
    // private func arrivalPreviewFinished() {
    //     arrivalPreview = nil
    //     showSentNotice()
    //     appState.transition(to: .idle)
    //     // After the 10th preview, ask whether to keep showing them.
    //     if arrivalPreviewCount == 10 {
    //         DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
    //             showKeepPreviewPrompt = true
    //         }
    //     }
    // }

    private func showSentNotice() {
        withAnimation(.easeOut(duration: 0.3)) { sentNotice = true }
        // [sent-confirmation] a touch longer (1.6 → 2.2s) so the clearer "sent to [Name]"
        // reads comfortably before it fades.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.4)) { sentNotice = false }
        }
    }

    /// The send: styled flight in the real compass direction, sound, clear.
    /// SenderAnimationView owns the haptics and the style voice; the
    /// thought's own sound still plays here.
    private func sendThought(_ token: String) {
        // [§C PART 2] REAL sends require a signed-in identity (insertMessage throws
        // .notSignedIn without localUserID). Not signed-in → route to onboarding (reuse
        // ComposeBackView, no new screen) — never a silent no-op. EXEMPT Demo Dan: the
        // un-onboarded try-it sandbox is LOCAL-ONLY (the demo branch below writes no DB)
        // and MUST stay open. Returns BEFORE appState.transition/animation, so a blocked
        // send can't half-fire; a signed-in user falls straight through unchanged.
        if SupabaseService.localUserID == nil && !isDemoSelected {
            CompassView.log.info("send: blocked — not signed in → onboarding (§C view-only)")
            routeToOnboardingForSend()
            return
        }
        // One state at a time — a catch in progress owns the screen
        guard appState.transition(to: .sending) else {
            // The gesture succeeded but the screen is owned (catch mode) —
            // never lose the moment silently; the selection stays loaded.
            CompassView.log.warning("send: blocked by app state \(appState.currentState.rawValue, privacy: .public) — try again when free")
            return
        }
        // [3/6] NO emoji sound on send — only the INSTRUMENT sound plays during
        // the flight (the style voice in SenderAnimationView + each instrument's
        // own sounds). The emoji's own sound is reserved for the REVEAL moment
        // on the recipient's side (ReceiptView), firing with the reveal haptic.
        // Compass/glow has no style voice of its own, so give it a soft whoosh.
        if instrumentStore.selected.senderStyle == .glow {
            SoundEngine.shared.play(for: "style.whoosh")
        }
        // [5/5] Capture the note before clearing the field, so it rides along.
        let outgoingMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        // [2/3] Capture what was sent for the sent-confirmation reveal.
        sentMessage = outgoingMessage.isEmpty ? nil : outgoingMessage
        sentTagline = people.selectedPerson?.tagline
        withAnimation(.easeOut(duration: 0.25)) { selectedToken = nil }
        messageFocused = false
        messageText = ""
        messageEdited = false                    // [custom-text lock] per-send reset
        flightToken = token
        flightFly = true   // legacy flag (the style view drives its own motion)

        // [4/4] The compass face pulses once as the thought launches — even
        // the free instrument feels alive and powerful.
        if instrumentStore.selected == .compass {
            faceSendPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { faceSendPulse = false }
        }

        // ONE SELECTION DEFINES EVERYTHING: the flight personality follows
        // the chosen instrument (compass→glow, bow→bowArrow, firefly→firefly,
        // flick→fingerFlick). Free users hold the compass, so glow.
        let style = instrumentStore.selected.senderStyle
        if style == .fingerFlick || style == .bowArrow || style == .rocket {
            faceDimmedForInstrument = true
            // The rocket's blast-off owns the whole screen for ~3.4 s
            let restoreDelay: Double = style == .rocket ? 3.4
                                     : style == .bowArrow ? 1.5 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                faceDimmedForInstrument = false
            }
        }
        // HapticEngine.thoughtReleased()   // retired — style haptic fires at launch

        // [phase2 stage A] LEGACY direct send (sendRemote → pings) COMMENTED OUT to
        // remove the double-send once the link send below is un-gated. This is
        // PATH-1's channel — it returns (re-keyed pairedUserID → senderID) in Stage C,
        // for CONNECTED contacts only. Until then a send is LINK-ONLY (PATH 2).
        // (pings.sendRemote stays DEFINED in PingManager — it just has no caller here.)
        // let recipient = people.selectedPerson?.pairedUserID.flatMap(UUID.init)
        //                 ?? SupabaseService.connectedFriendID
        // if let recipient {
        //     CompassView.log.info("send: \(token) → \(recipient.uuidString) as \(style.rawValue)")
        //     pings.sendRemote(to: recipient,
        //                      emoji: sendRemoteEmoji(for: token),
        //                      style: style,
        //                      message: outgoingMessage.isEmpty ? nil : outgoingMessage,
        //                      tagline: people.selectedPerson?.tagline)
        // } else {
        //     CompassView.log.info("send: local only — no paired recipient")
        // }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            playSendSound(token)
            // HapticEngine.thoughtLaunched()   // retired — single .light at launch
        }

        // [#2 demo local-only] Demo Dan NEVER sends for real. The send animation above
        // plays as usual; instead of inserting a message + building a link, inject the
        // receipt LOCALLY via the existing test-playback path (isTest → never deduped/
        // persisted server-side; remoteID nil → markOpened makes NO Supabase call). While
        // appState == .sending the catch is QUEUED and plays the instant the send animation
        // completes (PingManager's simultaneous-send/receive ordering). NO insert, NO link,
        // NO share sheet, NO SentLink — zero DB writes. Returns before the two-path send.
        if let demo = people.selectedPerson, DemoPerson.isDemo(demo) {
            CompassView.log.info("send: DEMO local-only preview — no insert, no link, no share")
            pings.receivePing(
                fromName:    demo.name,
                emoji:       sendRemoteEmoji(for: token),
                remoteID:    nil,
                senderStyle: style.rawValue,
                message:     outgoingMessage.isEmpty ? nil : outgoingMessage,
                tagline:     demo.tagline,
                isTest:      true,
                autoPlay:    true)
            return
        }

        // [phase2 stage C] TWO-PATH SEND — mutually exclusive (NO double-send). The
        // animation above has ALREADY fired (sacred, never blocked).
        //   PATH 1 — CONNECTED contact (senderID stamped by Stage B = a real users.id)
        //            → DIRECT delivery on the existing pings channel, RE-KEYED to
        //            senderID. Lands in their Pointward + push. NO link, NO share sheet.
        //   PATH 2 — not-yet-connected → the link + share sheet (Stage A), recording
        //            the (S1) SentLink so the connection can later stamp the contact.
        // (The old unconditional sendRemote block above stays commented — this is the
        //  NEW, conditional, senderID-keyed direct send.)
        if let sid = people.selectedPerson?.senderID,
           let rid = UUID(uuidString: sid) {
            CompassView.log.info("send: PATH 1 (direct) \(token, privacy: .public) → \(rid.uuidString, privacy: .public) as \(style.rawValue, privacy: .public)")
            pings.sendRemote(to: rid,
                             emoji: sendRemoteEmoji(for: token),
                             style: style,
                             message: outgoingMessage.isEmpty ? nil : outgoingMessage,
                             tagline: people.selectedPerson?.tagline)
        } else {
            // PATH 2 — link send (sender-keyed; recipient is whoever opens the link).
            let cid = people.selectedPerson?.id   // capture BEFORE the async callback
            CompassView.log.info("send: PATH 2 (link) \(token, privacy: .public) — not-yet-connected")
            pings.createAndShareLink(
                content: outgoingMessage.isEmpty ? nil : outgoingMessage,
                emoji: sendRemoteEmoji(for: token),
                instrument: style.rawValue,                   // wire style (matches pings.sender_style)
                senderName: people.profile?.displayName ?? UserProfile.snapshot?.displayName ?? "",
                shortCode: people.profile?.shortCode.nilIfEmpty
                           ?? UserProfile.snapshot?.shortCode ?? "",
                personID: cid,
                onStored: { id in
                    if let cid { people.recordSentLink(messageID: id, personID: cid) }
                })
        }
        // Cleanup moved to SenderAnimationView.onComplete (duration varies by style)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
        //     flightToken = nil
        //     flightFly = false
        // }
    }

    // MARK: - Compass face

    private var compassFace: some View {
        ZStack {
            // ── [2/6] REAL COMPASS: the rose ROTATES with the phone so N
            // always points to true north (faceRotation = -heading). The
            // needle keeps pointing at the person; the user turns the phone
            // until the needle points up. ──
            Group {
                // Skin-specific rings and decorations
                SkinFaceView(
                    skin: compass.state.activeSkin,
                    bearing: compass.state.bearingDegrees,
                    locked: compass.state.isLocked,
                    quietMode: quietMode,
                    pingRingActive: pingRingActive
                )

                // Cardinal markers ride the rose (just inside the ring)
                ForEach(0..<4, id: \.self) { i in
                    let rad = Double(i) * 90 * .pi / 180
                    Text(["N", "E", "S", "W"][i])
                        .font(.system(size: 9, weight: i == 0 ? .semibold : .regular, design: .rounded))
                        .foregroundColor(i == 0
                                         ? DesignTokens.Color.accentSoft.opacity(0.9)
                                         : DesignTokens.Color.textDim.opacity(0.7))
                        .offset(x: CGFloat(sin(rad)) * 113, y: -CGFloat(cos(rad)) * 113)
                }
            }
            // The rose card spins to keep N pointing at real-world north.
            .rotationEffect(.degrees(compass.state.faceRotationDegrees))
            .animation(.easeOut(duration: 0.18), value: compass.state.faceRotationDegrees)

            // [§B5] Fixed RED INDEX MARK (lubber line) at top-center — the reference you turn the
            // person's bearing under to aim. FIXED on screen (OUTSIDE the rotating rose). Vintage only.
            if compass.state.activeSkin == .vintage {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .offset(y: -123)            // just above the bezel, top-center (device-tunable)
                    .allowsHitTesting(false)
            }

            // Emoji presence system — always at center, never rotates
            emojiPresence

            // Needle — points at the person. On the spinning rose its mark
            // sits at the absolute bearing; on screen that lands at the
            // relative bearing (bearing - heading), so it points up when
            // the phone faces them. (Shared geometry, skin-tinted colours.)
            NeedleView(
                bearing: compass.state.bearingDegrees,
                skin: compass.state.activeSkin,
                locked: compass.state.isLocked,
                quietMode: quietMode
            )

            // Pivot dot — soft glow on the heart skin
            Circle()
                .fill(pivotColor)
                .frame(width: 10, height: 10)
                .shadow(color: pivotGlow, radius: 4)
                .zIndex(4)
        }
    }

    // MARK: - Emoji presence

    private var emojiPresence: some View {
        ZStack {
            // Glow disc behind emoji
            Circle()
                .fill(glowColor.opacity(glowOpacity))
                .frame(width: 68, height: 68)
                .animation(
                    quietMode
                        ? .easeInOut(duration: 1.0)
                        : AnimationSystem.pingGlow,
                    value: lockGlowActive || pingRingActive
                )
                .zIndex(2)

            // Emoji — scales up on lock, crossfades on person switch
            Text(compass.state.personEmoji)
                .font(.system(size: 28))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: compass.state.personEmoji)
                .scaleEffect(emojiScaled ? 1.2 : 1.0)
                .animation(
                    quietMode
                        ? .easeInOut(duration: 0.6)
                        : AnimationSystem.pingBurst,
                    value: emojiScaled
                )
                .zIndex(3)
        }
    }

    // MARK: - Lock badge

    private var lockBadge: some View {
        HStack(spacing: 4) {
            if lockBadgeShown {
                Text("locked ✦")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#c4a8d4").opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#c4a8d4").opacity(0.3), lineWidth: 1))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeOut(duration: 0.4), value: lockBadgeShown)
        .frame(height: 22)
    }

    // MARK: - Bearing readout

    private var bearingReadout: some View {
        Text("\(Int(compass.state.bearingDegrees.rounded()))°")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(DesignTokens.Color.textDim)
            .monospacedDigit()
    }

    // MARK: - Computed styling

    private var glowColor: Color {
        switch compass.state.activeSkin {
        case .aurora:    return Color(hex: "#5dcaa5")
        case .heart:     return Color(hex: "#c4a8d4")
        default:         return Color(hex: "#9b7fc0")
        }
    }

    private var glowOpacity: Double {
        if pingRingActive          { return quietMode ? 0.18 : 0.35 }
        if lockGlowActive          { return quietMode ? 0.12 : 0.25 }
        return 0
    }

    private var pivotColor: Color {
        switch compass.state.activeSkin {
        case .aurora: return Color(hex: "#1D9E75")
        case .heart:  return Color(hex: "#e0a8c8")
        default:      return DesignTokens.Color.accentMid
        }
    }

    private var pivotGlow: Color {
        compass.state.activeSkin == .heart
            ? Color(hex: "#e0a8c8").opacity(0.8)
            : .clear
    }

    // MARK: - Event handlers

    private func handleLock(_ locked: Bool) {
        guard !quietMode || locked else { return } // quiet mode: allow lock-on, skip unlock animation
        // [5/5] COMPASS — a single satisfying medium tap as the needle locks.
        if locked && instrumentStore.selected == .compass { HapticEngine.compassLock() }
        withAnimation(AnimationSystem.pingBurst) {
            emojiScaled    = locked
            lockGlowActive = locked
        }
        withAnimation(.easeOut(duration: 0.4).delay(locked ? 0.15 : 0)) {
            lockBadgeShown = locked
        }
        // Auto-dismiss lock glow after 4 seconds so it doesn't linger
        // (the brief-point flash: lock → quick glow → fades)
        if locked {
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { lockGlowActive = false }
            }
            // STEADY LOCK: held for 5+ seconds → the needle breathes warmer
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if compass.state.isLocked {
                    withAnimation(.easeIn(duration: 1.0)) { steadyLock = true }
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        breathePulse = true
                    }
                }
            }
            // [copy-declutter ITEM 7] Shareable moment disabled for v1 (preserved):
            // shareCard = renderShareCard()
            // withAnimation(.easeIn(duration: 0.5).delay(0.8)) { showShareMoment = true }
            // Task {
            //     try? await Task.sleep(nanoseconds: 8_000_000_000)
            //     withAnimation(.easeOut(duration: 0.6)) { showShareMoment = false }
            // }
        } else {
            withAnimation(.easeOut(duration: 0.5)) { steadyLock = false }
            withAnimation(.easeOut(duration: 0.3)) {
                // [copy-declutter ITEM 7] showShareMoment = false
                breathePulse = false
            }
        }
    }

    // MARK: - Ambient presence glow

    // [9b · B4] presenceGlow (the mutual-pointing edge-glow visual) REMOVED — it was
    // only rendered by the deleted presenceGlowVisible/onChange path, which never fired.

    // MARK: - [1/6] Thought history on the compass

    /// [3/5] Top-left icon — a soft lavender sparkle cluster. Pulses gently
    /// when thoughts exist, dims to 20 % when none, carries an unread badge.
    private var thoughtsIcon: some View {
        Button {
            guard thoughtsLoaded else { return }
            HapticEngine.personSelected()
            withAnimation(AnimationSystem.easeOutCubic(0.4)) { showThoughtsDrawer = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                // [3/5] A bucket — the home for caught thoughts (was a sparkle).
                Image(systemName: "basket.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "#c4a8d4"))
                    .frame(width: 44, height: 44)           // 44pt tap target
                    // [7/7] Clearly visible on every instrument screen — soft
                    // when empty (0.55), full + pulsing when thoughts exist.
                    .opacity(hasThoughts ? 1.0 : 0.55)
                    .scaleEffect(hasThoughts && thoughtsIconPulse ? 1.05 : 0.95)
                    .shadow(color: Color(hex: "#c4a8d4").opacity(hasThoughts ? 0.5 : 0.2), radius: 6)
                if pings.unreadCount > 0 {                  // unread badge
                    Text("\(pings.unreadCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#c4a8d4")))
                        .offset(x: 8, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.top, 8)            // [3/5] just below the navigation bar
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(3.0).repeatForever(autoreverses: true)) {
                thoughtsIconPulse = true
            }
        }
    }

    /// Scrim + the upward-sliding drawer.
    @ViewBuilder private var thoughtsDrawerLayer: some View {
        if showThoughtsDrawer {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(AnimationSystem.easeOutCubic(0.3)) { showThoughtsDrawer = false }
                    }
                thoughtsDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// [4/4] Unread thoughts float to the top (newest within each group); read
    /// thoughts settle below, slightly dimmer.
    private var sortedThoughts: [SupabaseService.PingRecord] {
        compassThoughts.sorted { a, b in
            let au = a.openedAt == nil, bu = b.openedAt == nil
            if au != bu { return au }            // unread first
            return a.createdAt > b.createdAt     // newest within each group
        }
    }

    private var thoughtsDrawer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("your bucket ✦")
                .font(.system(size: 15, design: .serif).italic())
                .foregroundColor(Color(hex: "#c4a8d4"))
                .padding(.leading, 4)
            if compassThoughts.isEmpty {
                Text(thoughtsLoaded ? "all caught up ✦" : "loading…")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.vertical, 12)
            } else {
                // Max 6 fit; more scroll horizontally. Unread first, then read.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(Array(sortedThoughts.prefix(12)), id: \.id) { rec in
                            thoughtBubble(rec)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24)
            .stroke(DesignTokens.Color.borderMid, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func thoughtBubble(_ rec: SupabaseService.PingRecord) -> some View {
        let hue = EmojiHue.color(for: rec.emoji)
        let unread = rec.openedAt == nil   // [4/4]
        return Button {
            replayThought(rec)
        } label: {
            VStack(spacing: 6) {
                // [4/4] Unread bubbles wear a small lavender "new ✦" badge.
                ZStack(alignment: .topTrailing) {
                    Text(rec.emoji)
                        .font(.system(size: 32))
                        .shadow(color: hue.opacity(0.7), radius: 8)
                        .padding(.top, 4)
                    if unread {
                        Text("new ✦")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color(hex: "#c4a8d4")))
                            .offset(x: 12, y: -2)
                    }
                }
                // Sender initial (the person this compass points at)
                Text(String(compass.state.personName.prefix(1)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(hue.opacity(0.25)))
                // Instrument-style indicator
                Text(SenderStyle.from(rec.senderStyle).emoji)
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
            .frame(width: 56)
            .opacity(unread ? 1.0 : 0.7)   // [4/4] read thoughts settle dimmer
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    /// "from [name] · [time ago]" — fades in after a replay finishes.
    @ViewBuilder private var replayCaptionView: some View {
        if let replayCaption {
            Text(replayCaption)
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Color(hex: "#c4a8d4"))
                .padding(.top, 74)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    /// Dismiss the drawer, then replay the memory ON the compass — in the
    /// original sender's instrument style, while the compass points toward
    /// that person. The most emotional moment in the app.
    private func replayThought(_ rec: SupabaseService.PingRecord) {
        withAnimation(AnimationSystem.easeOutCubic(0.3)) { showThoughtsDrawer = false }
        // [build9] Sender-agnostic bucket → attribute to the item's OWN sender,
        // falling back to the tracked person only when the record carries no name.
        pendingReplayCaption = "from \(rec.fromName ?? compass.state.personName) · \(Self.timeAgo(rec.createdAt))"
        // [swipe] Pass the FULL sorted list (unread-first) so the replay can
        // swipe between thoughts; start at the tapped one.
        let list = sortedThoughts
        let start = list.firstIndex(where: { $0.id == rec.id }) ?? 0
        let items = list.map {
            PingManager.ReplayItem(emoji: $0.emoji,
                                   bearingDegrees: compass.state.bearingDegrees,
                                   styleRaw: $0.senderStyle,
                                   fromName: $0.fromName ?? compass.state.personName,
                                   message: $0.message,        // AUDIT [5/6]
                                   tagline: $0.tagline,
                                   historyID: $0.id)           // [bucket delete] PingRecord.id == caughtHistory's (remoteID ?? id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            pings.requestReplaySequence(items, startIndex: start)
        }
    }

    /// [build9] The UNIFIED, SENDER-AGNOSTIC bucket: EVERY thought sent to you,
    /// newest first — regardless of the currently-selected person. Built purely
    /// from LOCAL `caughtHistory` (capped 50): there is NO server "messages sent to
    /// me" query (the `messages` table is sender-keyed, no recipient column), so the
    /// old `fetchPings(with: pairedUserID)` server call + the per-person
    /// `fromName == selectedPerson` filter are both GONE. /m/ opens (build 9),
    /// short-code claims, and legacy pings all record into `caughtHistory`, so this
    /// local set is now the complete record. `isTest` dev thoughts still pass.
    private func loadCompassThoughts() async {
        let me = SupabaseService.localUserID ?? UUID()
        compassThoughts = pings.caughtHistory
            .map { rp -> SupabaseService.PingRecord in
                let id = rp.remoteID ?? rp.id
                return SupabaseService.PingRecord(
                    id: id, fromUser: me, toUser: me, emoji: rp.emoji,
                    createdAt: rp.timestamp, openedAt: rp.timestamp,
                    senderStyle: rp.senderStyle, message: rp.message,
                    tagline: rp.tagline,
                    fromName: rp.fromName)   // each item keeps its OWN sender
            }
            .sorted { $0.createdAt > $1.createdAt }
        thoughtsLoaded = true
    }

    private static func timeAgo(_ date: Date) -> String {
        let s = Int(Date.now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3_600 { return "\(s / 60)m ago" }
        if s < 86_400 { return "\(s / 3_600)h ago" }
        return "\(s / 86_400)d ago"
    }

    // MARK: - Share card

    // [copy-declutter ITEM 7] Share-card renderer disabled for v1 (preserved).
    /*
    /// Renders the shareable compass moment as an image.
    private func renderShareCard() -> Image? {
        guard let person = people.selectedPerson else { return nil }
        let card = ShareCardView(
            personName: person.name,
            emoji: person.emoji,
            bearing: compass.state.bearingDegrees,
            distance: compass.state.formattedDistance,
            tagline: TaglineSystem.poeticLibrary[taglineIndex]
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
    */

    private func handlePersonChange() {
        compassReadyAt = .now   // [compass-grace] new aim context → restart the no-auto-fire window
        compassArmed = false    // and disarm, so switching to a person you're already pointed at can't fire
        // Re-trigger tagline fade-out → fade-in
        withAnimation {
            taglineKey = UUID()
        }
        // Reset lock state for new person
        withAnimation {
            lockGlowActive = false
            emojiScaled    = false
            lockBadgeShown = false
        }
    }

}

// MARK: - Notifications

extension Notification.Name {
    /// [6/6] Posted by the "✦ Pro" badge — MainTabView jumps to the Pro tab.
    static let pointwardOpenPro = Notification.Name("pointwardOpenPro")
    /// Posted by the "✦ Pro" badge — MainTabView jumps to Settings.
    static let pointwardOpenSettings = Notification.Name("pointwardOpenSettings")
    /// Posted by the send-a-thought pill — MainTabView jumps to Thoughts.
    static let pointwardOpenThoughts = Notification.Name("pointwardOpenThoughts")
    /// Posted when a notification-opened catch needs the compass on screen.
    static let pointwardOpenCompass = Notification.Name("pointwardOpenCompass")
    /// Posted before an app-wide replay so presenting sheets close first.
    static let pointwardCloseSheetsForReplay = Notification.Name("pointwardCloseSheetsForReplay")
}








// MARK: - Preview

#Preview {
    CompassView()
        .environmentObject(ServiceContainer().compassManager)
        .environmentObject(ServiceContainer().peopleManager)
        .environmentObject(ServiceContainer().pingManager)
        .environmentObject(ServiceContainer().skinStore)
        .environmentObject(ServiceContainer().subscriptionManager)
        .environmentObject(ServiceContainer().appStateManager)
        .preferredColorScheme(.dark)
}
