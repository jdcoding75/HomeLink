// PersonSwitcherSheet.swift
// Pointward › Views
//
// [cleanup] Extracted verbatim from CompassView.swift (safe-containment pass) — an
// independent subview (zero external callers; used only by CompassView, same module,
// callers unchanged). No logic change.

import SwiftUI
import CoreLocation

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
