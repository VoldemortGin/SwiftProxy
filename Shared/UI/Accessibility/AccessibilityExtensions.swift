import SwiftUI

// MARK: - Accessibility Helpers

public extension View {
    /// Add comprehensive accessibility support
    func accessible(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Mark as button with custom label
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self.accessible(label: label, hint: hint, traits: .isButton)
    }

    /// Mark as toggle with state
    func accessibleToggle(label: String, isOn: Bool) -> some View {
        if #available(macOS 14.0, *) {
            return self.accessible(
                label: label,
                value: isOn ? "On" : "Off",
                traits: .isToggle
            )
        } else {
            return self.accessible(
                label: label,
                value: isOn ? "On" : "Off",
                traits: .isButton
            )
        }
    }

    /// Mark as heading for navigation
    func accessibleHeading(label: String) -> some View {
        self.accessible(label: label, traits: .isHeader)
    }

    /// Mark as link
    func accessibleLink(label: String) -> some View {
        self.accessible(label: label, traits: .isLink)
    }

    /// Mark as image with description
    func accessibleImage(description: String) -> some View {
        self.accessible(label: description, traits: .isImage)
    }

    /// Make element invisible to VoiceOver
    func accessibilityHidden() -> some View {
        self.accessibilityHidden(true)
    }

    /// Group accessibility elements
    func accessibilityGroup() -> some View {
        self.accessibilityElement(children: .combine)
    }

    /// Separate accessibility elements
    func accessibilitySeparate() -> some View {
        self.accessibilityElement(children: .contain)
    }
}

// MARK: - Dynamic Type Support

public extension View {
    /// Apply dynamic type scaling
    func dynamicTypeSize(min: DynamicTypeSize = .xSmall, max: DynamicTypeSize = .xxxLarge) -> some View {
        self.dynamicTypeSize(min...max)
    }

    /// Scale with dynamic type
    func scaledFont(_ font: Font, maxSize: CGFloat? = nil) -> some View {
        self.font(font)
            .lineLimit(nil)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Keyboard Navigation

public extension View {
    /// Add keyboard shortcut with accessibility label
    func keyboardShortcut(
        _ key: KeyEquivalent,
        modifiers: EventModifiers = .command,
        label: String
    ) -> some View {
        self
            .keyboardShortcut(key, modifiers: modifiers)
            .accessibilityLabel(label)
    }

    /// Add focus support for keyboard navigation
    @ViewBuilder
    func focusable<Value: Hashable>(
        _ binding: FocusState<Value>.Binding,
        equals value: Value
    ) -> some View {
        self.focused(binding, equals: value)
    }
}

// MARK: - VoiceOver Announcements

public actor AccessibilityAnnouncer {
    public static let shared = AccessibilityAnnouncer()

    private init() {}

    /// Post accessibility announcement
    public func announce(_ message: String, priority: AccessibilityPriority = .default) {
        DispatchQueue.main.async {
            // Use NSAccessibility.post for announcements
            #if os(macOS)
            if let app = NSApp {
                NSAccessibility.post(
                    element: app,
                    notification: .announcementRequested
                )
            }
            #endif
        }
    }

    /// Announce with delay
    public func announce(_ message: String, after delay: TimeInterval, priority: AccessibilityPriority = .default) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await announce(message, priority: priority)
        }
    }
}

public enum AccessibilityPriority {
    case `default`
    case high
}

// MARK: - Accessibility Action

public extension View {
    /// Add custom accessibility action
    func accessibilityAction(
        named name: String,
        _ handler: @escaping () -> Void
    ) -> some View {
        self.accessibilityAction(named: Text(name), handler)
    }

    /// Add accessibility increment/decrement actions
    func accessibilityAdjustable(
        increment: @escaping () -> Void,
        decrement: @escaping () -> Void
    ) -> some View {
        self
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    increment()
                case .decrement:
                    decrement()
                @unknown default:
                    break
                }
            }
    }
}

// MARK: - High Contrast Support

public extension View {
    /// Apply high contrast adaptive colors
    @ViewBuilder
    func adaptiveColor(
        _ normal: Color,
        increased: Color? = nil
    ) -> some View {
        self.foregroundColor(normal)
    }

