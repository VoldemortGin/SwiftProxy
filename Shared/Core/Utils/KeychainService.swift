import Foundation

/// Cross-platform protocol for secure keychain storage
/// Abstracts platform-specific keychain implementations (macOS/iOS)
/// Provides password management with error handling and thread safety
public protocol KeychainServiceProtocol: Sendable {
    /// Save a password for a specific identifier
    /// - Parameters:
    ///   - password: The password to store securely
    ///   - identifier: Unique identifier for the password (typically UUID string)
    /// - Throws: KeychainServiceError if save fails
    func savePassword(_ password: String, for identifier: String) async throws

    /// Retrieve a password for a specific identifier
    /// - Parameter identifier: Unique identifier for the password
    /// - Returns: The stored password, or nil if not found
    /// - Throws: KeychainServiceError if retrieval fails (other than not found)
    func loadPassword(for identifier: String) async throws -> String?

    /// Delete a password for a specific identifier
    /// - Parameter identifier: Unique identifier for the password
    /// - Throws: KeychainServiceError if deletion fails
    func deletePassword(for identifier: String) async throws

    /// Delete all passwords for the service
    /// - Throws: KeychainServiceError if bulk deletion fails
    func deleteAllPasswords() async throws

    /// Check if a password exists for a specific identifier
    /// - Parameter identifier: Unique identifier for the password
    /// - Returns: True if password exists, false otherwise
    func passwordExists(for identifier: String) async -> Bool

    /// Migrate passwords from old identifiers to new ones
    /// - Parameter migrations: Dictionary mapping old identifiers to new ones
    /// - Throws: KeychainServiceError if migration fails
    func migratePasswords(_ migrations: [String: String]) async throws
}

/// Errors that can occur during keychain operations
public enum KeychainServiceError: Error, LocalizedError {
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case migrationFailed(underlying: Error)
    case invalidIdentifier
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save password to keychain: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load password from keychain: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete password from keychain: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate passwords: \(error.localizedDescription)"
        case .invalidIdentifier:
            return "Invalid password identifier provided"
        case .serviceUnavailable:
            return "Keychain service is not available"
        }
    }
}

/// Default implementation for no-op keychain (used for testing or when keychain is unavailable)
public final class NoOpKeychainService: KeychainServiceProtocol {
    public init() {}

    public func savePassword(_ password: String, for identifier: String) async throws {
        // No-op: doesn't save anything
    }

    public func loadPassword(for identifier: String) async throws -> String? {
        return nil
    }

    public func deletePassword(for identifier: String) async throws {
        // No-op: nothing to delete
    }

    public func deleteAllPasswords() async throws {
        // No-op: nothing to delete
    }

    public func passwordExists(for identifier: String) async -> Bool {
        return false
    }

    public func migratePasswords(_ migrations: [String: String]) async throws {
        // No-op: nothing to migrate
    }
}
