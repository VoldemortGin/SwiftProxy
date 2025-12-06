import SwiftUI

// MARK: - Animation Presets

public extension Animation {
    /// Quick spring animation for UI feedback
    static var quickSpring: Animation {
        .spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0)
    }

    /// Smooth spring animation
    static var smoothSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)
    }

    /// Bouncy spring animation
    static var bouncySpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
    }

    /// Gentle spring animation
    static var gentleSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)
    }
}

// MARK: - Transition Presets

public extension AnyTransition {
    /// Slide and fade transition
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }

    /// Push transition from bottom
    static var pushFromBottom: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Blur and fade transition
    static var blurAndFade: AnyTransition {
        .opacity.combined(with: .scale(scale: 1.05))
    }
}

// MARK: - View Modifiers for Animations

public struct AnimatedAppearModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.smoothSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

public struct PulseAnimationModifier: ViewModifier {
    @State private var isPulsing = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

public struct ShakeAnimationModifier: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _ in
                shake()
            }
    }

    private func shake() {
        let animation = Animation.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0)
        withAnimation(animation) {
            offset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(animation) {
                offset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(animation) {
                offset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                offset = 0
            }
        }
    }
}

public struct ButtonPressAnimationModifier: ViewModifier {
    @State private var isPressed = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.quickSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

public struct RotatingAnimationModifier: ViewModifier {
    @State private var isRotating = false

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    isRotating = true
                }
            }
    }
}

public struct ShimmerAnimationModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

// MARK: - View Extensions

public extension View {
    /// Add animated appearance effect
    func animatedAppear(delay: Double = 0) -> some View {
        modifier(AnimatedAppearModifier(delay: delay))
    }

    /// Add pulse animation
    func pulseAnimation() -> some View {
        modifier(PulseAnimationModifier())
    }

    /// Add shake animation
    func shakeAnimation(trigger: Bool) -> some View {
        modifier(ShakeAnimationModifier(trigger: trigger))
    }

    /// Add button press animation
    func buttonPressAnimation() -> some View {
        modifier(ButtonPressAnimationModifier())
    }

    /// Add rotating animation
    func rotatingAnimation() -> some View {
        modifier(RotatingAnimationModifier())
    }

    /// Add shimmer loading animation
    func shimmerAnimation() -> some View {
        modifier(ShimmerAnimationModifier())
    }

    /// Add conditional animation
    func conditionalAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        if let animation = animation {
            return AnyView(self.animation(animation, value: value))
        } else {
            return AnyView(self)
        }
    }

    /// Add smooth transition
    func smoothTransition(_ transition: AnyTransition = .slideAndFade) -> some View {
        self.transition(transition)
    }
}

// MARK: - Loading Indicators

public struct SkeletonView: View {
    @State private var isAnimating = false

    public var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.5),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(45))
                .offset(x: isAnimating ? 300 : -300)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

public struct PulsingDot: View {
    @State private var isPulsing = false

    public var body: some View {
        Circle()
            .fill(AppTheme.Colors.primary)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.2 : 0.8)
            .opacity(isPulsing ? 1.0 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

public struct LoadingDots: View {
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                PulsingDot()
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: true
                    )
            }
        }
    }
}

// MARK: - Animated Number

public struct AnimatedNumber: View {
    let value: Int
    @State private var displayValue: Int = 0

    public init(value: Int) {
        self.value = value
    }

    public var body: some View {
        Text("\(displayValue)")
            .contentTransition(.numericText())
            .onChange(of: value) { newValue in
                withAnimation(.smoothSpring) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Animated Progress Bar

public struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    @State private var displayProgress: Double = 0

    public init(progress: Double, color: Color = AppTheme.Colors.primary) {
        self.progress = progress
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * displayProgress)
            }
        }
        .cornerRadius(4)
        .frame(height: 8)
        .onChange(of: progress) { newValue in
            withAnimation(.smoothSpring) {
                displayProgress = min(max(newValue, 0), 1)
            }
        }
        .onAppear {
            displayProgress = progress
        }
    }
}
