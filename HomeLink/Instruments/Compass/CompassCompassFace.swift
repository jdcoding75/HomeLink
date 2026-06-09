// CompassCompassFace.swift
// Pointward › Instruments › Compass
//
// ACT 1 of 3 — the compass instrument's interactive face.
//
// POINTER FILE:
// Unlike the other instruments, the compass face is not a
// small standalone view — it is rendered by CompassView,
// the app's emotional core, which is referenced throughout
// the app. Moving that file is out of scope for a zero-
// behavior-change structural pass, so it intentionally
// stays at Views/CompassView.swift.
//
// This file marks the compass's place in the per-instrument
// folder system and is the home for any compass-face state
// machine added by the animation work.

import SwiftUI
