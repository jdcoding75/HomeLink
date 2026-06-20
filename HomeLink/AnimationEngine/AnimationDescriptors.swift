// AnimationDescriptors.swift
// Pointward › AnimationEngine
//
// THE CREATIVE BRIEF FOR EVERY INSTRUMENT.
//
// Each descriptor contains:
// - The emotional story
// - The wow moment
// - Exact technical values
// - Sound brief for audio designer
// - Visual brief for animator
//
// This file is the source of truth for
// how every animation looks and feels.
// Change a value here — it changes
// everywhere automatically.

import SwiftUI

extension AnimationDescriptor {

    // ─────────────────────────────────────
    // MARK: 🚀 ROCKET
    // ─────────────────────────────────────
    //
    // EMOTIONAL STORY:
    // The most dramatic send in the app.
    // Used for celebration, excitement,
    // "I'm thinking of you SO much right
    // now I needed to LAUNCH something."
    // This is not subtle. This is a
    // full commitment send.
    //
    // THE WOW MOMENT:
    // The countdown silence before blast.
    // 2.5 seconds of building tension —
    // fuel loading, systems priming —
    // then EVERYTHING explodes at once.
    // The silence IS the drama.
    // Nothing happens... nothing happens...
    // EVERYTHING HAPPENS.
    //
    // SEND VISUAL BRIEF:
    // Rocket stands on pad at screen center.
    // Countdown: 3...2...1 appears and fades.
    // Exhaust plume begins at T-0.5s —
    // small white wisps from engine bell.
    // At T-0: FULL BLAST.
    // White core exhaust column erupts.
    // Orange-red fire particles scatter.
    // Rocket accelerates — slow then fast.
    // Reaches top of screen in 1.5s.
    // Screen shakes ±6px at launch.
    // Smoke trail lingers and drifts.
    //
    // RECEIVE VISUAL BRIEF:
    // Deep black space. Stars drift slowly.
    // Tiny bright speck appears at sender edge.
    // Grows as it approaches — perspective.
    // Banks slightly — feels alive.
    // Landing legs deploy at T-2s.
    // Touchdown: screen shakes ±4px.
    // Exhaust clears. Door opens. Emoji emerges.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Deep subwoofer rumble building
    // from near-silence over 2.5 seconds.
    // Think Saturn V launch recording.
    // Key frequencies: 40-80hz build,
    // burst of full spectrum at ignition,
    // crackling fire tail.
    // Total: 4.0 seconds.
    // ElevenLabs prompt: "Deep rumbling
    // rocket launch sound, starting almost
    // silent, building over 2 seconds to
    // a thunderous roar with crackling
    // fire exhaust tail, 4 seconds total,
    // very bass heavy"
    //
    // ARRIVAL: Same rumble character but
    // descending — roar fades to thruster
    // burns, then silence at touchdown.
    //
    // HAPTIC BRIEF:
    // SEND: sustainedRumble — 8 pulses
    // building over 0.8s then single
    // massive heavy at launch.
    // ARRIVAL: singleHeavy at touchdown.
    // REVEAL: celebration (success notification).
    //
    static let rocket = AnimationDescriptor(
        instrument: .rocket,
        emotionalIntent: .powerful,
        anticipationDuration: 2.5,
        journeyDuration: 1.5,
        arrivalDuration: 3.0,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 40,
        particleColor: .fireOrange,
        glowRadius: 32,
        glowOpacity: 0.50,
        trailLength: 14,
        primaryColor: Color(hex: "#FF6B35"),
        worldBackground: .deepSpace,
        easingCurve: .explosive,
        launchScale: 0.08,
        peakScale: 2.8,
        arrivalBounce: true,
        sendSound: .rocketRoar,
        arrivalSound: .heavyThud,
        sendHaptic: .sustainedRumble,
        arrivalHaptic: .singleHeavy
    )

