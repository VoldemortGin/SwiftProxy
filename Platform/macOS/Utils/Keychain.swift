import Foundation
import Security
import OSLog
import SwiftProxyCore

/// Thread-safe Keychain wrapper for secure storage of sensitive data
/// Provides type-safe access to keychain items with automatic encoding/decoding
/// All operations are performed synchronously on a dedicated queue for thread safety
public final class Keychain {
    // MARK: - Properties

    private let serviceName: String
    private let accessGroup: String?
    private let logger: OSLog
    private let keychainQueue = DispatchQueue(label: "com.swiftproxy.keychain", qos: .userInitiated)

    // MARK: - Initialization

    /// Initialize a keychain instance
    /// - Parameters:
    ///   - serviceName: Service name to scope keychain items (typically bundle identifier)
    ///   - accessGroup: Optional access group for keychain sharing between apps
    ///   - logger: Logger instance for debugging
    public init(
        serviceName: String = Bundle.main.bundleIdentifier ?? "com.swiftproxy",
        accessGroup: String? = nil,
        logger: OSLog = Logger.securityLog
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
        self.logger = logger
    }

    // MARK: - String Operations

    /// Save a string value to keychain
    public func setString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        try setData(data, forKey: key)
    }

    /// Retrieve a string value from keychain
    public func getString(forKey key: String) throws -> String? {
        guard let data = try getData(forKey: key) else {
            return nil
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return string
    }

    // MARK: - Data Operations

    /// Save raw data to keychain
    public func setData(_ data: Data, forKey key: String) throws {
        try keychainQueue.sync {
            // Build query
            var query = baseQuery(forKey: key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

            // Delete existing item first
            SecItemDelete(query as CFDictionary)

            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)

            guard status == errSecSuccess else {
                os_log(.error, log: logger, "Failed to save keychain item: %@, status: %d", key, status)
                throw KeychainError.saveFailed(status: status)
            }

            os_log(.debug, log: logger, "Saved keychain item: %@", key)
        }
    }

    /// Retrieve raw data from keychain
    public func getData(forKey key: String) throws -> Data? {
        try keychainQueue.sync {
            var query = baseQuery(forKey: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecItemNotFound {
                return nil
            }

            guard status == errSecSuccess else {
                os_log(.error, log: logger, "Failed to retrieve keychain item: %@, status: %d", key, status)
                throw KeychainError.retrievalFailed(status: status)
            }

            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }

            os_log(.debug, log: logger, "Retrieved keychain item: %@", key)
            return data
        }
    }

    // MARK: - Codable Operations

    /// Save a Codable value to keychain
    public func setCodable<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        try setData(data, forKey: key)
    }

    /// Retrieve a Codable value from keychain
    public func getCodable<T: Codable>(forKey key: String, as type: T.Type) throws -> T? {
        guard let data = try getData(forKey: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    // MARK: - Delete Operations

    /// Delete a keychain item
    public func delete(forKey key: String) throws {
        try keychainQueue.sync {
            let query = baseQuery(forKey: key)
            let status = SecItemDelete(query as CFDictionary)

            // Success if item was deleted or didn't exist
            guard status == errSecSuccess || status == errSecItemNotFound else {
                os_log(.error, log: logger, "Failed to delete keychain item: %@, status: %d", key, status)
                throw KeychainError.deleteFailed(status: status)
            }

            os_log(.debug, log: logger, "Deleted keychain item: %@", key)
        }
    }

    /// Delete all keychain items for this service
    public func deleteAll() throws {
        try keychainQueue.sync {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName
            ]

            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            let status = SecItemDelete(query as CFDictionary)

            // Success if items were deleted or none existed
            guard status == errSecSuccess || status == errSecItemNotFound else {
                os_log(.error, log: logger, "Failed to delete all keychain items, status: %d", status)
                throw KeychainError.deleteFailed(status: status)
            }

            os_log(.info, log: logger, "Deleted all keychain items for service: %@", serviceName)
        }
    }

    // MARK: - Query Operations

    /// Check if a keychain item exists
    public func exists(forKey key: String) -> Bool {
        do {
            return try getData(forKey: key) != nil
        } catch {
            return false
        }
    }

    /// Get all keys for this service
    public func allKeys() throws -> [String] {
        try keychainQueue.sync {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll
            ]

            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecItemNotFound {
                return []
            }

            guard status == errSecSuccess else {
                throw KeychainError.retrievalFailed(status: status)
            }

            guard let items = result as? [[String: Any]] else {
                return []
            }

            return items.compactMap { item in
                item[kSecAttrAccount as String] as? String
            }
        }
    }

    // MARK: - Bulk Operations

    /// Save multiple items atomically
    public func setBulk(_ items: [String: Data]) throws {
        // Note: Keychain doesn't support true atomic operations
        // We save items sequentially and rollback on failure
        var savedKeys: [String] = []

        do {
            for (key, data) in items {
                try setData(data, forKey: key)
                savedKeys.append(key)
            }
        } catch {
            // Rollback: delete successfully saved items
            for key in savedKeys {
                try? delete(forKey: key)
            }
            throw error
        }
    }

    /// Retrieve multiple items
    public func getBulk(forKeys keys: [String]) throws -> [String: Data] {
        var result: [String: Data] = [:]

        for key in keys {
            if let data = try getData(forKey: key) {
                result[key] = data
            }
        }

        return result
    }

    // MARK: - Private Methods

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

