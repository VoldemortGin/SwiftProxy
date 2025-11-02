import Foundation

/// Comprehensive error types for the SwiftProxy application
/// Provides detailed error information with localized descriptions
public enum AppError: Error, Equatable, Codable {
    // MARK: - Proxy Errors

    case proxyNotAuthorized
    case proxyConfigurationInvalid(String)
    case proxyConnectionFailed(String)
    case proxyAlreadyEnabled
    case proxyNotEnabled
    case proxyServerUnreachable(String)
    case proxyAuthenticationFailed
    case proxyNotSupported(String)

    // MARK: - Network Errors

    case networkUnavailable
    case connectionTimeout
    case requestFailed(String)
    case invalidURL(String)
    case invalidResponse
    case sslError(String)

    // MARK: - Rule Errors

    case ruleValidationFailed(String)
    case ruleNotFound(UUID)
    case duplicateRule
    case invalidPattern(String)
    case ruleConflict(String)

    // MARK: - Storage Errors

    case storageReadFailed(String)
    case storageWriteFailed(String)
    case storageCorrupted
    case keychainAccessFailed(String)
    case dataEncodingFailed
    case dataDecodingFailed

    // MARK: - Extension Errors

    case extensionNotInstalled
    case extensionNotEnabled
    case extensionCommunicationFailed(String)
    case extensionStartFailed(String)

    // MARK: - Permission Errors

    case permissionDenied(String)
    case systemExtensionPermissionRequired
    case networkExtensionPermissionRequired

    // MARK: - Generic Errors

    case unknown(Error)
    case invalidState(String)
    case operationCancelled
    case timeout
    case notImplemented

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        // Proxy Errors
        case .proxyNotAuthorized:
            return "Not authorized to modify system proxy settings. Please grant permission in System Preferences."

        case .proxyConfigurationInvalid(let reason):
            return "Invalid proxy configuration: \(reason)"

        case .proxyConnectionFailed(let reason):
            return "Failed to connect to proxy server: \(reason)"

        case .proxyAlreadyEnabled:
            return "Proxy is already enabled"

        case .proxyNotEnabled:
            return "Proxy is not currently enabled"

        case .proxyServerUnreachable(let host):
            return "Proxy server \(host) is unreachable"

        case .proxyAuthenticationFailed:
            return "Proxy authentication failed. Please check username and password."

        case .proxyNotSupported(let reason):
            return "Proxy operation not supported: \(reason)"

        // Network Errors
        case .networkUnavailable:
            return "Network connection unavailable"

        case .connectionTimeout:
            return "Connection timed out"

        case .requestFailed(let reason):
            return "Request failed: \(reason)"

        case .invalidURL(let url):
            return "Invalid URL: \(url)"

        case .invalidResponse:
            return "Received invalid response from server"

        case .sslError(let reason):
            return "SSL/TLS error: \(reason)"

        // Rule Errors
        case .ruleValidationFailed(let reason):
            return "Rule validation failed: \(reason)"

        case .ruleNotFound(let id):
            return "Rule not found: \(id)"

        case .duplicateRule:
            return "A rule with the same pattern already exists"

        case .invalidPattern(let pattern):
            return "Invalid pattern: \(pattern)"

        case .ruleConflict(let reason):
            return "Rule conflict: \(reason)"

        // Storage Errors
        case .storageReadFailed(let reason):
            return "Failed to read from storage: \(reason)"

        case .storageWriteFailed(let reason):
            return "Failed to write to storage: \(reason)"

        case .storageCorrupted:
            return "Storage data is corrupted"

        case .keychainAccessFailed(let reason):
            return "Keychain access failed: \(reason)"

        case .dataEncodingFailed:
            return "Failed to encode data"

        case .dataDecodingFailed:
            return "Failed to decode data"

        // Extension Errors
        case .extensionNotInstalled:
            return "System extension is not installed"

        case .extensionNotEnabled:
            return "System extension is not enabled"

        case .extensionCommunicationFailed(let reason):
            return "Failed to communicate with extension: \(reason)"

        case .extensionStartFailed(let reason):
            return "Failed to start extension: \(reason)"

        // Permission Errors
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"

        case .systemExtensionPermissionRequired:
            return "System Extension permission is required. Please allow in System Preferences > Privacy & Security."

        case .networkExtensionPermissionRequired:
            return "Network Extension permission is required. Please allow in System Preferences > Network."

        // Generic Errors
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"

        case .invalidState(let reason):
            return "Invalid state: \(reason)"

        case .operationCancelled:
            return "Operation was cancelled"