    // ─────────────────────────────────────
    // MARK: 🏹 BOW
    // ─────────────────────────────────────
    //
    // EMOTIONAL STORY:
    // Precise. Intentional. Aimed.
    // This is "I thought specifically about
    // YOU and aimed this directly at you."
    // The most targeted send in the app.
    // Used for encouragement, focus,
    // "you've got this" moments.
    //
    // THE WOW MOMENT:
    // The moment of release.
    // The string snaps. Everything is still.
    // Then the arrow is just... gone.
    // Too fast to see.
    // That absence IS the wow.
    // The sound does the work —
    // crack of release + Doppler whistle
    // fading to nothing in 0.3s.
    //
    // SEND VISUAL BRIEF:
    // User spins outer rim to aim.
    // Bow draws back — string tension visible.
    // Arrow nocked, feathers visible.
    // Target marker on person bearing.
    // At release: arrow streak.
    // Not a slow arc — a blur line.
    // Gone in 0.2s.
    // 3 flight feathers spin off in wake.
    // Tiny gold wisps mark the path.
    //
    // RECEIVE VISUAL BRIEF:
    // Dark archery range world.
    // Target rings centered on screen.
    // Arrow appears at sender edge —
    // full size, traveling fast.
    // THUNK into target — screen micro-shake.
    // Arrow vibrates for 0.8s after impact.
    // Feathers flutter.
    // Emoji bursts from impact point.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Two sounds layered:
    // 1. Wood creak under tension (0.5s)
    //    building as string draws back
    // 2. Sharp CRACK of release (0.05s)
    //    followed immediately by
    //    high-pitch Doppler whistle
    //    fading to nothing in 0.3s
    // Like an actual compound bow release.
    // ElevenLabs prompt: "Compound bow
    // release sound, sharp crack followed
    // by high pitched arrow whistle
    // doppler fading away quickly,
    // 0.6 seconds total"
    //
    // ARRIVAL: Sharp metallic THUNK.
    // Arrow hitting a target hard.
    // Short vibration tail 0.2s.
    // ElevenLabs prompt: "Arrow hitting
    // archery target, sharp thud with
    // brief vibration, 0.4 seconds"
    //
    static let bow = AnimationDescriptor(
        instrument: .bow,
        emotionalIntent: .powerful,
        anticipationDuration: 0.5,
        journeyDuration: 0.3,
        arrivalDuration: 0.4,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 14,
        particleColor: .goldAmber,
        glowRadius: 20,
        glowOpacity: 0.40,
        trailLength: 6,
        primaryColor: Color(hex: "#D4A017"),
        worldBackground: .archeryRange,
        easingCurve: .explosive,
        launchScale: 0.2,
        peakScale: 1.8,
        arrivalBounce: false,
        sendSound: .bowRelease,
        arrivalSound: .arrowImpact,
        sendHaptic: .sharpSnap,
        arrivalHaptic: .singleHeavy
    )

    // ─────────────────────────────────────
    // MARK: 🌬️ WIND
    // ─────────────────────────────────────
    //
    // NOTE: The wind instrument is backed by
    // the `.firefly` enum case (its displayName
    // is "wind" — the case name is kept for
    // wire-format stability). The descriptor is
    // still named `wind` for clarity.
    //
    // EMOTIONAL STORY:
    // The most intimate send in the app.
    // You literally breathe it into existence.
    // Used for "I'm thinking of you softly"
    // moments. The quiet check-in.
    // The 2am "you awake?" feeling.
    // This is the one that says the most
    // with the least effort.
    //
    // THE WOW MOMENT:
    // The leaf swirling around the entire
    // screen before finding direction.
    // It takes its TIME.
    // The user watches it dance for 8 seconds.
    // That patience IS the emotional message.
    // "I'm not in a rush. I just wanted
    // you to know I was thinking of you."
    //
    // SEND VISUAL BRIEF:
    // Leaf rises from screen bottom.
    // Size: 160x100pt. Emoji: 56pt on face.
    // Swirls lazily around screen ONCE.
    // Seed particles drift off as it moves.
    // 8-10 second gentle circle.
    // Then: catches the wind.
    // Accelerates toward person bearing.
    // Seed trail increases as it speeds up.
    // Exits screen with a final seed burst.
    //
    // RECEIVE VISUAL BRIEF:
    // Blue sky, soft clouds drifting.
    // Leaf enters at sender screen edge.
    // Same lazy swirl — one full circle.
    // User watches it drift toward them.
    // Auto-catches after circle completes.
    // No alignment needed — wind finds you.
    // Leaf tips into bucket.
    // Seeds scatter into bucket.
    // Emoji rises from seeds.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Not a whoosh. An actual breath.
    // Intimate. Close. Personal.
    // Like someone breathing near a mic.
    // Duration: 0.8s.
    // Then as leaf swirls: near-silence
    // with barely-audible wind chime.
    // On departure: gentle whoosh fade.
    // ElevenLabs prompt: "Soft intimate
    // breath sound, single exhale very
    // close to microphone, warm and
    // personal, 0.8 seconds"
    //
    // ARRIVAL: Distant gentle wind chime.
    // Single note. Barely there.
    // Like hearing wind chimes from
    // inside a house on a quiet day.
    // ElevenLabs prompt: "Single distant
    // wind chime note, very soft and
    // gentle, fading naturally, 1.5 seconds"
    //
    static let wind = AnimationDescriptor(
        instrument: .firefly,
        emotionalIntent: .tender,
        anticipationDuration: 0.4,
        journeyDuration: 8.0,
        arrivalDuration: 8.0,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 28,
        particleColor: .warmWhite,
        glowRadius: 14,
        glowOpacity: 0.18,
        trailLength: 8,
        primaryColor: Color(hex: "#90EE90"),
        worldBackground: .daySkyClouds,
        easingCurve: .gentle,
        launchScale: 0.8,
        peakScale: 1.2,
        arrivalBounce: false,
        sendSound: .windBreath,
        arrivalSound: .leafLanding,
        sendHaptic: .singleSoft,
        arrivalHaptic: .none
    )

