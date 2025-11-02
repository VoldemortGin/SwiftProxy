import Foundation
import OSLog

/// Centralized logging infrastructure using OSLog for optimal performance
/// Categories are separated for better filtering and debugging
public struct Logger {
    // MARK: - Logger Categories

    /// Proxy service operations
    public static let proxyLog = OSLog(subsystem: subsystem, category: "Proxy")

    /// Network monitoring and traffic analysis
    public static let networkLog = OSLog(subsystem: subsystem, category: "Network")

    /// Rule engine and pattern matching
    public static let rulesLog = OSLog(subsystem: subsystem, category: "Rules")

    /// Storage and persistence operations
    public static let storageLog = OSLog(subsystem: subsystem, category: "Storage")

    /// UI and user interaction events
    public static let uiLog = OSLog(subsystem: subsystem, category: "UI")

    /// System extension operations
    public static let extLog = OSLog(subsystem: subsystem, category: "Extension")

    /// Performance metrics and profiling
    public static let performanceLog = OSLog(subsystem: subsystem, category: "Performance")

    /// Security and authentication
    public static let securityLog = OSLog(subsystem: subsystem, category: "Security")

    // MARK: - Configuration

    private static let subsystem = "com.yourcompany.swiftproxy"

    // MARK: - Logging Methods

    /// Log an info message
    public static func info(_ message: String, log: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.info, log: log, "%{public}@ [%{public}@:%d] %{public}@",
               fileName(from: file), function, line, message)
    }

    /// Log a debug message (only in debug builds)
    public static func debug(_ message: String, log: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        os_log(.debug, log: log, "%{public}@ [%{public}@:%d] %{public}@",
               fileName(from: file), function, line, message)
        #endif
    }

    /// Log an error message
    public static func error(_ message: String, log: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.error, log: log, "%{public}@ [%{public}@:%d] %{public}@",
               fileName(from: file), function, line, message)
    }

    /// Log a fault message (critical errors)
    public static func fault(_ message: String, log: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.fault, log: log, "%{public}@ [%{public}@:%d] %{public}@",
               fileName(from: file), function, line, message)
    }

    /// Log an AppError with appropriate severity
    public static func log(error: AppError, log: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        let message = error.errorDescription ?? "Unknown error"

        switch error.severity {
        case .low:
            self.debug(message, log: log, file: file, function: function, line: line)
        case .medium:
            self.info(message, log: log, file: file, function: function, line: line)
        case .high:
            self.error(message, log: log, file: file, function: function, line: line)
        case .critical:
            self.fault(message, log: log, file: file, function: function, line: line)
        }
    }

    // MARK: - Performance Tracking

    /// Begin a signpost interval for performance tracking
    @available(macOS 10.15, *)
    public static func beginInterval(_ name: StaticString, log: OSLog = performanceLog) -> OSSignpostID {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        return signpostID
    }

    /// End a signpost interval
    @available(macOS 10.15, *)
    public static func endInterval(_ name: StaticString, signpostID: OSSignpostID, log: OSLog = performanceLog) {
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }

    /// Emit a signpost event
    @available(macOS 10.15, *)
    public static func signpost(_ name: StaticString, log: OSLog = performanceLog) {
        os_signpost(.event, log: log, name: name)
    }

    // MARK: - Private Helpers

    private static func fileName(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }
}

// MARK: - Performance Measurement

/// Measure and log the performance of a code block
@available(macOS 10.15, *)
public func measurePerformance<T>(
    _ name: StaticString,
    log: OSLog = Logger.performanceLog,
    operation: () throws -> T
) rethrows -> T {
    let signpostID = Logger.beginInterval(name, log: log)
    defer {
        Logger.endInterval(name, signpostID: signpostID, log: log)
    }

    return try operation()
}

/// Async version of performance measurement
@available(macOS 10.15, *)
public func measurePerformance<T>(
    _ name: StaticString,
    log: OSLog = Logger.performanceLog,
    operation: () async throws -> T
) async rethrows -> T {
    let signpostID = Logger.beginInterval(name, log: log)
    defer {
        Logger.endInterval(name, signpostID: signpostID, log: log)
    }

    return try await operation()
}

// MARK: - Debug Helpers

#if DEBUG
/// Print object in a formatted way for debugging
public func debugPrint<T>(_ value: T, label: String? = nil, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    let labelStr = label.map { "\($0): " } ?? ""

    print("[\(fileName):\(line)] \(labelStr)\(value)")
}

/// Dump object structure for debugging
public func debugDump<T>(_ value: T, label: String? = nil, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent

    print("[\(fileName):\(line)]", label ?? "Debug Dump:")
    dump(value)
}
#endif
