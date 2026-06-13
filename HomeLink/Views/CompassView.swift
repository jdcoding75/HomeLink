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

    // Discovery hint — "tap the words to change them", first three launches
    @AppStorage("discoveryHintCount") private var discoveryHintCount = 0
    @State private var showDiscoveryHint = false

    // Person switcher sheet (tap the name)
    @State private var showPersonSwitcher = false

    // Ambient presence — partner's needle resting on us → edge glow
    @State private var presenceGlowVisible = false

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
    @State private var showShareMoment = false
    @State private var shareCard: Image? = nil

    // Bottom-zone distance line: 0 standard · 1 funny (Pro) · 2 light speed
    @State private var distanceMode = 0

    // Face interactions — tap pulse + brief bearing readout, long-press skins
    @State private var faceTapPulse = false
    @State private var bearingFlash = false
    @State private var showSkinOverlay = false
    @State private var showSkinPaywall = false
    @State private var showConnectSheet = false
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
    @State private var longPressLabel: String? = nil        // [1/3] curated-emoji label on long-press
    @State private var loadFlightToken: String? = nil       // [1/5] load flight
    @State private var loadFlightProgress: CGFloat = 0
    @State private var flightToken: String? = nil
    // [5/6] Arrival preview — a brief glimpse of the recipient's catch.
    @AppStorage("arrivalPreviewEnabled") private var arrivalPreviewEnabled = true
    @AppStorage("arrivalPreviewCount")   private var arrivalPreviewCount   = 0
    @State private var arrivalPreview: ArrivalPreviewData? = nil
    @State private var sentMessage: String? = nil   // [2/3] for the sent confirmation
    @State private var sentTagline: String? = nil
    @State private var sentNotice = false
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
    private let holdTick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var holdToSendActive: Bool {
        holdToSendEnabled && subscription.tier != .free
    }
    private var sendAlignDiff: Double {
        BearingCalculator.alignmentError(relativeBearing: compass.state.bearingDegrees)
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
            let aimed = compass.isHeadingAvailable ? sendAlignDiff <= 15 : true
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

            if people.people.isEmpty {
                // ── Warm empty state — no one to point toward yet ────────────
                emptyState
            } else {
                VStack(spacing: 0) {
                    // ── TOP ZONE: name, then distance right under it ──────────
                    nameHeader
                        .padding(.top, 16)

                    distanceLine
                        .padding(.top, 6)

                    Spacer(minLength: 12)

                    // ── MIDDLE ZONE: the compass, dominant, nothing on it ─────
                    // Skins render at a fixed 240pt design size; scale the whole
                    // composition so every face grows together.
                    // ── FOUR INSTRUMENTS: only the middle changes ─────────
                    Group {
                        switch instrumentStore.selected {
                        case .compass:
                            // [birthday] When 🎂 is the selected emoji, the
                            // compass face becomes the special tap-the-candles
                            // birthday send mechanic; otherwise the normal face.
                            if (selectedToken.map { sendRemoteEmoji(for: $0) }) == "🎂" {
                                // [birthday V2] HERO — tap each candle to LIGHT it.
                                // (V1 BirthdayCakeCompassFace kept as fallback.)
                                BirthdayCakeCompassFaceV2(
                                    bearingDegrees: compass.state.bearingDegrees,
                                    personName: compass.state.personName,
                                    onSend: { if let token = selectedToken { sendThought(token) } }
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
                                    onSend: { if let token = selectedToken { sendThought(token) } }
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
                        case .bow:
                            BowInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onSend: { if let token = selectedToken { sendThought(token) } }
                            )
                        case .firefly:
                            // 🌬️ WIND — replaced the firefly (same mechanic as
                            // compass made it redundant; view kept in the repo)
                            WindInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onSend: { if let token = selectedToken { sendThought(token) } }
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
                                emoji: selectedToken.map { sendRemoteEmoji(for: $0) } ?? "💜",
                                bearingDegrees: compass.state.bearingDegrees,
                                onSend: { if let token = selectedToken { sendThought(token) } },
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
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 24)) },
                                loadedEmoji: selectedToken.map { sendRemoteEmoji(for: $0) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onLaunch: { if let token = selectedToken { sendThought(token) } }
                            )
                        case .wand:
                            // 🪄 WAND — load into the crystal, shake to charge,
                            // release at full charge within 15°. Owns its own
                            // mechanic, then fires the shared send pipeline.
                            WandInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 22)) },
                                loadedEmoji: selectedToken.map { sendRemoteEmoji(for: $0) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onSend: { if let token = selectedToken { sendThought(token) } }
                            )
                        case .plane:
                            // ✈️ PLANE — wind the propeller (8 winds), let fly.
                            // Owns its winding mechanic, then fires the send pipeline. [3/5]
                            PlaneInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 22)) },
                                loadedEmoji: selectedToken.map { sendRemoteEmoji(for: $0) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                personEmoji: compass.state.personEmoji,
                                onLaunch: { if let token = selectedToken { sendThought(token) } }
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
                    // [2/5] STEP PROGRESS — dots beneath the instrument tracking
                    // where you are in the send.
                    .overlay(alignment: .bottom) {
                        StepProgressView(instrument: instrumentStore.selected,
                                         currentStep: instrumentStep)
                            .offset(y: 22)
                            .opacity(pings.nowPlaying == nil ? 1 : 0)
                    }
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
                        // [2/6] SIMULTANEOUS long-press → instrument picker, so it
                        // fires on EVERY instrument even when the instrument owns
                        // its own drag gesture (e.g. the plane's circular swirl).
                        // A still 0.5 s press opens the picker; any rotation feeds
                        // the swirl instead — no conflict.
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    HapticEngine.personSelected()
                                    withAnimation(.easeOut(duration: 0.3)) { showSkinOverlay = true }
                                }
                        )

                    Spacer(minLength: 12)

                    // ── BOTTOM ZONE: distance · funny · tagline · emojis ──────
                    bottomZone
                        .padding(.top, 24)

                    // ── Catch badge — "X thoughts waiting ✦", every tier ──
                    if pings.queueCount > 0 && pings.nowPlaying == nil {
                        CatchBadgeView(count: pings.queueCount) {
                            pings.playNext()
                        }
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // The six, always visible — sending lives right here.
                    // The gap above equals one tagline line height (26pt):
                    // the tagline breathes clearly, not crowded, not far.
                    emojiRow
                        .padding(.top, pings.queueCount > 0 && pings.nowPlaying == nil ? 8 : 26)
                        // The catch owns the screen — the row recedes to 30 %
                        .opacity(appState.currentState == .catchMode ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3),
                                   value: appState.currentState == .catchMode)

                    // [1/6] The separate message box below the emojis is GONE —
                    // the message now lives in the ONE zone above the emoji row
                    // (bottomZone), replacing the tagline when a feeling is loaded.

                    sendControl
                        .padding(.top, 10)
                        .padding(.bottom, 12)

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
                    if previewEmoji == "🎆" {
                        // [firework] 🎆 is a SPECIAL emoji send — the spectacular
                        // deep-space launch → small pops → massive burst → embers,
                        // shown for ANY instrument, then back to the pipeline.
                        FireworkSendAnimation(
                            emoji: previewEmoji,
                            onComplete: {
                                flightToken = nil
                                flightFly   = false
                                finishSend(emoji: previewEmoji, style: previewStyle)
                            })
                    } else if previewEmoji == "🎂" {
                        // [birthday V2] 🎂 is a SPECIAL emoji send — the cake +
                        // confetti burst, shown for ANY instrument, then back to
                        // the pipeline (no EmojiRevealView here).
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

            // ── Ambient presence — their needle is resting on us ──────────────
            if presenceGlowVisible {
                presenceGlow
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

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
        .onChange(of: pings.partnerPointingAt) { _, stamp in
            guard stamp != nil else { return }
            // Mutual: we're locked on them while they rest on us — always honored.
            if compass.state.isLocked {
                HapticEngine.connectionFelt()
            }
            // [2/6] Ambient presence is ALWAYS ON, but the visible glow is a
            // once-per-person-per-day surprise — never annoying, always welcome.
            // Resets at local midnight. (Bearing/timestamp already updated for
            // the mutual-pointing check regardless.)
            let key = "lastAmbientGlow_\(pings.partnerPointingName)"
            let last = UserDefaults.standard.object(forKey: key) as? Date
            if let last, Calendar.current.isDate(last, inSameDayAs: .now) { return }
            UserDefaults.standard.set(Date.now, forKey: key)
            withAnimation(.easeIn(duration: 1.2)) { presenceGlowVisible = true }
            // The glow breathes for a while, then drifts away
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
                withAnimation(.easeOut(duration: 2.0)) { presenceGlowVisible = false }
            }
        }
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
        .task(id: people.selectedPerson) { await loadCompassThoughts() }
        .onChange(of: pings.queueCount) { _, _ in
            Task { await loadCompassThoughts() }   // a new thought just landed
        }
        .onChange(of: pings.caughtHistory.count) { _, _ in
            Task { await loadCompassThoughts() }   // [2/5] a thought was caught → history
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
            guard instrumentStore.selected == .compass,
                  let token = selectedToken, flightToken == nil else {
                if holdProgress > 0 { holdProgress = 0 }
                return
            }
            // [3/5] SOFT LOCK — the hold STARTS within 15°, but once it has
            // begun it tolerates drift up to 30° (hysteresis), so a small
            // wobble of the phone never breaks the lock or freezes the hold.
            let holding = holdProgress > 0
            if sendAlignDiff <= 15 || (holding && sendAlignDiff <= 30) {
                holdProgress += 0.05 / holdDuration
                if holdProgress >= 1.0 {
                    holdProgress = 0
                    HapticEngine.compassSend()      // [5/5] gentle double tap
                    sendThought(token)
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
            if let person = people.selectedPerson {
                compass.start(tracking: person)
            }
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
                guard people.people.count > 1 else { return }
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
    }

    /// [5/6] True when the compass is showing the auto-created demo person (Alex).
    private var isDemoSelected: Bool {
        people.selectedPerson.map(DemoPerson.isDemo) ?? false
    }

    // ── BOTTOM ZONE ───────────────────────────────────────────────────────

    /// The mode line 1 cycles through: standard → funny (Pro) → light speed.
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
    private func tapFace() {
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

                    // Suggested alternatives for this feeling — tap to use.
                    Text("or tap a suggestion")
                        .font(DesignTokens.Font.overline)
                        .foregroundColor(DesignTokens.Color.textMuted)
                    let options = composeSuggestions(for: token)
                    VStack(spacing: 6) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                messageText = MessageRules.clamped(option)
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
    private func seedMessage(for item: CuratedEmoji.Item) -> String {
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
                composing = false               // [5/7] close the message editor
                messageFocused = false
                HapticEngine.personSelected()
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { selectedToken = item.emoji }
                // [3/3] Auto-fill the warm default message (user can edit/clear).
                // [hints 2026-06-13] seedMessage falls back to the instrument's
                // TaglineSystem hint when the emoji has no curated default.
                messageText = MessageRules.clamped(seedMessage(for: item))
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
        loadFlightToken = nil
        loadFlightProgress = 0
        messageFocused = false                   // [5/7] close the message editor
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

    @ViewBuilder
    private var sendControl: some View {
        if pings.nowPlaying != nil {
            EmptyView()
        } else if selectedToken == nil {
            Text("tap a feeling below to load")
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

    /// Per-instrument step guide, shown once a feeling is loaded. The "loaded"
    /// step is checked; the rest are the steps to send.
    private var universalInstruction: String {
        // [4/6] The full step flow per instrument: emoji · message · …action.
        switch instrumentStore.selected {
        case .compass: return "choose emoji · message · point · hold"
        case .bow:     return "choose emoji · message · aim · draw · release"
        case .firefly: return "choose emoji · message · breathe"          // wind
        case .flick:   return "choose emoji · message · flick"
        case .rocket:  return "choose emoji · message · aim · fuel · blast"
        case .wand:    return "choose emoji · message · shake · release"
        case .plane:   return "choose emoji · message · wind · fly"
        }
    }

    /// The instrument's own action verb, used once locked. (Kept for the
    /// compass hold flow + any heading-guidance callers.)
    private var instrumentAction: String {
        let name = compass.state.personName
        switch instrumentStore.selected {
        case .compass: return "hold toward \(name) to send"
        case .bow:     return "spin to aim, then draw toward \(name)"
        case .firefly: return "breathe to send to \(name)"   // wind
        case .flick:   return "flick toward \(name) to send"
        case .rocket:  return "fuel the rocket toward \(name)"
        case .wand:    return "shake · release toward \(name)"
        case .plane:   return "wind it up, then let fly toward \(name)"
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
        .confirmationDialog("Keep showing arrival previews?",
                            isPresented: $showKeepPreviewPrompt, titleVisibility: .visible) {
            Button("Keep showing them") { arrivalPreviewEnabled = true }
            Button("Turn off", role: .destructive) { arrivalPreviewEnabled = false }
        } message: {
            Text("You've seen 10 — a quick glimpse of what your person catches. You can change this anytime in Settings.")
        }
    }

    @ViewBuilder
    private var arrivalPreviewLayer: some View {
        if let preview = arrivalPreview {
            // [2/3] SENT CONFIRMATION — every instrument's send ends with the
            // ONE shared EmojiRevealView: context = .sent ("sent to [Name] ✦"),
            // ambient = the instrument's world. Same component as the receipt.
            EmojiRevealView(
                emoji: preview.emoji,
                message: sentMessage,
                tagline: sentTagline,
                context: .sent(recipientName: preview.name),
                ambient: RevealAmbient.forStyle(preview.style),
                onDismiss: { arrivalPreviewFinished() }
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var sentNoticeToast: some View {
        if sentNotice {
            Text("sent ✦")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Color(hex: "#c4a8d4"))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(DesignTokens.Color.background.opacity(0.9))
                        .overlay(Capsule().stroke(Color(hex: "#c4a8d4").opacity(0.35), lineWidth: 1))
                )
                .padding(.top, 60)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// The flight finished. Either show a brief glimpse of the recipient's
    /// catch (the arrival preview), or just confirm "sent ✦".
    private func finishSend(emoji: String, style: SenderStyle) {
        if arrivalPreviewEnabled {
            arrivalPreviewCount += 1
            let recipient = people.selectedPerson?.name ?? "them"
            arrivalPreview = ArrivalPreviewData(emoji: emoji, style: style, name: recipient)
            // The preview view calls back when its glimpse ends.
        } else {
            showSentNotice()
            appState.transition(to: .idle)
        }
    }

    /// Called when the arrival preview finishes its ~2.5 s glimpse.
    private func arrivalPreviewFinished() {
        arrivalPreview = nil
        showSentNotice()
        appState.transition(to: .idle)
        // After the 10th preview, ask whether to keep showing them.
        if arrivalPreviewCount == 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showKeepPreviewPrompt = true
            }
        }
    }

    private func showSentNotice() {
        withAnimation(.easeOut(duration: 0.3)) { sentNotice = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.4)) { sentNotice = false }
        }
    }

    /// The send: styled flight in the real compass direction, sound, clear.
    /// SenderAnimationView owns the haptics and the style voice; the
    /// thought's own sound still plays here.
    private func sendThought(_ token: String) {
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

        // Real delivery when paired. The SELECTED person's partner id wins —
        // the global connectedFriendID is only a fallback (with several
        // paired people it can point at someone else entirely).
        let recipient = people.selectedPerson?.pairedUserID.flatMap(UUID.init)
                        ?? SupabaseService.connectedFriendID
        if let recipient {
            CompassView.log.info("send: \(token, privacy: .public) → \(recipient.uuidString, privacy: .public) as \(style.rawValue, privacy: .public)")
            pings.sendRemote(to: recipient,
                             emoji: sendRemoteEmoji(for: token),
                             style: style,
                             message: outgoingMessage.isEmpty ? nil : outgoingMessage,
                             tagline: people.selectedPerson?.tagline)
        } else {
            CompassView.log.info("send: local only — no paired recipient")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            playSendSound(token)
            // HapticEngine.thoughtLaunched()   // retired — single .light at launch
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
            // Shareable moment — offer briefly after the needle settles
            shareCard = renderShareCard()
            withAnimation(.easeIn(duration: 0.5).delay(0.8)) { showShareMoment = true }
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                withAnimation(.easeOut(duration: 0.6)) { showShareMoment = false }
            }
        } else {
            withAnimation(.easeOut(duration: 0.5)) { steadyLock = false }
            withAnimation(.easeOut(duration: 0.3)) {
                showShareMoment = false
                breathePulse = false
            }
        }
    }

    // MARK: - Ambient presence glow

    /// Warm lavender light breathing in from the partner's edge of the
    /// screen — they're pointing at us right now. No text, no badge…
    /// unless we're pointing back: then the moment is named.
    private var presenceGlow: some View {
        let rad = compass.state.bearingDegrees * .pi / 180
        return ZStack {
            RadialGradient(
                colors: [Color(hex: "#c4a8d4").opacity(steadyLock ? 0.34 : 0.22), .clear],
                center: UnitPoint(x: 0.5 + 0.60 * sin(rad),
                                  y: 0.5 - 0.60 * cos(rad)),
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()

            // Both needles resting on each other — a shared moment
            if compass.state.isLocked {
                VStack {
                    Spacer()
                    Text("pointing at each other ✦")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(Color(hex: "#e0ccee"))
                        .shadow(color: Color(hex: "#9b7fc0").opacity(0.8), radius: 8)
                        .padding(.bottom, 64)
                }
                .transition(.opacity)
            }
        }
    }

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
        pendingReplayCaption = "from \(compass.state.personName) · \(Self.timeAgo(rec.createdAt))"
        // [swipe] Pass the FULL sorted list (unread-first) so the replay can
        // swipe between thoughts; start at the tapped one.
        let list = sortedThoughts
        let start = list.firstIndex(where: { $0.id == rec.id }) ?? 0
        let items = list.map {
            PingManager.ReplayItem(emoji: $0.emoji,
                                   bearingDegrees: compass.state.bearingDegrees,
                                   styleRaw: $0.senderStyle,
                                   fromName: compass.state.personName,
                                   message: $0.message,        // AUDIT [5/6]
                                   tagline: $0.tagline)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            pings.requestReplaySequence(items, startIndex: start)
        }
    }

    /// Recent RECEIVED thoughts from the currently-tracked person, newest first.
    /// [2/5] Merges SERVER history (real thoughts, per-person) with LOCAL caught
    /// history (dev test thoughts + an offline fallback) so every caught thought
    /// shows in the bucket — deduped by id, newest first.
    private func loadCompassThoughts() async {
        guard let person = people.selectedPerson else {
            compassThoughts = mergedLocalHistory(serverRecords: [], person: nil)
            thoughtsLoaded = true
            return
        }
        let me = SupabaseService.localUserID
        var server: [SupabaseService.PingRecord] = []
        if let pid = person.pairedUserID.flatMap(UUID.init) {
            server = await SupabaseService.shared.fetchPings(with: pid)
                .filter { $0.toUser.uuidString == me?.uuidString }   // addressed to me
        }
        compassThoughts = mergedLocalHistory(serverRecords: server, person: person)
        thoughtsLoaded = true
    }

    /// [2/5] Fold the local caught-history into the server records. Test thoughts
    /// always show; locally-caught real thoughts show only under their own
    /// person. Server rows win on dedupe (they carry the canonical opened state).
    private func mergedLocalHistory(serverRecords: [SupabaseService.PingRecord],
                                    person: Person?) -> [SupabaseService.PingRecord] {
        let me = SupabaseService.localUserID ?? UUID()
        let pid = person?.pairedUserID.flatMap(UUID.init) ?? me
        let serverIDs = Set(serverRecords.map(\.id))
        let local = pings.caughtHistory
            .filter { $0.isTest || $0.fromName == person?.name }
            .compactMap { rp -> SupabaseService.PingRecord? in
                let id = rp.remoteID ?? rp.id
                if serverIDs.contains(id) { return nil }   // server copy wins
                return SupabaseService.PingRecord(
                    id: id, fromUser: pid, toUser: me, emoji: rp.emoji,
                    createdAt: rp.timestamp, openedAt: rp.timestamp,
                    senderStyle: rp.senderStyle, message: rp.message, tagline: rp.tagline)
            }
        return (serverRecords + local).sorted { $0.createdAt > $1.createdAt }
    }

    private static func timeAgo(_ date: Date) -> String {
        let s = Int(Date.now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3_600 { return "\(s / 60)m ago" }
        if s < 86_400 { return "\(s / 3_600)h ago" }
        return "\(s / 86_400)d ago"
    }

    // MARK: - Share card

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

    private func handlePersonChange() {
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

// MARK: - SkinQuickPicker

/// Long-press the compass face → switch skins right here, no Settings trip.
struct SkinQuickPicker: View {

    let isPro: Bool
    let onLockedTap: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var skinStore: SkinStore

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Text("compass skin")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)

                HStack(spacing: 14) {
                    card(.minimal, locked: false)
                    card(.vintage, locked: !isPro)
                    card(.heart,   locked: !isPro)
                }
            }
            .padding(22)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
            )
            .shadow(color: Color(hex: "#9b7fc0").opacity(0.3), radius: 24)
            .padding(.horizontal, 36)
        }
    }

    private func card(_ skin: CompassSkin, locked: Bool) -> some View {
        let isActive = skinStore.activeSkin == skin
        return Button {
            if locked {
                HapticEngine.paywallReached()
                onLockedTap()
            } else {
                skinStore.activeSkin = skin
                HapticEngine.skinSelected()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onDismiss() }
            }
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .stroke(isActive ? Self.lavender : DesignTokens.Color.borderMid,
                                lineWidth: isActive ? 2 : 1)
                        .frame(width: 56, height: 56)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Self.lavender.opacity(0.8))
                    } else {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isActive ? Self.lavender : DesignTokens.Color.textDim)
                    }
                    if isActive {
                        VStack { HStack { Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Self.lavender)
                        }; Spacer() }
                        .frame(width: 62, height: 62)
                    }
                }
                .shadow(color: isActive ? Self.lavender.opacity(0.55) : .clear, radius: 9)
                Text(skin.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? DesignTokens.Color.textPrimary
                                              : DesignTokens.Color.textMuted)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PersonSwitcherSheet

