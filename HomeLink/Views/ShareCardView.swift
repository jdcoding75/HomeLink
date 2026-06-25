// ShareCardView.swift
// Pointward › Views
//
// [cleanup] Extracted verbatim from CompassView.swift (safe-containment pass) — an
// independent subview (zero external callers; used only by CompassView, same module,
// callers unchanged). No logic change. (`Triangle` is a shared shape in the module.)

import SwiftUI

// MARK: - ShareCardView

// [copy-declutter ITEM 7] Share-card disabled for v1 (preserved; only caller was
// CompassView.renderShareCard(), also disabled). Re-enable both together.
#if false

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

#endif // [copy-declutter ITEM 7] ShareCardView
