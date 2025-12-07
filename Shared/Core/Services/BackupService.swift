import Foundation
import OSLog

/// Service for managing backups and restores
/// Supports automatic and manual backups with versioning
public actor BackupService {
    // MARK: - Properties

    private let logger: OSLog
    private let fileManager = FileManager.default
    private let backupDirectory: URL
    private let maxBackupCount: Int
    private let importExportService: ImportExportService

    // MARK: - Initialization

    public init(
        logger: OSLog? = nil,
        maxBackupCount: Int = 10
    ) {
        self.logger = logger ?? OSLog(subsystem: "com.swiftproxy.app", category: "backup")
        self.maxBackupCount = maxBackupCount
        self.importExportService = ImportExportService(logger: self.logger)

        // Set up backup directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.backupDirectory = appSupport
            .appendingPathComponent("SwiftProxy")
            .appendingPathComponent("Backups")

        // Create backup directory if needed
        // Use local variables to avoid crossing concurrency boundary with non-Sendable FileManager
        let manager = fileManager
        let directory = backupDirectory
        Task {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Create Backup

    /// Create a manual backup
    public func createBackup(
        configurations: [ProxyConfiguration],
        rules: [ProxyRule],
        name: String? = nil
    ) async throws -> Backup {
        os_log(.info, log: logger, "Creating manual backup")

        let timestamp = Date()
        let backupName = name ?? "Manual Backup \(formatDate(timestamp))"
        let backup = Backup(
            id: UUID(),
            name: backupName,
            timestamp: timestamp,
            type: .manual,
            configurations: configurations,
            rules: rules
        )

        try await saveBackup(backup)

        os_log(.info, log: logger, "Manual backup created")

        // Clean up old backups
        await cleanupOldBackups()

        return backup
    }

    /// Create an automatic backup
    public func createAutomaticBackup(
        configurations: [ProxyConfiguration],
        rules: [ProxyRule]
    ) async throws -> Backup {
        os_log(.info, log: logger, "Creating automatic backup")

        let timestamp = Date()
        let backup = Backup(
            id: UUID(),
            name: "Auto Backup \(formatDate(timestamp))",
            timestamp: timestamp,
            type: .automatic,
            configurations: configurations,
            rules: rules
        )

        try await saveBackup(backup)

        os_log(.info, log: logger, "Automatic backup created: \(backup.id)")

        // Clean up old automatic backups
        await cleanupOldBackups()

        return backup
    }

    // MARK: - Restore Backup

    /// Restore from a backup
    public func restoreBackup(_ backup: Backup) async throws -> (configurations: [ProxyConfiguration], rules: [ProxyRule]) {
        os_log(.info, log: logger, "Restoring backup: \(backup.id)")

        return (backup.configurations, backup.rules)
    }

    /// Restore from backup file
    public func restoreFromFile(url: URL) async throws -> (configurations: [ProxyConfiguration], rules: [ProxyRule]) {
        os_log(.info, log: logger, "Restoring from file: \(url.path)")

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(Backup.self, from: data)

        os_log(.info, log: logger, "Backup restored from file")

        return (backup.configurations, backup.rules)
    }

    // MARK: - List Backups

    /// Get all backups
    public func listBackups() async throws -> [Backup] {
        os_log(.info, log: logger, "Listing all backups")

        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        var backups: [Backup] = []

        for url in contents where url.pathExtension == "backup" {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(Backup.self, from: data)
                backups.append(backup)
            } catch {
                os_log(.error, log: logger, "Failed to load backup from \(url.path): \(error.localizedDescription)")
            }
        }

        // Sort by timestamp (newest first)
        backups.sort { $0.timestamp > $1.timestamp }

        os_log(.info, log: logger, "Found \(backups.count) backups")

        return backups
    }

    /// Get backup info
    public func getBackupInfo(_ id: UUID) async throws -> Backup? {
        let backups = try await listBackups()
        return backups.first { $0.id == id }
    }

    // MARK: - Delete Backup

    /// Delete a specific backup
    public func deleteBackup(_ id: UUID) async throws {
        os_log(.info, log: logger, "Deleting backup: \(id)")

        let url = backupDirectory.appendingPathComponent("\(id.uuidString).backup")

        try fileManager.removeItem(at: url)

        os_log(.info, log: logger, "Backup deleted: \(id)")
    }

    /// Delete all backups
    public func deleteAllBackups() async throws {
        os_log(.info, log: logger, "Deleting all backups")

        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents where url.pathExtension == "backup" {
            try fileManager.removeItem(at: url)
        }

        os_log(.info, log: logger, "All backups deleted")
    }

    // MARK: - Export Backup

    /// Export backup to file
    public func exportBackup(_ backup: Backup, to url: URL) async throws {
        os_log(.info, log: logger, "Exporting backup \(backup.id) to \(url.path)")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)

        try data.write(to: url, options: [.atomic])

        os_log(.info, log: logger, "Backup exported successfully")
    }

    // MARK: - Automatic Backup Management

    /// Configure automatic backup
    public func configureAutomaticBackup(enabled: Bool, interval: TimeInterval) {
        os_log(.info, log: logger, "Configuring automatic backup: enabled=\(enabled), interval=\(interval)")

        if enabled {
            // Start automatic backup timer
            // Note: This would need a timer implementation
            os_log(.info, log: logger, "Automatic backup enabled with interval \(interval) seconds")
        } else {
            os_log(.info, log: logger, "Automatic backup disabled")
        }
    }

    // MARK: - Backup Statistics

    /// Get backup statistics
    public func getBackupStatistics() async throws -> BackupStatistics {
        let backups = try await listBackups()

        let manualCount = backups.filter { $0.type == .manual }.count
        let automaticCount = backups.filter { $0.type == .automatic }.count

        let totalSize = try backups.reduce(Int64(0)) { total, backup in
            let url = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            return total + size
        }

        let lastBackup = backups.first?.timestamp

        return BackupStatistics(
            totalBackups: backups.count,
            manualBackups: manualCount,
            automaticBackups: automaticCount,
            totalSize: totalSize,
            lastBackupDate: lastBackup
        )
    }

    // MARK: - Private Helpers

    private func saveBackup(_ backup: Backup) async throws {
        let url = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)

        try data.write(to: url, options: [.atomic])

        os_log(.info, log: logger, "Backup saved to \(url.path)")
    }

    private func cleanupOldBackups() async {
        do {
            let backups = try await listBackups()

            // Keep manual backups, only cleanup automatic ones
            let automaticBackups = backups.filter { $0.type == .automatic }

            if automaticBackups.count > maxBackupCount {
                let toDelete = automaticBackups.dropFirst(maxBackupCount)

                for backup in toDelete {
                    try await deleteBackup(backup.id)
                    os_log(.info, log: logger, "Cleaned up old backup: \(backup.id)")
                }

                os_log(.info, log: logger, "Cleaned up \(toDelete.count) old backups")
            }
        } catch {
            os_log(.error, log: logger, "Failed to cleanup old backups: \(error.localizedDescription)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

public struct Backup: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let timestamp: Date
    public let type: BackupType
    public let configurations: [ProxyConfiguration]
    public let rules: [ProxyRule]

    public var formattedSize: String {
        "N/A" // Could calculate actual size if needed
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

public enum BackupType: String, Codable {
    case manual
    case automatic
}

public struct BackupStatistics {
    public let totalBackups: Int
    public let manualBackups: Int
    public let automaticBackups: Int
    public let totalSize: Int64
    public let lastBackupDate: Date?

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var formattedLastBackup: String {
        guard let date = lastBackupDate else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Backup Errors

public enum BackupError: LocalizedError {
    case backupNotFound
    case invalidBackupData
    case backupDirectoryUnavailable
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "Backup not found"
        case .invalidBackupData:
            return "Invalid backup data"
        case .backupDirectoryUnavailable:
            return "Backup directory unavailable"
        case .exportFailed:
            return "Failed to export backup"
        }
    }
}
