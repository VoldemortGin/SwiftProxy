import SwiftUI
import OSLog
import SwiftProxyCore
import UserNotifications
import Combine

/// Main application entry point for SwiftProxy
@main
struct SwiftProxyApp: App {
    // MARK: - Properties

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel: MainViewModel
    private let ruleService: RuleServiceProtocol
    @State private var showingConfigEditor = false

    // MARK: - Initialization

    init() {
        // Log application startup
        os_log(.info, log: OSLog(subsystem: "com.swiftproxy.app", category: "app"), "SwiftProxy starting...")

        // Create proxy service
        let proxyService = ProxyService(logger: Logger.proxyLog)

        // Create rule service
        do {
            ruleService = try RuleService(logger: Logger.rulesLog)
        } catch {
            os_log(.error, log: Logger.rulesLog, "Failed to initialize RuleService: %@", error.localizedDescription)
            // Use mock service as fallback
            ruleService = MockRuleService()
        }

        // Create view model
        let vm = MainViewModel(proxyService: proxyService)
        _viewModel = StateObject(wrappedValue: vm)

        // Request notification authorization at startup
        Task { @MainActor in
            await NotificationManager.shared.requestAuthorization()
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup(content: {
            MainView(viewModel: viewModel, ruleService: ruleService)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Pass viewModel to AppDelegate for menu bar integration
                    appDelegate.viewModel = viewModel
                }
                .sheet(isPresented: $showingConfigEditor) {
                    NavigationStack {
                        ConfigurationEditorView(
                            configuration: nil,
                            onSave: { config in
                                Task {
                                    await viewModel.saveConfiguration(config)
                                    NotificationManager.shared.notifyConfigurationSaved(name: config.name)
                                    showingConfigEditor = false
                                }
                            },
                            onCancel: {
                                showingConfigEditor = false
                            }
                        )
                    }
                    .frame(minWidth: 500, minHeight: 600)
                }
        })
        .commands {
            proxyCommands
            viewCommands
            windowCommands
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView(viewModel: viewModel, ruleService: ruleService)
                .frame(minWidth: 700, minHeight: 500)
        }
    }

    // MARK: - Commands

    private var proxyCommands: some Commands {
        Group {
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftProxy") {
                    showAbout()
                }
            }

            CommandGroup(after: .newItem) {
                Button("New Proxy Configuration...") {
                    showingConfigEditor = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button(viewModel.isProxyEnabled ? "Disable Proxy" : "Enable Proxy") {
                    Task {
                        await toggleProxyWithNotification()
                    }
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(viewModel.currentConfiguration == nil && !viewModel.isProxyEnabled)
            }
        }
    }

