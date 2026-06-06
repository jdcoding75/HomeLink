// SupabaseConfig.swift
// Pointward › Utilities
//
// Phase 2 backend credentials. Fill in the two values below once the
// Supabase project exists — nothing else in the codebase needs touching.
// While they're empty, SupabaseService stays dormant and the app runs
// fully offline exactly as before.

import Foundation

enum SupabaseConfig {
    static let url = "https://jlbgdlgwtrkmqcfnomlr.supabase.co"

    /// The project's public anon key (safe to ship in the client).
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsYmdkbGd3dHJrbXFjZm5vbWxyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3NjYwODYsImV4cCI6MjA5NjM0MjA4Nn0.QN0-lU4LrxEjUUqsR0r2dtZHeDbSajSHXeyb3H_NcHM"

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty
    }
}
