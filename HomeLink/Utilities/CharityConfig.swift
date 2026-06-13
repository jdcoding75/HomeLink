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

    // Window anchors — computed ONCE, before any partner is built, and pinned to
    // the START OF THE LAUNCH DAY. [fix 2026-06-13] Previously startDate was a
    // bare `Date()` inside the partner literal. Because `partners` is a lazy
    // `static let`, it initialized only on first access — which happens INSIDE
    // `partner(at: Date())`, AFTER that call's argument `Date()` was already
    // evaluated. So startDate landed a few microseconds in the FUTURE relative to
    // the query date, the `date >= startDate` window check failed, and `current`
    // reported NO active charity (GivingBackHardeningTests.testCurrentCharityReturns).
    // Anchoring to start-of-day makes startDate deterministically earlier than any
    // query instant, eliminating the argument-evaluation ordering race.
    private static let featuredStart = Calendar.current.startOfDay(for: Date())
    private static let featuredEnd =
        Calendar.current.date(byAdding: .day, value: 60, to: featuredStart)!

    static let partners: [CharityPartner] = [
        CharityPartner(
            name: "military families",
            emoji: "🎖️",
            description: "supporting families separated by deployment",
            websiteURL: "https://pointward.app",
            donationURL: "https://pointward.app",
            startDate: featuredStart,
            endDate: featuredEnd
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