    // ─────────────────────────────────────
    // MARK: 🪄 WAND
    // ─────────────────────────────────────
    //
    // EMOTIONAL STORY:
    // Pure magic. No physics. No logic.
    // Just "I'm sending you something
    // magical and I don't need to explain it."
    // Used for the inexplicable moments.
    // "I was just thinking about you and
    // something made me reach for my phone."
    // The most mysterious send.
    //
    // THE WOW MOMENT:
    // The explosion at release.
    // No build up. No warning.
    // One frame: crystal tip glowing.
    // Next frame: SUPERNOVA.
    // Everything erupts outward
    // from a single point simultaneously.
    // The silence after the explosion
    // is as important as the explosion.
    //
    // SEND VISUAL BRIEF:
    // Wand appears centered. Crystal tip up.
    // Each shake adds a ring of light at tip.
    // Rings spin faster with each shake.
    // At full charge: rings blur to solid glow.
    // Release: ONE FRAME of maximum brightness.
    // Then: instant expansion outward.
    // 72 particles erupt in all directions.
    // Lavender and gold sparkles.
    // Shock wave ring expands and fades.
    // Single sparkle trail toward bearing.
    //
    // RECEIVE VISUAL BRIEF:
    // Deep purple magical world.
    // Stars and drifting sparkles background.
    // Sparkle cluster forms at sender edge.
    // Travels as constellation toward bucket.
    // On arrival: BURST.
    // Sparkles scatter from bucket.
    // Some rise, some fall.
    // Emoji materializes from the center
    // of the sparkle cloud.
    // Like it was always there, just hidden.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Crystal resonance building.
    // Like a singing bowl being struck
    // faster and faster.
    // Then at release: complete silence
    // for 0.1s (the supernova moment).
    // Then: magical shimmer burst.
    // Crystalline, high frequency.
    // ElevenLabs prompt: "Magical wand
    // charging sound, crystal resonance
    // building in intensity, then brief
    // silence followed by sparkle burst,
    // 2 seconds total, mystical and bright"
    //
    // ARRIVAL: Crystal chime cluster.
    // Multiple high notes simultaneously.
    // Like dropping a handful of bells.
    // ElevenLabs prompt: "Magical sparkle
    // arrival sound, multiple crystal
    // chimes simultaneously, bright and
    // mystical, 0.8 seconds"
    //
    static let wand = AnimationDescriptor(
        instrument: .wand,
        emotionalIntent: .magical,
        anticipationDuration: 0.3,
        journeyDuration: 1.2,
        arrivalDuration: 0.6,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 72,
        particleColor: .lavender,
        glowRadius: 28,
        glowOpacity: 0.55,
        trailLength: 12,
        primaryColor: Color(hex: "#9b7fc0"),
        worldBackground: .magicalDark,
        easingCurve: .organic,
        launchScale: 0.05,
        peakScale: 1.8,
        arrivalBounce: true,
        sendSound: .wandShimmer,
        arrivalSound: .sparkleArrive,
        sendHaptic: .buildingSequence,
        arrivalHaptic: .celebration
    )