/// Tap the name on the compass → choose who to point toward.
/// emoji + name + distance per row; selection swings the needle immediately.
struct PersonSwitcherSheet: View {

    @EnvironmentObject var people: PeopleManager
    @EnvironmentObject var compass: CompassManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("point toward…")
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.top, 22)
                        .padding(.bottom, 12)

                    ForEach(people.people) { person in
                        Button {
                            people.select(person)
                            compass.start(tracking: person)
                            HapticEngine.personSelected()
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Text(person.emoji)
                                    .font(.system(size: 26))
                                Text(person.name)
                                    .font(.system(size: 17, weight: .medium, design: .serif))
                                    .foregroundColor(DesignTokens.Color.textPrimary)
                                Spacer()
                                if let distance = distanceText(for: person) {
                                    Text(distance)
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignTokens.Color.textMuted)
                                        .monospacedDigit()
                                }
                                if people.selectedPerson?.id == person.id {
                                    Circle()
                                        .fill(Color(hex: "#c4a8d4"))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if person.id != people.people.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func distanceText(for person: Person) -> String? {
        guard let location = compass.userLocation else { return nil }
        let km = BearingCalculator.distanceKm(from: location.coordinate, to: person.coordinate)
        return BearingCalculator.formattedDistance(km)
    }
}

// MARK: - DirectionalArrivalView

/// DIRECTIONAL ARRIVAL — direction feels physical, requires nothing.
/// The emoji blooms in FROM the screen edge matching the sender's bearing
/// (north → top, east → right…), travels to center, and settles. Fully
/// received on arrival. Pointing toward them within 30 s replays the bloom
/// warmer — bonus magic, never a requirement.
struct DirectionalArrivalView: View {

    let ping: PingManager.ReceivedPing
    let onContinue: () -> Void

    @EnvironmentObject var compass: CompassManager

    @State private var arrived    = false   // edge → center travel + bloom
    @State private var named      = false
    @State private var breathing  = false
    @State private var hintShown  = false   // "turn toward them…" (3 s)
    @State private var replayGlow = false   // warmer second bloom
    @State private var mutualNote = false   // "pointing toward them ✦"
    @State private var replayArmed = true   // 30 s window
    @State private var replaying  = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let warm     = Color(hex: "#d4b08c")

    private var alignmentDiff: Double {
        let bearing = compass.state.bearingDegrees
        return min(bearing, 360 - bearing)
    }
    private var isAligned: Bool { alignmentDiff <= 15 }

    var body: some View {
        GeometryReader { geo in
            let rad   = compass.state.bearingDegrees * .pi / 180
            let reach = max(geo.size.width, geo.size.height) * 0.62
            let start = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)

            ZStack {
                // Quiet veil
                Color.black.opacity(0.45).ignoresSafeArea()

                // Glow anchored at the sender's edge — warms on replay
                RadialGradient(
                    colors: [(replayGlow ? Self.warm : Self.lavender)
                                .opacity(replayGlow ? 0.36 : 0.28), .clear],
                    center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                      y: 0.5 - 0.62 * cos(rad)),
                    startRadius: 10,
                    endRadius: 420
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    if named {
                        VStack(spacing: 3) {
                            Text("\(ping.fromName) sent you this")
                                .font(.system(size: 15, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                            Text(PoeticTime.string(for: ping.timestamp))
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.textMuted)
                        }
                        .transition(.opacity)
                    }

                    // The bloom — travels in from the sender's edge,
                    // settles at center. Same easeOut, no bounce.
                    Text(ping.emoji)
                        .font(.system(size: 76))
                        .opacity(arrived ? 1 : 0.25)
                        .scaleEffect((arrived ? 1.0 : 0.35) * (breathing ? 1.03 : 1.0))
                        .offset(arrived ? .zero : start)
                        .shadow(color: (replayGlow ? Self.warm : Self.lavender).opacity(0.55),
                                radius: replayGlow ? 24 : 18)

                    if mutualNote {
                        Text("pointing toward them ✦")
                            .font(.system(size: 12, design: .serif).italic())
                            .foregroundColor(Self.warm)
                            .transition(.opacity)
                    } else if hintShown {
                        Text("turn toward them to feel it again")
                            .font(.system(size: 10, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.75))
                            .transition(.opacity)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onContinue() }
            .onAppear { arrive() }
            .onChange(of: isAligned) { _, aligned in
                // Optional replay — bonus magic within the 30 s window
                if aligned && replayArmed && !replaying && arrived {
                    replayFromDirection()
                }
            }
        }
    }

    private func arrive() {
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: ping.emoji)
        withAnimation(.easeOut(duration: 1.2)) { arrived = true }
        withAnimation(.easeOut(duration: 0.6).delay(1.1)) { named = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
            // The soft optional hint — fades after 3 s, no consequence
            withAnimation(.easeIn(duration: 0.5)) { hintShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.8)) { hintShown = false }
            }
        }
        // Replay window closes after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { replayArmed = false }
    }

    private func replayFromDirection() {
        replaying = true
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: ping.emoji)
        withAnimation(.easeIn(duration: 0.4)) {
            replayGlow = true
            mutualNote = true
        }
        // Pull back toward the edge and bloom in again
        breathing = false
        withAnimation(.easeIn(duration: 0.35)) { arrived = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.0)) { arrived = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                mutualNote = false
                replayGlow = false
            }
            replaying = false
        }
    }
}

