# Main UI Features - Quick Reference Guide

## Overview

This guide provides a quick reference for the Sprint 2 Task #5 implementation: Main Application UI Features.

---

## File Locations

### Core Files

| File | Purpose | Lines |
|------|---------|-------|
| `Platform/macOS/SwiftProxyApp.swift` | Main app & AppDelegate with menu bar | ~350 |
| `Platform/macOS/UI/Views/QuickStatusPopover.swift` | Status popover view | ~263 |
| `Platform/macOS/Services/NotificationManager.swift` | Notification service | ~240 |
| `Platform/macOS/UI/Views/ProxyConfigView.swift` | Config editor (existing) | ~187 |

---

## Key Components

### 1. SwiftProxyApp

**Purpose**: Main application entry point with menu bar integration

**Key Properties**:
```swift
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
@StateObject private var viewModel: MainViewModel
@State private var showingConfigEditor = false
```

**Keyboard Shortcuts**:
- `Cmd+N` - New configuration
- `Cmd+T` - Toggle proxy
- `Cmd+R` - Refresh
- `Cmd+Shift+K` - Clear requests
- `Cmd+Option+K` - Clear notifications
- `Cmd+Shift+S` - Show quick status

### 2. AppDelegate

**Purpose**: Menu bar icon and popover management

**Key Methods**:
```swift
setupMenuBar()                    // Initialize menu bar icon
updateStatusIcon(isEnabled:)      // Update icon state
statusBarButtonClicked(_:)        // Handle clicks
showContextMenu()                 // Right-click menu
togglePopover()                   // Left-click popover
showQuickStatus()                 // Display popover
toggleProxy()                     // Proxy state toggle
```

**Menu Bar Icon States**:
- Inactive: `network` (gray)
- Active: `network.badge.shield.half.filled` (green)

### 3. QuickStatusPopover

**Purpose**: Display proxy status and statistics

**Key Sections**:
- Header: Status indicator, app name, state
- Configuration: Current config details
- Statistics: Requests, downloaded, uploaded, avg speed
- Actions: Toggle, open, settings buttons

**Statistics Display**:
```swift
private func statisticItem(icon:label:value:color:) -> some View
private func formatBytes(_ bytes: Int64) -> String
private func formatSpeed(_ bytesPerRequest: Double) -> String
```

### 4. NotificationManager

**Purpose**: Handle all user notifications

**Singleton Access**:
```swift
NotificationManager.shared
```

**Key Methods**:
```swift
requestAuthorization() async                        // Request permissions
notifyProxyEnabled(configuration:)                  // Proxy enabled
notifyProxyDisabled()                              // Proxy disabled
notifyProxyError(_:)                               // Error occurred
notifyConfigurationSaved(name:)                    // Config saved
notifyConnectionTestResult(success:configuration:) // Test result
clearAllNotifications()                            // Clear all
```

**Notification Categories**:
- `PROXY_STATUS` - State changes
- `PROXY_ERROR` - Errors
- `CONNECTION_TEST` - Test results
- `CONFIG_UPDATE` - Config changes
- `SYSTEM_ALERT` - System warnings

---

## Integration Points

### Showing Configuration Editor

```swift
// From SwiftProxyApp
showingConfigEditor = true

// Sheet automatically shows ConfigurationEditorView
```

### Toggling Proxy

```swift
// From ViewModel
await viewModel.toggleProxy()

// With notification
let wasEnabled = viewModel.isProxyEnabled
await viewModel.toggleProxy()

if viewModel.isProxyEnabled && !wasEnabled {
    if let config = viewModel.currentConfiguration {
        NotificationManager.shared.notifyProxyEnabled(configuration: config)
    }
}
```

### Updating Menu Bar Icon

```swift
// Automatic via AppDelegate
Task { @MainActor in
    updateStatusIcon(isEnabled: viewModel.isProxyEnabled)
}
```

### Sending Notifications

```swift
// Success notification
NotificationManager.shared.notifyProxyEnabled(configuration: config)

// Error notification
let error = AppError.proxyConnectionFailed("message")
NotificationManager.shared.notifyProxyError(error)

// Silent notification
NotificationManager.shared.notifyConfigurationSaved(name: "My Proxy")
```

---

## Common Tasks

### Adding a New Keyboard Shortcut

1. Add to appropriate command group in `SwiftProxyApp.swift`:
```swift
private var proxyCommands: some Commands {
    Group {
        CommandGroup(after: .newItem) {
            Button("My Action") {
                // Action code
            }
            .keyboardShortcut("a", modifiers: .command)
        }
    }
}
```

### Adding a New Notification Type