    /// Add border for high contrast
    func highContrastBorder(color: Color = .primary) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 1)
                .accessibilityHidden()
        )
    }
}

// MARK: - Reduced Motion Support

public extension View {
    /// Respect reduce motion setting
    func respectReducedMotion<T: Equatable>(
        animation: Animation?,
        value: T
    ) -> some View {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return AnyView(self)
        } else {
            return AnyView(self.animation(animation, value: value))
        }
    }

    /// Conditional animation based on reduce motion
    func conditionalAnimation<T: Equatable>(
        _ animation: Animation?,
        reduceMotion: Animation? = nil,
        value: T
    ) -> some View {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return AnyView(self.animation(reduceMotion ?? .default, value: value))
        } else {
            return AnyView(self.animation(animation, value: value))
        }
    }
}

// MARK: - Touch Target

public extension View {
    /// Ensure minimum touch target size (44x44)
    func minimumTouchTarget(
        width: CGFloat = 44,
        height: CGFloat = 44
    ) -> some View {
        self
            .frame(minWidth: width, minHeight: height)
            .contentShape(Rectangle())
    }

    /// Add tap gesture with accessibility
    func accessibleTapGesture(
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        self
            .onTapGesture(perform: action)
            .accessible(label: label, traits: .isButton)
            .minimumTouchTarget()
    }
}

// MARK: - Accessibility Previews

public struct AccessibilityPreviewWrapper<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text("Normal")
                .font(.headline)
            content

            Text("Large Text")
                .font(.headline)
            content
                .environment(\.sizeCategory, .accessibilityLarge)

            Text("Extra Large Text")
                .font(.headline)
            content
                .environment(\.sizeCategory, .accessibilityExtraLarge)
        }
        .padding()
    }
}

// MARK: - VoiceOver Helper Views

public struct VoiceOverAnnouncement: View {
    let message: String
    let priority: AccessibilityPriority

    public init(_ message: String, priority: AccessibilityPriority = .default) {
        self.message = message
        self.priority = priority
    }

    public var body: some View {
        EmptyView()
            .onAppear {
                Task {
                    await AccessibilityAnnouncer.shared.announce(message, priority: priority)
                }
            }
    }
}

// MARK: - Accessibility Identifiers

public extension View {
    /// Add accessibility identifier for UI testing
    func accessibilityIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }
}

// MARK: - Common Accessibility Labels

public enum A11y {
    // MARK: - Status
    public static let statusConnected = "status_connected_accessibility"
    public static let statusDisconnected = "status_disconnected_accessibility"
    public static let statusConnecting = "status_connecting_accessibility"
    public static let statusError = "status_error_accessibility"

    // MARK: - Actions
    public static let toggleProxy = "toggle_proxy_accessibility"
    public static let addConfiguration = "add_configuration_accessibility"
    public static let editConfiguration = "edit_configuration_accessibility"
    public static let deleteConfiguration = "delete_configuration_accessibility"
    public static let refreshData = "refresh_data_accessibility"

    // MARK: - Navigation
    public static let proxyTab = "proxy_tab_accessibility"
    public static let connectionsTab = "connections_tab_accessibility"
    public static let statisticsTab = "statistics_tab_accessibility"
    public static let settingsTab = "settings_tab_accessibility"

    // MARK: - Components
    public static let configurationList = "configuration_list_accessibility"
    public static let statisticsChart = "statistics_chart_accessibility"
    public static let statusIndicator = "status_indicator_accessibility"
    public static let menuBar = "menu_bar_accessibility"
}

// MARK: - Accessibility Testing Helper

#if DEBUG
public struct AccessibilityTestView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Button("Test Announcement") {
                Task {
                    await AccessibilityAnnouncer.shared.announce("This is a test announcement")
                }
            }
            .accessible(label: "Test announcement button", hint: "Posts a test VoiceOver announcement", traits: .isButton)

            Toggle("Sample Toggle", isOn: .constant(true))
                .accessibleToggle(label: "Sample toggle", isOn: true)

            Text("Sample Text")
                .accessibleHeading(label: "Sample heading")

            Button("Action Button") {}
                .minimumTouchTarget()
                .accessible(label: "Action button", hint: "Performs sample action", traits: .isButton)
        }
        .padding()
    }
}
#endif