// MARK: - RevealArrivalView (superseded by DirectionalArrivalView; kept)

/// DIRECTION REVEALS CONTENT — the compass IS the inbox.
/// A thought arrives: no emoji shown. The screen edge glows from the
/// sender's direction, "[name] sent you something". Physically turn the
/// phone toward them (within 15°) and the emoji blooms with its sound.
struct RevealArrivalView: View {

    let ping: PingManager.ReceivedPing
    let onRevealed: () -> Void
    let onContinue: () -> Void

    @EnvironmentObject var compass: CompassManager

    @State private var revealed  = false
    @State private var bloomed   = false
    @State private var named     = false
    @State private var breathing = false
    @State private var debugBypass = false

    private static let lavender = Color(hex: "#c4a8d4")

    private var alignmentDiff: Double {
        let bearing = compass.state.bearingDegrees
        return min(bearing, 360 - bearing)
    }
    private var isAligned: Bool { debugBypass || alignmentDiff <= 15 }

    var body: some View {
        ZStack {
            if !revealed {
                // ── Waiting: the pull. Edge glow + the invitation to turn ──
                let rad = compass.state.bearingDegrees * .pi / 180
                RadialGradient(
                    colors: [Self.lavender.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                      y: 0.5 - 0.62 * cos(rad)),
                    startRadius: 10,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack {
                    VStack(spacing: 4) {
                        Text("\(ping.fromName) sent you something")
                            .font(.system(size: 14, design: .serif).italic())
                            .foregroundColor(Self.lavender)
                        Text("turn toward them to feel it")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textMuted)
                        #if DEBUG
                        Button("⚙︎ reveal (sim)") { debugBypass = true }
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.textDim)
                        #endif
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Color.backgroundLift.opacity(0.92))
                            .overlay(Capsule().stroke(Self.lavender.opacity(0.4), lineWidth: 1))
                    )
                    .padding(.top, 84)
                    Spacer()
                }
            } else {
                // ── Revealed: the bloom ─────────────────────────────────────
                Color.black.opacity(0.45).ignoresSafeArea()
                RadialGradient(
                    colors: [Self.lavender.opacity(0.25), .clear],
                    center: .center, startRadius: 20, endRadius: 320
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    if named {
                        VStack(spacing: 3) {
                            Text("\(ping.fromName) sent you this")
                                .font(.system(size: 15, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                            Text(PoeticTime.string(for: ping.timestamp))
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.textMuted)
                        }
                        .transition(.opacity)
                    }

                    Text(ping.emoji)
                        .font(.system(size: 76))
                        .opacity(bloomed ? 1 : 0)
                        .scaleEffect((bloomed ? 1.0 : 0.3) * (breathing ? 1.03 : 1.0))
                        .shadow(color: Self.lavender.opacity(0.5), radius: 18)
                        .onTapGesture { replayBloom() }

                    if named {
                        Text("tap to feel again")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.textDim)
                            .transition(.opacity)
                    }
                }
                // Tap anywhere else → continue to the next thought
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onContinue() }
                    .allowsHitTesting(true)
                    .zIndex(-1)
            }
        }
        .onAppear {
            HapticEngine.thoughtArrived()   // the directional pull
        }
        .onChange(of: isAligned) { _, aligned in
            if aligned && !revealed { reveal() }
        }
        .onAppear {
            // Already pointing at them when it arrives → instant bloom
            if isAligned { reveal() }
        }
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.4)) { revealed = true }
        onRevealed()   // opened_at — felt at the moment of reveal
        playBloom()
    }

    private func playBloom() {
        SoundEngine.shared.play(for: ping.emoji)
        HapticEngine.thoughtArrived()
        withAnimation(.easeOut(duration: 1.2)) { bloomed = true }
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) { named = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private func replayBloom() {
        breathing = false
        bloomed   = false
        named     = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { playBloom() }
    }
}

