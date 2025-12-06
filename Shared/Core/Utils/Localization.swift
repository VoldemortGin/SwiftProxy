import Foundation

/// Localization helper for SwiftProxy
/// Provides type-safe access to localized strings
public enum L10n {
    // MARK: - App
    public static let appName = localized("app_name")
    public static let appDescription = localized("app_description")

    // MARK: - Tabs
    public static let tabProxy = localized("tab_proxy")
    public static let tabConnections = localized("tab_connections")
    public static let tabStatistics = localized("tab_statistics")
    public static let tabSettings = localized("tab_settings")

    // MARK: - Status
    public static let statusActive = localized("status_active")
    public static let statusInactive = localized("status_inactive")
    public static let statusConnected = localized("status_connected")
    public static let statusConnecting = localized("status_connecting")
    public static let statusDisconnected = localized("status_disconnected")
    public static let statusError = localized("status_error")

    // MARK: - Proxy Toggle
    public static let proxyEnabled = localized("proxy_enabled")
    public static let proxyDisabled = localized("proxy_disabled")
    public static let proxyEnable = localized("proxy_enable")
    public static let proxyDisable = localized("proxy_disable")
    public static let proxyToggle = localized("proxy_toggle")

    // MARK: - Configuration
    public static let configName = localized("config_name")
    public static let configType = localized("config_type")
    public static let configHost = localized("config_host")
    public static let configPort = localized("config_port")
    public static let configUsername = localized("config_username")
    public static let configPassword = localized("config_password")
    public static let configRequiresAuth = localized("config_requires_auth")
    public static let configNoSelection = localized("config_no_selection")
    public static let configNew = localized("config_new")
    public static let configEdit = localized("config_edit")
    public static let configDelete = localized("config_delete")
    public static let configDuplicate = localized("config_duplicate")
    public static let configImport = localized("config_import")
    public static let configExport = localized("config_export")

    // MARK: - Statistics
    public static let statsRequests = localized("stats_requests")
    public static let statsDownloaded = localized("stats_downloaded")
    public static let statsUploaded = localized("stats_uploaded")
    public static let statsTotalBytesIn = localized("stats_total_bytes_in")
    public static let statsTotalBytesOut = localized("stats_total_bytes_out")
    public static let statsActiveConnections = localized("stats_active_connections")
    public static let statsTotalConnections = localized("stats_total_connections")
    public static let statsSuccessRate = localized("stats_success_rate")
    public static let statsAverageLatency = localized("stats_average_latency")
    public static let statsPeakBandwidth = localized("stats_peak_bandwidth")
    public static let statsExport = localized("stats_export")
    public static let statsClear = localized("stats_clear")

    // MARK: - Rules
    public static let rulesTitle = localized("rules_title")
    public static let rulesAdd = localized("rules_add")
    public static let rulesEdit = localized("rules_edit")
    public static let rulesDelete = localized("rules_delete")
    public static let rulesImport = localized("rules_import")
    public static let rulesExport = localized("rules_export")
    public static let rulesType = localized("rules_type")
    public static let rulesPattern = localized("rules_pattern")
    public static let rulesPolicy = localized("rules_policy")
    public static let rulesEnabled = localized("rules_enabled")

    // MARK: - Settings
    public static let settingsGeneral = localized("settings_general")
    public static let settingsNetwork = localized("settings_network")
    public static let settingsSecurity = localized("settings_security")
    public static let settingsAdvanced = localized("settings_advanced")
    public static let settingsAbout = localized("settings_about")
    public static let settingsLaunchAtLogin = localized("settings_launch_at_login")
    public static let settingsShowInMenuBar = localized("settings_show_in_menu_bar")
    public static let settingsNotifications = localized("settings_notifications")
    public static let settingsDarkMode = localized("settings_dark_mode")
    public static let settingsLanguage = localized("settings_language")

    // MARK: - Backup & Restore
    public static let backupTitle = localized("backup_title")
    public static let backupCreate = localized("backup_create")
    public static let backupRestore = localized("backup_restore")
    public static let backupAuto = localized("backup_auto")
    public static let backupLocation = localized("backup_location")
    public static let backupLast = localized("backup_last")
    public static let backupList = localized("backup_list")
    public static let backupDelete = localized("backup_delete")

    // MARK: - Import/Export
    public static let importTitle = localized("import_title")
    public static let importFromFile = localized("import_from_file")
    public static let importFromURL = localized("import_from_url")
    public static let importFromClipboard = localized("import_from_clipboard")
    public static let exportTitle = localized("export_title")
    public static let exportAsJSON = localized("export_as_json")
    public static let exportAsSurge = localized("export_as_surge")
    public static let exportSuccess = localized("export_success")
    public static let importSuccess = localized("import_success")

