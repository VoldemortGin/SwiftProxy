import SwiftUI
import SwiftProxyCore

/// Onboarding wizard for first-time users
/// Guides users through initial setup and introduces key features
struct OnboardingView: View {
    // MARK: - Properties

    @State private var currentPage = 0
    @State private var showingConfigEditor = false
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        .welcome,
        .features,
        .setup,
        .permissions,
        .complete
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator

            // Content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(for: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .animation(.smoothSpring, value: currentPage)

            // Navigation buttons
            navigationButtons
        }
        .frame(width: 600, height: 500)
        .background(AppTheme.Colors.background)
        .sheet(isPresented: $showingConfigEditor) {
            ConfigurationEditorPlaceholder(onDismiss: {
                showingConfigEditor = false
            })
        }
    }

    // MARK: - Subviews

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? AppTheme.Colors.primary : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.smoothSpring, value: currentPage)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .accessible(
            label: "Progress: page \(currentPage + 1) of \(pages.count)",
            traits: .updatesFrequently
        )
    }

    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.primary)
                .accessibleImage(description: page.iconDescription)
                .animatedAppear(delay: 0.1)

            // Title
            Text(page.title)
                .font(AppTheme.Typography.largeTitle)
                .multilineTextAlignment(.center)
                .accessibleHeading(label: page.title)
                .animatedAppear(delay: 0.2)

            // Message
            Text(page.message)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)
                .animatedAppear(delay: 0.3)

            // Additional content
            if page == .setup {
                setupContent
                    .animatedAppear(delay: 0.4)
            } else if page == .permissions {
                permissionsContent
                    .animatedAppear(delay: 0.4)
            } else if page == .complete {
                completeContent
                    .animatedAppear(delay: 0.4)
            }

            Spacer()
        }
        .padding(40)
    }

    private var setupContent: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingConfigEditor = true
            }) {
                Label("Create First Configuration", systemImage: "plus.circle.fill")
            }
            .primaryButtonStyle()
            .accessibleButton(label: "Create first proxy configuration")

            Text("You can also skip this step and configure later")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
    }

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionRow(
                icon: "bell.fill",
                title: "Notifications",
                description: "Stay informed about proxy status changes",
                isGranted: true
            )

            PermissionRow(
                icon: "network",
                title: "Network Access",
                description: "Required for proxy functionality",
                isGranted: true
            )

            Divider()

            Text("SwiftProxy respects your privacy. No data is collected or shared.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
        .padding()
        .cardStyle()
    }

    private var completeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.success)
                .pulseAnimation()

            Text("Ready to use SwiftProxy!")
                .font(AppTheme.Typography.headline)
        }
    }

    private var navigationButtons: some View {
        HStack {
            // Back button
            if currentPage > 0 {
                Button(action: {
                    withAnimation(.smoothSpring) {
                        currentPage -= 1
                    }
                }) {
                    Label("Previous", systemImage: "chevron.left")
                }
                .accessibleButton(label: "Go to previous page")
            }

            Spacer()

            // Skip button (not on last page)
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    completeOnboarding()
                }
                .accessibleButton(label: "Skip onboarding")
            }

            // Next/Finish button
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation(.smoothSpring) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            }) {
                Label(
                    currentPage < pages.count - 1 ? "Next" : "Finish",
                    systemImage: currentPage < pages.count - 1 ? "chevron.right" : "checkmark"
                )
            }
            .primaryButtonStyle()
            .accessibleButton(
                label: currentPage < pages.count - 1 ? "Go to next page" : "Finish onboarding"
            )
        }
        .padding(24)
    }

    // MARK: - Methods

    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Announce completion for VoiceOver
        Task {
            await AccessibilityAnnouncer.shared.announce("Onboarding completed")
        }

        onComplete()
        dismiss()
    }
}

// MARK: - Onboarding Page

private enum OnboardingPage {
    case welcome
    case features
    case setup
    case permissions
    case complete

    var icon: String {
        switch self {
        case .welcome:
            return "hand.wave.fill"
        case .features:
            return "star.fill"
        case .setup:
            return "gearshape.fill"
        case .permissions:
            return "lock.shield.fill"
        case .complete:
            return "checkmark.seal.fill"
        }
    }

    var iconDescription: String {
        switch self {
        case .welcome:
            return "Welcome icon"
        case .features:
            return "Features icon"
        case .setup:
            return "Setup icon"
        case .permissions:
            return "Permissions icon"
        case .complete:
            return "Complete icon"
        }
    }

    var title: String {
        switch self {
        case .welcome:
            return L10n.onboardingWelcomeTitle
        case .features:
            return L10n.onboardingFeaturesTitle
        case .setup:
            return L10n.onboardingSetupTitle
        case .permissions:
            return L10n.onboardingPermissionsTitle
        case .complete:
            return L10n.onboardingCompleteTitle
        }
    }

    var message: String {
        switch self {
        case .welcome:
            return L10n.onboardingWelcomeMessage
        case .features:
            return L10n.onboardingFeaturesMessage
        case .setup:
            return L10n.onboardingSetupMessage
        case .permissions:
            return L10n.onboardingPermissionsMessage
        case .complete:
            return L10n.onboardingCompleteMessage
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? AppTheme.Colors.success : AppTheme.Colors.secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.Typography.headline)

                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.secondaryText)
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isGranted ? AppTheme.Colors.success : AppTheme.Colors.secondary)
        }
        .accessible(
            label: "\(title): \(isGranted ? "granted" : "not granted")",
            hint: description
        )
    }
}

// MARK: - Configuration Editor Placeholder

private struct ConfigurationEditorPlaceholder: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Configuration Editor")
                .font(.title)

            Text("This would open the configuration editor")
                .foregroundColor(.secondary)

            Button("Close") {
                onDismiss()
            }
            .primaryButtonStyle()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Onboarding Helper

public extension View {
    /// Show onboarding if not completed
    func showOnboardingIfNeeded(onComplete: @escaping () -> Void) -> some View {
        self.sheet(isPresented: .constant(!UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))) {
            OnboardingView(onComplete: onComplete)
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
}

#Preview("Dark Mode") {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