// MARK: - Keychain Error

public enum KeychainError: Error, LocalizedError {
    case saveFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case encodingFailed
    case decodingFailed
    case unexpectedData
    case itemNotFound
    case duplicateItem

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save keychain item: \(statusMessage(status))"

        case .retrievalFailed(let status):
            return "Failed to retrieve keychain item: \(statusMessage(status))"

        case .deleteFailed(let status):
            return "Failed to delete keychain item: \(statusMessage(status))"

        case .encodingFailed:
            return "Failed to encode data for keychain storage"

        case .decodingFailed:
            return "Failed to decode data from keychain"

        case .unexpectedData:
            return "Unexpected data format in keychain"

        case .itemNotFound:
            return "Keychain item not found"

        case .duplicateItem:
            return "Keychain item already exists"
        }
    }

    private func statusMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Failed to allocate memory"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecAuthFailed:
            return "Authorization failed"
        case errSecDuplicateCallback:
            return "Duplicate callback"
        case errSecInvalidCallback:
            return "Invalid callback"
        default:
            return "Status code: \(status)"
        }
    }
}

// MARK: - Convenience Extensions

extension Keychain {
    /// Namespace for password-specific operations
    public struct Passwords {
        private let keychain: Keychain

        fileprivate init(keychain: Keychain) {
            self.keychain = keychain
        }

        /// Save a password for a specific account/identifier
        public func set(_ password: String, for identifier: String) throws {
            try keychain.setString(password, forKey: "password_\(identifier)")
        }

        /// Retrieve a password for a specific account/identifier
        public func get(for identifier: String) throws -> String? {
            try keychain.getString(forKey: "password_\(identifier)")
        }

        /// Delete a password for a specific account/identifier
        public func delete(for identifier: String) throws {
            try keychain.delete(forKey: "password_\(identifier)")
        }
    }

    /// Access password operations
    public var passwords: Passwords {
        Passwords(keychain: self)
    }
}

// MARK: - Async Wrapper

extension Keychain {
    /// Async wrapper for string operations
    public func setStringAsync(_ value: String, forKey key: String) async throws {
        try await Task {
            try self.setString(value, forKey: key)
        }.value
    }

    public func getStringAsync(forKey key: String) async throws -> String? {
        try await Task {
            try self.getString(forKey: key)
        }.value
    }

    /// Async wrapper for data operations
    public func setDataAsync(_ data: Data, forKey key: String) async throws {
        try await Task {
            try self.setData(data, forKey: key)
        }.value
    }

    public func getDataAsync(forKey key: String) async throws -> Data? {
        try await Task {
            try self.getData(forKey: key)
        }.value
    }

    /// Async wrapper for delete operations
    public func deleteAsync(forKey key: String) async throws {
        try await Task {
            try self.delete(forKey: key)
        }.value
    }

    public func deleteAllAsync() async throws {
        try await Task {
            try self.deleteAll()
        }.value
    }
}

// MARK: - Static Shared Instance

extension Keychain {
    /// Shared keychain instance for application-wide use
    public static let shared = Keychain()
}
