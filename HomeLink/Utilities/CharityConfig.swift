// CharityConfig.swift
// Pointward › Utilities
//
// Giving back — 50% of every Pro purchase goes to the featured charity.
// Not a promotion. Just how we work.

import Foundation

struct CharityPartner {
    let name: String
    let emoji: String
    let description: String
    let websiteURL: String
    let donationURL: String
    let startDate: Date
    let endDate: Date
}

enum CharityConfig {

    static let partners: [CharityPartner] = [
        CharityPartner(
            name: "military families",
            emoji: "🎖️",
            description: "supporting families separated by deployment",
            websiteURL: "https://pointward.app",
            donationURL: "https://pointward.app",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        ),
    ]

    /// The partner whose window contains `date`, if any. Pure and date-injectable
    /// so the "no active charity" case is testable without time travel.
    static func partner(at date: Date) -> CharityPartner? {
        partners.first { date >= $0.startDate && date <= $0.endDate }
    }

    /// The partner featured right now, if any window is active.
    static var current: CharityPartner? { partner(at: Date()) }
}