    // ─────────────────────────────────────
    // MARK: ✈️ PLANE
    // ─────────────────────────────────────
    //
    // EMOTIONAL STORY:
    // Charming. Nostalgic. Unhurried.
    // Like a toy rubber band plane
    // from childhood.
    // Used for long distance moments.
    // "You're far away but I'm sending
    // this all the way to you."
    // The most travel-aware send.
    // Distance is the point.
    //
    // THE WOW MOMENT:
    // The victory lap.
    // After landing the plane does a full
    // loop around the screen before stopping.
    // Nobody expects it.
    // It's showing off.
    // That single loop makes people smile
    // every single time.
    //
    // SEND VISUAL BRIEF:
    // User swirls finger to wind rubber band.
    // Propeller spins with finger.
    // At full wind: propeller blurs.
    // Release: plane launches from center.
    // Banks left then right — alive feeling.
    // Grows toward viewer then recedes.
    // Wake spiral behind propeller.
    // Exits toward person bearing.
    //
    // RECEIVE VISUAL BRIEF:
    // Bright blue daytime sky. Clouds drift.
    // Tiny speck at sender screen edge.
    // Grows dramatically as it approaches.
    // Banks left and right — charming wobble.
    // Flyover: passes OVER bucket.
    // Shadow sweeps across bucket.
    // Victory loop: full 360 around screen.
    // Lines up for landing.
    // Gear deploys. Flaps extend.
    // Touchdown at bucket.
    // Propeller spins to stop.
    // Door opens. Emoji delivered.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Toy propeller winding up.
    // Light mechanical whir getting faster.
    // At release: propeller at full speed
    // fading as plane flies away.
    // ElevenLabs prompt: "Small toy airplane
    // propeller sound, starts slow winding
    // up to full speed, light and charming,
    // 2 seconds total"
    //
    // ARRIVAL: Propeller approaching from
    // distance, growing louder.
    // Flyover: loud pass overhead.
    // Landing: engine slowing, wheels
    // touching ground, propeller winding down.
    // ElevenLabs prompt: "Small toy airplane
    // landing sound, propeller slowing down,
    // gentle touchdown, charming and light,
    // 3 seconds total"
    //
    static let plane = AnimationDescriptor(
        instrument: .plane,
        emotionalIntent: .playful,
        anticipationDuration: 3.0,
        journeyDuration: 2.0,
        arrivalDuration: 5.0,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 8,
        particleColor: .warmWhite,
        glowRadius: 8,
        glowOpacity: 0.15,
        trailLength: 4,
        primaryColor: Color(hex: "#FFD700"),
        worldBackground: .daySkyClouds,
        easingCurve: .gentle,
        launchScale: 0.05,
        peakScale: 1.6,
        arrivalBounce: true,
        sendSound: .planeEngine,
        arrivalSound: .planeTouchdown,
        sendHaptic: .singleSoft,
        arrivalHaptic: .singleMedium
    )

    // ─────────────────────────────────────
    // MARK: 👆 FLICK
    // ─────────────────────────────────────
    //
    // EMOTIONAL STORY:
    // Quick. Casual. Affectionate.
    // Like leaving a sticky note somewhere
    // someone will find it later.
    // Used for quick check-ins.
    // "Just flicking you a thought."
    // The most casual send.
    // Low commitment, high warmth.
    //
    // THE WOW MOMENT:
    // The SLAP on the cork board.
    // The note tumbles through the air
    // with satisfying spin.
    // Then: THWACK.
    // Pin shoots through.
    // Board shakes.
    // Cork dust scatters.
    // The violence of the impact vs the
    // softness of a sticky note is the joke.
    //
    // SEND VISUAL BRIEF:
    // Post-it note at compass center.
    // Emoji visible on face — 42pt.
    // User drags backward from any direction.
    // Elastic trail shows tension.
    // Release: note tumbles through air.
    // Rotation: 720 degrees during flight.
    // Slight wobble — paper in wind.
    // Exits screen toward person bearing.
    //
    // RECEIVE VISUAL BRIEF:
    // Warm cork board texture fills screen.
    // Existing pinned notes in background.
    // Note enters from sender screen edge.
    // Tumbling rotation during flight.
    // SLAP on board:
    //   Screen shakes ±4px.
    //   THWACK haptic.
    //   Pin shoots through note.
    //   Cork dust particles scatter radially.
    //   Note vibrates 0.4s after impact.
    // Emoji visible clearly on note face.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Paper snap — like flicking
    // a thick piece of paper.
    // Sharp and satisfying. 0.15s.
    // ElevenLabs prompt: "Paper flick snap
    // sound, single sharp snap like
    // flicking a sticky note, 0.15 seconds"
    //
    // ARRIVAL: Two-part sound:
    // 1. Paper tumbling (subtle flutter)
    // 2. THWACK of impact on cork board
    // The THWACK is the main event.
    // Sharp, solid, satisfying.
    // ElevenLabs prompt: "Sticky note
    // slapping onto a cork board, sharp
    // thwack sound with brief vibration,
    // 0.3 seconds"
    //
    static let flick = AnimationDescriptor(
        instrument: .flick,
        emotionalIntent: .playful,
        anticipationDuration: 0.1,
        journeyDuration: 0.6,
        arrivalDuration: 0.4,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 18,
        particleColor: .goldAmber,
        glowRadius: 10,
        glowOpacity: 0.25,
        trailLength: 4,
        primaryColor: Color(hex: "#FFD700"),
        worldBackground: .corkBoard,
        easingCurve: .explosive,
        launchScale: 0.6,
        peakScale: 1.5,
        arrivalBounce: true,
        sendSound: .flickSnap,
        arrivalSound: .noteSlap,
        sendHaptic: .sharpSnap,
        arrivalHaptic: .singleRigid
    )