        case .timeout:
            return "Operation timed out"

        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }

    public var failureReason: String? {
        switch self {
        case .proxyNotAuthorized:
            return "The application does not have permission to modify system network settings."

        case .networkUnavailable:
            return "The device is not connected to the internet."

        case .storageCorrupted:
            return "The stored data file has been corrupted or modified."

        case .extensionNotEnabled:
            return "The Network Extension has not been enabled in System Preferences."

        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .proxyNotAuthorized:
            return "Go to System Preferences > Security & Privacy and grant SwiftProxy permission to modify network settings."

        case .networkUnavailable:
            return "Check your internet connection and try again."

        case .storageCorrupted:
            return "The app will attempt to reset the storage. Your custom configurations may be lost."

        case .extensionNotEnabled:
            return "Go to System Preferences > Network and enable the SwiftProxy extension."

        case .proxyAuthenticationFailed:
            return "Verify your proxy username and password and try again."

        default:
            return "Please try again or contact support if the problem persists."
        }
    }

    // MARK: - Error Classification

    public var isRecoverable: Bool {
        switch self {
        case .proxyConfigurationInvalid,
             .ruleValidationFailed,
             .invalidPattern,
             .invalidURL,
             .connectionTimeout,
             .proxyAuthenticationFailed:
            return true

        case .storageCorrupted,
             .extensionNotInstalled:
            return false

        default:
            return true
        }
    }

    public var shouldRetry: Bool {
        switch self {
        case .connectionTimeout,
             .networkUnavailable,
             .proxyServerUnreachable,
             .requestFailed:
            return true

        default:
            return false
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .proxyNotAuthorized,
             .systemExtensionPermissionRequired,
             .networkExtensionPermissionRequired,
             .storageCorrupted:
            return .critical

        case .extensionNotInstalled,
             .extensionNotEnabled,
             .proxyConfigurationInvalid:
            return .high

        case .proxyConnectionFailed,
             .requestFailed,
             .ruleValidationFailed:
            return .medium

        case .operationCancelled,
             .duplicateRule:
            return .low

        default:
            return .medium
        }
    }
}

// MARK: - Error Severity

public enum ErrorSeverity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    public var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Codable Implementation

extension AppError {
    enum CodingKeys: String, CodingKey {
        case type
        case message
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let message = try container.decodeIfPresent(String.self, forKey: .message)

        switch type {
        case "proxyNotAuthorized":
            self = .proxyNotAuthorized
        case "proxyConfigurationInvalid":
            self = .proxyConfigurationInvalid(message ?? "")
        case "proxyConnectionFailed":
            self = .proxyConnectionFailed(message ?? "")
        case "proxyAlreadyEnabled":
            self = .proxyAlreadyEnabled
        case "proxyNotEnabled":
            self = .proxyNotEnabled
        case "proxyNotSupported":
            self = .proxyNotSupported(message ?? "")
        case "networkUnavailable":
            self = .networkUnavailable
        case "connectionTimeout":
            self = .connectionTimeout
        case "storageCorrupted":
            self = .storageCorrupted
        case "operationCancelled":
            self = .operationCancelled
        case "timeout":
            self = .timeout
        default:
            self = .invalidState(message ?? "Unknown error type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .proxyNotAuthorized:
            try container.encode("proxyNotAuthorized", forKey: .type)

        case .proxyConfigurationInvalid(let message):
            try container.encode("proxyConfigurationInvalid", forKey: .type)
            try container.encode(message, forKey: .message)

        case .proxyConnectionFailed(let message):
            try container.encode("proxyConnectionFailed", forKey: .type)
            try container.encode(message, forKey: .message)

        case .proxyAlreadyEnabled:
            try container.encode("proxyAlreadyEnabled", forKey: .type)

        case .proxyNotEnabled:
            try container.encode("proxyNotEnabled", forKey: .type)

        case .proxyNotSupported(let message):
            try container.encode("proxyNotSupported", forKey: .type)
            try container.encode(message, forKey: .message)

        case .networkUnavailable:
            try container.encode("networkUnavailable", forKey: .type)

        case .connectionTimeout:
            try container.encode("connectionTimeout", forKey: .type)

        case .storageCorrupted:
            try container.encode("storageCorrupted", forKey: .type)

        case .operationCancelled:
            try container.encode("operationCancelled", forKey: .type)

        case .timeout:
            try container.encode("timeout", forKey: .type)

        default:
            try container.encode("unknown", forKey: .type)
            try container.encode(errorDescription ?? "", forKey: .message)
        }
    }
}

// MARK: - Error Equatable

extension AppError {
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.proxyNotAuthorized, .proxyNotAuthorized):
            return true
        case (.proxyAlreadyEnabled, .proxyAlreadyEnabled):
            return true
        case (.proxyNotEnabled, .proxyNotEnabled):
            return true
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.connectionTimeout, .connectionTimeout):
            return true
        case (.storageCorrupted, .storageCorrupted):
            return true
        case (.operationCancelled, .operationCancelled):
            return true
        case (.timeout, .timeout):
            return true

        case (.proxyConfigurationInvalid(let l), .proxyConfigurationInvalid(let r)):
            return l == r
        case (.proxyConnectionFailed(let l), .proxyConnectionFailed(let r)):
            return l == r
        case (.proxyNotSupported(let l), .proxyNotSupported(let r)):
            return l == r
        case (.ruleValidationFailed(let l), .ruleValidationFailed(let r)):
            return l == r

        default:
            return false
        }
    }
}

// MARK: - Result Type Extension

extension Result where Failure == AppError {
    /// Convert to an optional value, discarding the error
    public var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    /// Convert to an optional error, discarding the success value
    public var error: AppError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
