import SwiftUI
import OSLog
import SwiftProxyCore

/// Main application entry point for SwiftProxy
@main
struct SwiftProxyApp: App {
    // MARK: - Properties

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel: MainViewModel

    // MARK: - Initialization

    init() {
        // Initialize logger
        Logger.configure()

        // Create proxy service
        let proxyService = ProxyService(logger: Logger.proxyLog)

        // Create view model
        let vm = MainViewModel(proxyService: proxyService)
        _viewModel = StateObject(wrappedValue: vm)

        // Pass viewModel reference to AppDelegate for memory pressure handling
        DispatchQueue.main.async {
            appDelegate.viewModel = vm
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            proxyCommands
            viewCommands
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView(viewModel: viewModel)
                .frame(minWidth: 700, minHeight: 500)
        }
    }

    // MARK: - Commands

    private var proxyCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About SwiftProxy") {
                showAbout()
            }
        }

        CommandGroup(after: .newItem) {
            Button("New Proxy Configuration...") {
                // TODO: Show new configuration window
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button(viewModel.isProxyEnabled ? "Disable Proxy" : "Enable Proxy") {
                Task {
                    await viewModel.toggleProxy()
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(viewModel.currentConfiguration == nil && !viewModel.isProxyEnabled)
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
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var viewModel: MainViewModel?  // Injected from App
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
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "SwiftProxy")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create menu
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Enable Proxy", action: #selector(toggleProxy), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open SwiftProxy", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func togglePopover() {
        // TODO: Show quick status popover
    }

    @objc private func toggleProxy() {
        // TODO: Toggle proxy state
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

// MARK: - Logger Configuration

extension Logger {
    static let proxy = OSLog(subsystem: "com.swiftproxy.app", category: "proxy")
    static let network = OSLog(subsystem: "com.swiftproxy.app", category: "network")
    static let ui = OSLog(subsystem: "com.swiftproxy.app", category: "ui")

    static func configure() {
        os_log(.info, log: proxy, "SwiftProxy starting...")
    }
}