    // MARK: - Onboarding
    public static let onboardingWelcomeTitle = localized("onboarding_welcome_title")
    public static let onboardingWelcomeMessage = localized("onboarding_welcome_message")
    public static let onboardingFeaturesTitle = localized("onboarding_features_title")
    public static let onboardingFeaturesMessage = localized("onboarding_features_message")
    public static let onboardingSetupTitle = localized("onboarding_setup_title")
    public static let onboardingSetupMessage = localized("onboarding_setup_message")
    public static let onboardingPermissionsTitle = localized("onboarding_permissions_title")
    public static let onboardingPermissionsMessage = localized("onboarding_permissions_message")
    public static let onboardingCompleteTitle = localized("onboarding_complete_title")
    public static let onboardingCompleteMessage = localized("onboarding_complete_message")
    public static let onboardingNext = localized("onboarding_next")
    public static let onboardingSkip = localized("onboarding_skip")
    public static let onboardingFinish = localized("onboarding_finish")
    public static let onboardingPrevious = localized("onboarding_previous")

    // MARK: - Actions
    public static let actionSave = localized("action_save")
    public static let actionCancel = localized("action_cancel")
    public static let actionDelete = localized("action_delete")
    public static let actionEdit = localized("action_edit")
    public static let actionRefresh = localized("action_refresh")
    public static let actionClear = localized("action_clear")
    public static let actionReset = localized("action_reset")
    public static let actionApply = localized("action_apply")
    public static let actionOK = localized("action_ok")
    public static let actionClose = localized("action_close")
    public static let actionOpen = localized("action_open")
    public static let actionBrowse = localized("action_browse")

    // MARK: - Errors
    public static let errorTitle = localized("error_title")
    public static let errorNetwork = localized("error_network")
    public static let errorConfiguration = localized("error_configuration")
    public static let errorConnectionFailed = localized("error_connection_failed")
    public static let errorAuthFailed = localized("error_auth_failed")
    public static let errorInvalidInput = localized("error_invalid_input")
    public static let errorFileNotFound = localized("error_file_not_found")
    public static let errorPermissionDenied = localized("error_permission_denied")

    // MARK: - Confirmations
    public static let confirmDeleteTitle = localized("confirm_delete_title")
    public static let confirmDeleteMessage = localized("confirm_delete_message")
    public static let confirmResetTitle = localized("confirm_reset_title")
    public static let confirmResetMessage = localized("confirm_reset_message")
    public static let confirmClearTitle = localized("confirm_clear_title")
    public static let confirmClearMessage = localized("confirm_clear_message")

    // MARK: - Accessibility
    public static let accessibilityProxyToggle = localized("accessibility_proxy_toggle")
    public static let accessibilityStatusIndicator = localized("accessibility_status_indicator")
    public static let accessibilityConfigurationList = localized("accessibility_configuration_list")
    public static let accessibilityStatisticsChart = localized("accessibility_statistics_chart")
    public static let accessibilitySettingsPanel = localized("accessibility_settings_panel")
    public static let accessibilityMenuBar = localized("accessibility_menu_bar")

    // MARK: - Notifications
    public static let notificationProxyEnabled = localized("notification_proxy_enabled")
    public static let notificationProxyDisabled = localized("notification_proxy_disabled")
    public static let notificationConfigSaved = localized("notification_config_saved")
    public static let notificationBackupCreated = localized("notification_backup_created")
    public static let notificationRestoreComplete = localized("notification_restore_complete")

    // MARK: - Menu
    public static let menuAbout = localized("menu_about")
    public static let menuPreferences = localized("menu_preferences")
    public static let menuQuit = localized("menu_quit")
    public static let menuShowMainWindow = localized("menu_show_main_window")
    public static let menuQuickStatus = localized("menu_quick_status")

    // MARK: - Misc
    public static let loading = localized("loading")
    public static let noData = localized("no_data")
    public static let search = localized("search")
    public static let filter = localized("filter")
    public static let sort = localized("sort")
    public static let viewDetails = localized("view_details")
    public static let hideDetails = localized("hide_details")

    // MARK: - Helper
    private static func localized(_ key: String) -> String {
        return NSLocalizedString(key, bundle: .main, comment: "")
    }
}

/// Extension for easy localization in SwiftUI
public extension String {
    /// Returns localized string for this key
    var localized: String {
        return NSLocalizedString(self, bundle: .main, comment: "")
    }

    /// Returns localized string with formatted arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, bundle: .main, comment: ""), arguments: arguments)
    }
}
