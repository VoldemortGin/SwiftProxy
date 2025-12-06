import Foundation
import SwiftProxyCore

/// macOS implementation of KeychainServiceProtocol
/// Adapts the existing Keychain utility to conform to the cross-platform protocol
/// Thread-safe and async-compatible for Swift concurrency
public final class KeychainServiceAdapter: KeychainServiceProtocol {
    // MARK: - Properties

    private let keychain: Keychain

    // MARK: - Initialization

    /// Initialize with an existing keychain instance
    /// - Parameter keychain: The keychain instance to wrap (defaults to shared instance)
    public init(keychain: Keychain = .shared) {
        self.keychain = keychain
    }

    /// Initialize with custom service name and access group
    /// - Parameters:
    ///   - serviceName: Service name for keychain items
    ///   - accessGroup: Optional access group for keychain sharing
    public convenience init(serviceName: String, accessGroup: String? = nil) {
        let keychain = Keychain(serviceName: serviceName, accessGroup: accessGroup)
        self.init(keychain: keychain)
    }

    // MARK: - KeychainServiceProtocol

    public func savePassword(_ password: String, for identifier: String) async throws {
        do {
            try keychain.passwords.set(password, for: identifier)
        } catch {
            throw KeychainServiceError.saveFailed(underlying: error)
        }
    }

    public func loadPassword(for identifier: String) async throws -> String? {
        do {
            return try keychain.passwords.get(for: identifier)
        } catch {
            // If item not found, return nil instead of throwing
            if let keychainError = error as? KeychainError,
               case .itemNotFound = keychainError {
                return nil
            }
            throw KeychainServiceError.loadFailed(underlying: error)
        }
    }

    public func deletePassword(for identifier: String) async throws {
        do {
            try keychain.passwords.delete(for: identifier)
        } catch {
            throw KeychainServiceError.deleteFailed(underlying: error)
        }
    }

    public func deleteAllPasswords() async throws {
        do {
            try keychain.deleteAll()
        } catch {
            throw KeychainServiceError.deleteFailed(underlying: error)
        }
    }

    public func passwordExists(for identifier: String) async -> Bool {
        do {
            let password = try await loadPassword(for: identifier)
            return password != nil
        } catch {
            return false
        }
    }

    public func migratePasswords(_ migrations: [String: String]) async throws {
        do {
            for (oldIdentifier, newIdentifier) in migrations {
                // Load password from old identifier
                if let password = try keychain.passwords.get(for: oldIdentifier) {
                    // Save to new identifier
                    try keychain.passwords.set(password, for: newIdentifier)

                    // Delete old identifier
                    try keychain.passwords.delete(for: oldIdentifier)
                }
            }
        } catch {
            throw KeychainServiceError.migrationFailed(underlying: error)
        }
    }
}

// MARK: - Convenience Extensions

extension KeychainServiceAdapter {
    /// Shared adapter instance using the default keychain
    public static let shared = KeychainServiceAdapter()
}
