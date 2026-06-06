// PersistenceServiceProtocol.swift
// Pointward › Services › Protocols

import Foundation

protocol PersistenceServiceProtocol {
    func sync() async throws
    func pull() async throws
    func deleteRemoteData() async throws
}