    private var viewCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Refresh") {
                Task {
                    await viewModel.loadConfigurations()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Clear Requests") {
                viewModel.clearRequests()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("Clear Notifications") {
                NotificationManager.shared.clearAllNotifications()
            }
            .keyboardShortcut("k", modifiers: [.command, .option])
        }
    }

    private var windowCommands: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button("Show Quick Status") {
                appDelegate.showQuickStatus()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }

    // MARK: - Methods

    private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                NSApplication.AboutPanelOptionKey.applicationName: "SwiftProxy",
                NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2024 SwiftProxy"
            ]
        )
    }

    private func toggleProxyWithNotification() async {
        let wasEnabled = viewModel.isProxyEnabled
        await viewModel.toggleProxy()

        // Send notification based on result
        if viewModel.isProxyEnabled && !wasEnabled {
            if let config = viewModel.currentConfiguration {
                NotificationManager.shared.notifyProxyEnabled(configuration: config)
            }
        } else if !viewModel.isProxyEnabled && wasEnabled {
            NotificationManager.shared.notifyProxyDisabled()
        }

        // Handle errors
        if let error = viewModel.errorMessage {
            let appError = AppError.proxyConnectionFailed(error)
            NotificationManager.shared.notifyProxyError(appError)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var viewModel: MainViewModel?  // Injected from App
    private var statusObserver: AnyCancellable?
    private let memoryHandler = MemoryPressureHandler(
        logger: OSLog(subsystem: "com.swiftproxy.app", category: "memory")
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupMemoryPressureMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running when windows are closed
    }

    private func setupMenuBar() {
        // Create status item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon(isEnabled: false)
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.animates = true
    }

    private func updateStatusIcon(isEnabled: Bool) {
        guard let button = statusItem?.button else { return }

        let iconName = isEnabled ? "network.badge.shield.half.filled" : "network"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "SwiftProxy")

        // Color the icon based on status
        if isEnabled {
            button.contentTintColor = .systemGreen
        } else {
            button.contentTintColor = nil
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            Task { @MainActor in
                showContextMenu()
            }
        } else {
            // Left-click: toggle popover
            togglePopover()
        }
    }

    @MainActor
    private func showContextMenu() {
        let menu = NSMenu()

        // Proxy toggle
        let toggleTitle = viewModel?.isProxyEnabled == true ? "Disable Proxy" : "Enable Proxy"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleProxy), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Current configuration
        if let config = viewModel?.currentConfiguration {
            let configItem = NSMenuItem(title: "Using: \(config.name)", action: nil, keyEquivalent: "")
            configItem.isEnabled = false
            menu.addItem(configItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Main window
        let openItem = NSMenuItem(title: "Open SwiftProxy", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit SwiftProxy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Show menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Clear menu to allow left-click popover
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showQuickStatus()
        }
    }

    func showQuickStatus() {
        guard let button = statusItem?.button,
              let popover = popover,
              let viewModel = viewModel else {
            return
        }

        // Create and set content
        let statusView = QuickStatusPopover(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: statusView)
        popover.contentViewController = hostingController

        // Show popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func toggleProxy() {
        guard let viewModel = viewModel else { return }

        Task { @MainActor in
            let wasEnabled = viewModel.isProxyEnabled
            await viewModel.toggleProxy()

            // Update icon
            updateStatusIcon(isEnabled: viewModel.isProxyEnabled)

            // Send notifications
            if viewModel.isProxyEnabled && !wasEnabled {
                if let config = viewModel.currentConfiguration {
                    NotificationManager.shared.notifyProxyEnabled(configuration: config)
                }
            } else if !viewModel.isProxyEnabled && wasEnabled {
                NotificationManager.shared.notifyProxyDisabled()
            }

            // Handle errors
            if let error = viewModel.errorMessage {
                let appError = AppError.proxyConnectionFailed(error)
                NotificationManager.shared.notifyProxyError(appError)
            }
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Memory Pressure Handling

    private func setupMemoryPressureMonitoring() {
        memoryHandler.addCleanupHandler { [weak self] level in
            guard let self = self else { return }

            switch level {
            case .warning:
                os_log(.default, "⚠️ Memory pressure warning - performing cleanup")
                Task { @MainActor in
                    await self.handleMemoryWarning()
                }

            case .critical:
                os_log(.fault, "🔴 Critical memory pressure - aggressive cleanup")
                Task { @MainActor in
                    await self.handleCriticalMemory()
                }

            case .normal:
                os_log(.debug, "✅ Memory pressure returned to normal")
            }
        }

        memoryHandler.startMonitoring()
        os_log(.info, "Memory pressure monitoring started")
    }

    @MainActor
    private func handleMemoryWarning() async {
        os_log(.info, "Handling memory warning - clearing caches")

        // Clean up caches via ViewModel
        viewModel?.cleanupCaches()
    }

    @MainActor
    private func handleCriticalMemory() async {
        os_log(.info, "Handling critical memory - aggressive cleanup")

        // Aggressive cleanup via ViewModel
        await viewModel?.closeIdleConnections()
    }

    func applicationWillTerminate(_ notification: Notification) {
        memoryHandler.stopMonitoring()
        os_log(.info, "Memory pressure monitoring stopped")
    }
}

// Note: Logger configuration is now handled in Shared/Core/Utils/Logger.swift
// No need for duplicate extension here