    // ─────────────────────────────────────
    // MARK: 🧭 COMPASS
    // ─────────────────────────────────────
    //
    // EMOTIONAL STORY:
    // The original. The purest.
    // No mechanics. No gimmicks.
    // Just: I pointed toward you and
    // sent you something.
    // Used for the deepest, quietest
    // emotional moments.
    // "I don't need a rocket or a wand.
    // I just needed you to know
    // I was thinking of you."
    //
    // THE WOW MOMENT:
    // The glow that builds as the hold
    // completes. The needle pulling toward
    // the person. The moment the orb
    // releases and the compass face dims
    // — like something left.
    // Quiet and profound.
    //
    // SEND VISUAL BRIEF:
    // Compass needle pointing toward person.
    // Soft lavender orb forms at needle tip.
    // Grows as hold progresses.
    // At release: orb separates from needle.
    // Needle swings slightly — recoil.
    // Orb travels toward bearing.
    // Glowing trail behind it.
    // Compass face dims slightly after.
    // Like something real left the room.
    //
    // RECEIVE VISUAL BRIEF:
    // Deep purple world. Same as compass face.
    // Glowing orb enters from sender edge.
    // Soft glow trail behind it.
    // Travels slowly — tender not dramatic.
    // Arrives at bucket with soft pulse.
    // No explosion. Just: arrival.
    // Emoji materializes from orb dissolve.
    //
    // SOUND BRIEF FOR AUDIO DESIGNER:
    // SEND: Warm rising tone.
    // Like a singing bowl struck softly.
    // Builds during hold, peaks at release.
    // Then fades as orb departs.
    // ElevenLabs prompt: "Warm soft singing
    // bowl tone, gentle strike building
    // slowly then fading, intimate and
    // peaceful, 2 seconds"
    //
    // ARRIVAL: Same singing bowl but
    // arriving — tone descends gently.
    // Resolves to silence. Complete.
    // ElevenLabs prompt: "Soft singing bowl
    // arrival tone, descending gently to
    // silence, peaceful and complete,
    // 1.5 seconds"
    //
    static let compass = AnimationDescriptor(
        instrument: .compass,
        emotionalIntent: .tender,
        anticipationDuration: 0.3,
        journeyDuration: 1.5,
        arrivalDuration: 1.0,
        revealDuration: 0.5,
        lingerDuration: 6.0,
        particleCount: 12,
        particleColor: .lavender,
        glowRadius: 22,
        glowOpacity: 0.38,
        trailLength: 10,
        primaryColor: Color(hex: "#c4a8d4"),
        worldBackground: .deepPurple,
        easingCurve: .organic,
        launchScale: 0.4,
        peakScale: 1.5,
        arrivalBounce: false,
        sendSound: .compassPulse,
        arrivalSound: .orbArrive,
        sendHaptic: .singleMedium,
        arrivalHaptic: .singleSoft
    )

    // ─────────────────────────────────────
    // MARK: - Lookup
    // ─────────────────────────────────────
    //
    // Resolve the descriptor for any
    // instrument. The `.firefly` case is the
    // wind instrument (see note on `wind`).
    //
    static func descriptor(
        for instrument: Instrument
    ) -> AnimationDescriptor {
        switch instrument {
        case .compass: return .compass
        case .bow:     return .bow
        case .firefly: return .wind
        case .flick:   return .flick
        case .rocket:  return .rocket
        case .wand:    return .wand
        case .plane:   return .plane
        // [special moments] no dedicated descriptor — fall back to the compass
        // (glow) descriptor they originally shared. Legacy/test path only.
        case .birthday, .firework: return .compass
        }
    }
}