1. Add method to `NotificationManager`:
```swift
func notifyMyEvent(details: String) {
    guard isAuthorized else { return }

    let content = UNMutableNotificationContent()
    content.title = "Event Title"
    content.body = details
    content.sound = .default
    content.categoryIdentifier = "MY_CATEGORY"

    sendNotification(identifier: "my.event.\(UUID().uuidString)", content: content)
}
```

2. Handle in delegate if needed:
```swift
case "MY_CATEGORY":
    // Handle click
    break
```

### Adding Menu Bar Menu Items

1. Update `showContextMenu()` in AppDelegate:
```swift
let myItem = NSMenuItem(title: "My Action", action: #selector(myAction), keyEquivalent: "")
myItem.target = self
menu.addItem(myItem)
```

2. Add action handler:
```swift
@objc private func myAction() {
    // Action code
}
```

### Customizing Quick Status Popover

1. Add new section to `QuickStatusPopover`:
```swift
private var mySection: some View {
    VStack(spacing: 8) {
        // Section content
    }
    .padding(16)
}
```

2. Add to body:
```swift
var body: some View {
    VStack(spacing: 0) {
        headerSection
        Divider()
        mySection  // New section
        Divider()
        actionsSection
    }
}
```

---

## Debugging Tips

### Enable Logging

```swift
import OSLog

let logger = OSLog(subsystem: "com.swiftproxy.app", category: "ui")
os_log(.debug, log: logger, "My debug message: %@", value)
```

### Test Notifications Without Authorization

```swift
// Temporarily bypass authorization check
// In NotificationManager:
guard isAuthorized else {
    print("Would send notification: \(title)")
    return
}
```

### Verify Menu Bar State

```swift
// In AppDelegate
print("Status item: \(statusItem?.button?.image?.name() ?? "none")")
print("Popover shown: \(popover?.isShown ?? false)")
```

### Check Keyboard Shortcuts

```swift
// In SwiftProxyApp commands
print("Command executed: \(actionName)")
```

---

## Testing Checklist

### Quick Test

```bash
# Build
swift build

# Run (if executable)
.build/debug/SwiftProxy
```

### Manual Tests

- [ ] Menu bar icon appears
- [ ] Left-click shows popover
- [ ] Right-click shows menu
- [ ] Keyboard shortcuts work
- [ ] Notifications appear
- [ ] Configuration editor opens
- [ ] Proxy toggles correctly
- [ ] Icon updates on state change

---

## Performance Notes

### Optimization Tips

1. **Lazy Loading**: Create popover only when needed
2. **State Updates**: Use Combine publishers efficiently
3. **Memory**: Keep notification history bounded
4. **UI Updates**: Always on MainActor

### Memory Management

```swift
// Use weak self in closures
Task { [weak self] in
    await self?.method()
}

// Cancel publishers
cancellables.removeAll()
```

---

## Swift 6 Concurrency

### Actor Isolation

```swift
// MainActor for UI
@MainActor
final class ViewModel: ObservableObject { }

// Nonisolated for delegates
nonisolated func delegateMethod() { }

// Cross-actor calls
Task { @MainActor in
    // UI code
}
```

### Common Patterns

```swift
// Safe async call
Task { @MainActor in
    await asyncOperation()
    updateUI()
}

// Background work
Task {
    let result = await backgroundWork()
    await MainActor.run {
        updateUI(result)
    }
}
```

---

## Troubleshooting

### Issue: Menu bar icon not showing

**Check**:
1. `statusItem` is not nil
2. `button` has an image
3. App is running in foreground

### Issue: Popover not appearing

**Check**:
1. `popover` is created
2. `viewModel` is set
3. `statusItem.button` exists

### Issue: Notifications not showing

**Check**:
1. Authorization granted
2. `isAuthorized` is true
3. Notification Center enabled in System Preferences

### Issue: Keyboard shortcuts not working

**Check**:
1. No conflicting shortcuts
2. Command groups added to scene
3. Button actions are correct

---

## Code Style

### Naming Conventions

```swift
// Properties
private var statusItem: NSStatusItem?
private let logger = OSLog(...)

// Methods
private func setupMenuBar() { }
@objc private func toggleProxy() { }

// Computed Properties
private var mySection: some View { }
```

### Documentation

```swift
/// Brief description
///
/// Detailed explanation if needed
///
/// - Parameter name: Description
/// - Returns: Description
func method(name: String) -> Bool {
}
```

---

## References

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- [AppKit Menu Bar](https://developer.apple.com/documentation/appkit/nsstatusbar)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

**Last Updated**: 2025-01-26
**SwiftProxy Version**: 1.0.0