// MARK: - ShareCardView

/// The shareable compass moment — skin-toned face, real bearing, the words.
struct ShareCardView: View {

    let personName: String
    let emoji: String
    let bearing: Double
    let distance: String
    let tagline: String

    var body: some View {
        VStack(spacing: 14) {
            Text("pointing toward")
                .font(.system(size: 10, weight: .medium))
                .kerning(2.2)
                .foregroundColor(Color(hex: "#7c6b8e"))
                .padding(.top, 26)

            Text(personName)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(Color(hex: "#e8e0f0"))

            // The face — ring, cardinal ticks, needle at the real bearing
            ZStack {
                Circle()
                    .stroke(Color(hex: "#3a3050"), lineWidth: 1.5)
                    .frame(width: 170, height: 170)
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(0.10))
                    .frame(width: 170, height: 170)
                    .blur(radius: 12)
                ForEach(0..<4, id: \.self) { i in
                    Text(["N", "E", "S", "W"][i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#7c6b8e"))
                        .offset(y: -94)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
                // The needle
                VStack(spacing: 0) {
                    Triangle()
                        .fill(Color(hex: "#c4a8d4"))
                        .frame(width: 13, height: 56)
                    Rectangle()
                        .fill(Color(hex: "#7c6b8e").opacity(0.6))
                        .frame(width: 2.5, height: 42)
                }
                .offset(y: -7)
                .rotationEffect(.degrees(bearing))
                .shadow(color: Color(hex: "#9b7fc0").opacity(0.7), radius: 8)
                Text(emoji)
                    .font(.system(size: 20))
                    .offset(y: 0)
            }
            .frame(width: 200, height: 200)

            Text(distance)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color(hex: "#a89bb8"))
                .monospacedDigit()

            Text(tagline)
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(Color(hex: "#c4a8d4"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("pointward.app")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#5a4f6e"))
                .padding(.top, 6)
                .padding(.bottom, 22)
        }
        .frame(width: 320)
        .background(
            LinearGradient(colors: [Color(hex: "#16121f"), Color(hex: "#0d0d14")],
                           startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(24)
    }
}

// MARK: - CoreArrivalView (superseded by RevealArrivalView; kept)

/// CORE arrival — intimate, not loud. A single soft pulse, light blooming
/// from the edge of the screen in the sender's direction (like light through
/// a curtain), the emoji blooming gently at center, then the sender's name.
/// No particles. No bounce. Tap the emoji to feel it again; tap anywhere
/// else to continue.
struct CoreArrivalView: View {

    let ping: PingManager.ReceivedPing
    let incomingBearing: Double      // where they are, relative to us
    let onContinue: () -> Void

    @State private var bloomed   = false   // emoji bloom
    @State private var glow      = false   // directional edge light
    @State private var named     = false   // sender line
    @State private var breathing = false   // gentle rest state

    private static let lavender = Color(red: 196/255, green: 168/255, blue: 212/255)

    var body: some View {
        ZStack {
            // Quiet veil — the room dims, nothing shouts
            Color.black.opacity(0.45).ignoresSafeArea()

            // Directional glow from the sender's edge of the screen,
            // fading inward — warm lavender, light through a curtain
            let rad = incomingBearing * .pi / 180
            RadialGradient(
                colors: [Self.lavender.opacity(0.30), .clear],
                center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                  y: 0.5 - 0.62 * cos(rad)),
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(glow ? 1 : 0)

            VStack(spacing: 14) {
                // Sender — appears after the emoji settles
                if named {
                    VStack(spacing: 3) {
                        Text("\(ping.fromName) sent you something")
                            .font(.system(size: 15, design: .serif).italic())
                            .foregroundColor(Self.lavender)
                        Text(PoeticTime.string(for: ping.timestamp))
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textMuted)
                    }
                    .transition(.opacity)
                }

                // The bloom — pure easeOut, no spring, no bounce
                Text(ping.emoji)
                    .font(.system(size: 76))
                    .opacity(bloomed ? 1 : 0)
                    .scaleEffect((bloomed ? 1.0 : 0.3) * (breathing ? 1.03 : 1.0))
                    .shadow(color: Self.lavender.opacity(0.5), radius: 18)
                    .onTapGesture { replay() }   // tap to feel again

                if named {
                    Text("tap to feel again")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.textDim)
                        .transition(.opacity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onContinue() }
        .onAppear { play() }
    }

    private func play() {
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: ping.emoji)

        withAnimation(.easeOut(duration: 1.2)) { bloomed = true }
        withAnimation(.easeOut(duration: 0.5)) { glow = true }
        withAnimation(.easeIn(duration: 1.0).delay(0.5)) { glow = false }
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) { named = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private func replay() {
        breathing = false
        bloomed   = false
        named     = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { play() }
    }
}

/// PRO arrival — the full dramatic shooting animation.
struct ThoughtArrivalView: View {

    let ping: PingManager.ReceivedPing
    let incomingBearing: Double          // where they are, relative to us
    let onFinished: () -> Void           // animation ran its course
    let onSkip: () -> Void               // user tapped through

    @State private var fly     = false   // edge → center travel
    @State private var settled = false   // the reveal

    private static let glow = Color(hex: "#9b7fc0")

    var body: some View {
        GeometryReader { geo in
            let rad   = incomingBearing * .pi / 180
            let reach = max(geo.size.width, geo.size.height) * 0.62
            let start = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)

            ZStack {
                // Dim the world; let the thought own the screen
                Color.black.opacity(0.55).ignoresSafeArea()
                RadialGradient(
                    colors: [Self.glow.opacity(settled ? 0.30 : 0.12), .clear],
                    center: .center, startRadius: 20, endRadius: 320
                )
                .ignoresSafeArea()

                // Trail — smaller copies chasing in from their direction
                ForEach(0..<5, id: \.self) { i in
                    Text(ping.emoji)
                        .font(.system(size: 22))
                        .opacity(fly ? 0 : 0.75 - Double(i) * 0.13)
                        .offset(fly ? .zero : start)
                        .animation(.easeOut(duration: 1.2).delay(0.12 + Double(i) * 0.09), value: fly)
                }

                // The thought itself, flying in
                if !settled {
                    Text(ping.emoji)
                        .font(.system(size: 34))
                        .scaleEffect(fly ? 2.0 : 0.7)
                        .offset(fly ? .zero : start)
                        .animation(.easeOut(duration: 1.2), value: fly)
                        .shadow(color: Self.glow.opacity(0.8), radius: 14)
                }

                // The reveal — an event, not a footnote
                if settled {
                    VStack(spacing: 10) {
                        Text(ping.emoji)
                            .font(.system(size: 72))
                            .shadow(color: Self.glow.opacity(0.9), radius: 22)
                        Text("from \(ping.fromName)")
                            .font(.system(size: 27, weight: .semibold, design: .serif))
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        Text(Self.relativeTime(ping.timestamp))
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSkip() }
            .onAppear {
                SoundEngine.shared.play(for: ping.emoji)
                HapticEngine.pingReceived()
                withAnimation { fly = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        settled = true
                    }
                    HapticEngine.connectionFelt()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                    onFinished()
                }
            }
        }
    }

    static func relativeTime(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 90 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
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
