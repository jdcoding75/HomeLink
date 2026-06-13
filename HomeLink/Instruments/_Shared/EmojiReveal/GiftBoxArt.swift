// GiftBoxArt.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// Shared gift-box art for the 🎁 reveal hero. Mirrors BirthdayCakeGlyph: a
// custom-drawn box renders in place of the 🎁 glyph so the LID can lift off
// independently of the BODY (a single emoji glyph can't be split). The
// underlying thought data stays 🎁.
//
// The body (box + cross ribbon + the dark open interior) stays put; the LID
// (flat top + bow) is positioned by the caller via `lidLift` / `lidOpacity` /
// `lidTilt`, so the reveal can pop it off, bounce it, and float it away while
// the open box remains.

import SwiftUI

struct GiftBoxGlyph: View {
    /// Approximate visual height in points (≈ the emoji font size it replaces).
    var height: CGFloat = 156
    /// How far the lid has risen above its closed rest position (points, up+).
    var lidLift: CGFloat = 0
    /// Lid opacity — fades to 0 as it floats away.
    var lidOpacity: Double = 1
    /// A slight tilt on the lid for character during the pop (degrees).
    var lidTilt: Double = 0

    // Palette — warm + celebratory (pairs with the reveal glow #FF5CA8).
    private static let boxA     = Color(hex: "#ff7ab8")
    private static let boxB     = Color(hex: "#e84f9c")
    private static let boxC     = Color(hex: "#c23c80")
    private static let ribbon   = Color(hex: "#ffd56a")
    private static let ribbonHi = Color(hex: "#fff1c4")
    private static let interior = Color(hex: "#511f40")

    var body: some View {
        let box = CGSize(width: height * 1.12, height: height)
        let cx  = box.width / 2

        let boxW = height * 0.74
        let boxH = height * 0.54
        let bodyCenterY = box.height * 0.66
        let bodyTopY    = bodyCenterY - boxH / 2

        let lidH = height * 0.17
        let lidW = boxW * 1.18
        let ribbonW = boxW * 0.17
        // Closed lid rests just over the body's top edge.
        let lidClosedCenterY = bodyTopY - lidH / 2 + height * 0.03

        return ZStack {
            // ── Open interior — a dark slot revealed once the lid lifts ──
            RoundedRectangle(cornerRadius: 4)
                .fill(Self.interior)
                .frame(width: boxW * 0.9, height: lidH * 1.15)
                .position(x: cx, y: bodyTopY + 3)

            // ── BODY — box + vertical ribbon (stays put) ──
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: [Self.boxA, Self.boxB, Self.boxC],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: boxW, height: boxH)
                // soft top highlight
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: boxW, height: boxH * 0.34)
                    .offset(y: -boxH * 0.3)
                    .mask(RoundedRectangle(cornerRadius: 9).frame(width: boxW, height: boxH))
                // vertical ribbon down the body
                Rectangle()
                    .fill(LinearGradient(colors: [Self.ribbonHi, Self.ribbon],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: ribbonW, height: boxH)
            }
            .position(x: cx, y: bodyCenterY)

            // ── LID — flat top + bow, lifts off as one piece ──
            lid(width: lidW, height: lidH, ribbonW: ribbonW)
                .rotationEffect(.degrees(lidTilt))
                .position(x: cx, y: lidClosedCenterY - lidLift)
                .opacity(lidOpacity)
        }
        .frame(width: box.width, height: box.height)
    }

    /// The detachable lid: a flat rounded top with a knot + two bow loops.
    private func lid(width: CGFloat, height h: CGFloat, ribbonW: CGFloat) -> some View {
        let loopW = h * 1.05
        let loopH = h * 0.9
        return ZStack {
            // Lid slab
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Self.boxA, Self.boxB],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: h)
            // ribbon stub across the lid
            Rectangle()
                .fill(LinearGradient(colors: [Self.ribbonHi, Self.ribbon],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: ribbonW, height: h)

            // ── Bow on top ──
            // left loop
            Ellipse()
                .fill(LinearGradient(colors: [Self.ribbonHi, Self.ribbon],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: loopW, height: loopH)
                .rotationEffect(.degrees(-32))
                .offset(x: -loopW * 0.42, y: -h * 0.62)
            // right loop
            Ellipse()
                .fill(LinearGradient(colors: [Self.ribbonHi, Self.ribbon],
                                     startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(width: loopW, height: loopH)
                .rotationEffect(.degrees(32))
                .offset(x: loopW * 0.42, y: -h * 0.62)
            // knot
            Circle()
                .fill(LinearGradient(colors: [Self.ribbonHi, Self.ribbon],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: h * 0.6, height: h * 0.6)
                .offset(y: -h * 0.62)
        }
        .frame(width: width, height: h)
    }
}
