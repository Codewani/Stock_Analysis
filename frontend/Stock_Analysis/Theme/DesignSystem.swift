import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Color tokens
//
// The named colors themselves (appBackground, appSurface, textPrimary,
// brandPrimary, positive, negative, warning, ...) are backed by adaptive
// color set assets in Assets.xcassets and exposed on `Color` automatically
// by Xcode's asset symbol generation, so the app supports both light and
// dark appearance without any manual bridging code here.

extension Color {
    /// Semantic color for a signed value, e.g. day change or P&L.
    static func trend(_ value: Double) -> Color {
        value >= 0 ? .positive : .negative
    }

    /// A small, fixed palette used to give each ticker symbol a stable, distinct
    /// identity color for monogram avatars — deterministic so the same symbol
    /// always renders the same color across the app.
    private static let monogramPalette: [Color] = [
        .blue, .purple, .teal, .orange, .pink, .indigo, .mint, .brown, .cyan
    ]

    static func monogram(for seed: String) -> Color {
        let hash = seed.uppercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return monogramPalette[hash % monogramPalette.count]
    }
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

// MARK: - Radius

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

// MARK: - Typography
//
// Numeric values use the rounded design for a friendlier, more distinctive
// feel than the plain system font, and consistently use monospaced digits so
// price/percentage columns don't jitter as they update.

extension Font {
    static func numeric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let heroValue = Font.numeric(44)
    static let statValue = Font.numeric(19)

    static let screenTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let sectionTitle = Font.system(size: 19, weight: .semibold)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let bodyText = Font.system(size: 15, weight: .regular)
    static let captionText = Font.system(size: 12, weight: .medium)
    static let microText = Font.system(size: 11, weight: .semibold)
}

extension Text {
    /// Applies tabular (monospaced) digits so numbers in lists and tickers align.
    func tabularNumbers() -> Text {
        self.monospacedDigit()
    }
}

// MARK: - Elevation

struct SoftShadow: ViewModifier {
    var opacity: Double = 0.05

    func body(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(opacity), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(opacity * 1.2), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func softShadow(opacity: Double = 0.05) -> some View {
        modifier(SoftShadow(opacity: opacity))
    }
}

// MARK: - Haptics

enum Haptic {
    static func light() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
