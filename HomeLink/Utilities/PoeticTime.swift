// PoeticTime.swift
// Pointward › Utilities
//
// Timestamps that read like a journal, not a chat log:
// "moments ago" · "this morning" · "yesterday evening" · "Monday" ·
// "last Tuesday" · "a while ago"

import Foundation

enum PoeticTime {

    static func string(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date.now

        if now.timeIntervalSince(date) < 10 * 60 {
            return "moments ago"
        }

        if calendar.isDateInToday(date) {
            switch calendar.component(.hour, from: date) {
            case 0..<6:   return "in the night"
            case 6..<12:  return "this morning"
            case 12..<17: return "this afternoon"
            default:      return "this evening"
            }
        }

        if calendar.isDateInYesterday(date) {
            return calendar.component(.hour, from: date) >= 17
                ? "yesterday evening"
                : "yesterday"
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        let weekday = date.formatted(.dateTime.weekday(.wide)).lowercased()
        if days < 7  { return weekday }                 // "monday"
        if days < 14 { return "last \(weekday)" }       // "last tuesday"
        if days < 31 { return "earlier this month" }
        return "a while ago"
    }
}
