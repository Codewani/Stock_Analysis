import Charts
import SwiftUI
#if os(iOS)
import UIKit
#endif

private func hideKeyboard() {
#if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
}

// MARK: - Screen chrome

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.appBackground.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }

    func toastOverlay(toast: AppToast?) -> some View {
        modifier(ToastOverlayModifier(toast: toast))
    }

    @ViewBuilder
    func compatibleHiddenScrollBackground() -> some View {
#if os(iOS)
        scrollContentBackground(.hidden)
#else
        self
#endif
    }

    @ViewBuilder
    func compatibleRefreshable(action: @escaping @Sendable () async -> Void) -> some View {
#if os(iOS)
        refreshable {
            await action()
        }
#else
        self
#endif
    }

    @ViewBuilder
    func compatibleInlineNavigationTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func compatibleTextInputAutocapitalizationNever() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#else
        self
#endif
    }

    @ViewBuilder
    func compatibleTextInputAutocapitalizationCharacters() -> some View {
#if os(iOS)
        textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
#else
        self
#endif
    }
}

extension ToolbarItemPlacement {
    /// A trailing toolbar placement that's valid on every platform this app
    /// targets — `.topBarTrailing` doesn't exist outside iOS/iPadOS.
    static var compatibleTrailing: ToolbarItemPlacement {
#if os(iOS)
        .topBarTrailing
#else
        .primaryAction
#endif
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )
            .softShadow()
    }
}

/// A subtler press animation for tappable cards, replacing the default `.plain`
/// button style so navigation rows feel responsive instead of static.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Color.brandPrimary.opacity(isDisabled ? 0.5 : 1),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.negative)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.negative.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.textPrimary)
            .frame(width: 38, height: 38)
            .background(Color.appSurfaceSecondary, in: Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var appPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func appPrimary(isDisabled: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(isDisabled: isDisabled) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var appSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var appDestructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var appIcon: IconButtonStyle { IconButtonStyle() }
}

// MARK: - Text field

struct AppTextField: View {
    let title: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var autocapitalizationDisabled: Bool = false
    var autocapitalizeCharacters: Bool = false
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    var onFocusChange: ((Bool) -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 18)
            }

            Group {
                if isSecure && !isRevealed {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .font(.bodyText)
            .foregroundStyle(Color.textPrimary)
            .focused($isFocused)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .applyAutocapitalization(disabled: autocapitalizationDisabled, characters: autocapitalizeCharacters)

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 50)
        .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(isFocused ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .onChange(of: isFocused) { _, newValue in
            onFocusChange?(newValue)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyAutocapitalization(disabled: Bool, characters: Bool) -> some View {
        if characters {
            compatibleTextInputAutocapitalizationCharacters()
        } else if disabled {
            compatibleTextInputAutocapitalizationNever()
        } else {
            self
        }
    }
}

// MARK: - Stat tile / trend pill

struct StatTile: View {
    let title: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.microText)
                .foregroundStyle(Color.textTertiary)
                .kerning(0.4)
            Text(value)
                .font(.statValue)
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.appSurfaceSecondary))
    }
}

struct TrendPill: View {
    let value: Double
    let percentage: Double

    private var color: Color { Color.trend(value) }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
            Text(value.currencyString)
            Text("(\(percentage.percentString))")
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(color.opacity(0.14), in: Capsule())
    }
}

struct Badge: View {
    let text: String
    var tint: Color = .textSecondary

    var body: some View {
        Text(text)
            .font(.microText)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Symbol avatar

struct SymbolAvatar: View {
    let symbol: String
    var size: CGFloat = 44

    private var initials: String {
        String(symbol.prefix(2)).uppercased()
    }

    var body: some View {
        let tint = Color.monogram(for: symbol)
        Circle()
            .fill(tint.opacity(0.16))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Sparkline

/// Deterministic pseudo-series seeded by a string so the same symbol always
/// produces the same shape across renders (no flicker on view updates) while
/// still varying between symbols.
func deterministicSeries(seed: String, count: Int, base: Double, volatility: Double = 0.028) -> [Double] {
    var state = seed.unicodeScalars.reduce(UInt64(1)) { $0 &* 31 &+ UInt64($1.value) }
    func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / Double(UInt64.max >> 33)
    }
    var value = base
    var result: [Double] = []
    for _ in 0..<count {
        let delta = (next() - 0.47) * (base * volatility)
        value = max(value + delta, base * 0.35)
        result.append(value)
    }
    return result
}

struct Sparkline: View {
    let values: [Double]
    var color: Color = .brandPrimary
    var lineWidth: CGFloat = 2

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("Index", index), y: .value("Value", value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
    }
}

// MARK: - Interactive (scrubbable) chart

/// An area/line chart you can press and drag across to inspect the value at
/// a point in time: touching the chart snaps a marker to the nearest data
/// point and reports it via `selection`; lifting the finger clears the
/// selection so the caller can fall back to showing the latest value.
struct InteractiveAreaChart: View {
    let points: [PricePoint]
    let color: Color
    @Binding var selection: PricePoint?

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }

            if let selection {
                RuleMark(x: .value("Date", selection.date))
                    .foregroundStyle(Color.textTertiary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                PointMark(x: .value("Date", selection.date), y: .value("Value", selection.value))
                    .foregroundStyle(color)
                    .symbolSize(90)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                updateSelection(at: drag.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selection = nil
                                }
                            }
                    )
            }
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard !points.isEmpty else { return }
        let plotFrame = geometry[proxy.plotAreaFrame]
        let xPosition = location.x - plotFrame.origin.x
        guard let date = proxy.value(atX: xPosition, as: Date.self) else { return }

        let nearest = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        if nearest?.id != selection?.id {
            Haptic.selection()
        }
        selection = nearest
    }
}

// MARK: - Chart range selector

enum ChartRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonth = "3M"
    case oneYear = "1Y"
    case all = "ALL"

    var id: String { rawValue }

    var pointCount: Int {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonth: return 90
        case .oneYear: return 180
        case .all: return 260
        }
    }
}

struct RangeSelector: View {
    @Binding var selection: ChartRange

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChartRange.allCases) { range in
                Button {
                    Haptic.selection()
                    withAnimation(.easeOut(duration: 0.18)) { selection = range }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == range ? Color.white : Color.textSecondary)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == range ? Color.brandPrimary : Color.clear,
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.sm + 3, style: .continuous))
    }
}

// MARK: - State views

struct LoadingStateView: View {
    let title: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.brandPrimary)
            Text(title)
                .font(.bodyText)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(Color.appSurfaceSecondary).frame(width: 64, height: 64)
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            Text(title)
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.captionText)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(Color.negative.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.negative)
            }
            Text(title)
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.captionText)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again", action: retry)
                .buttonStyle(.appSecondary)
                .frame(maxWidth: 160)
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toast

struct ToastOverlayModifier: ViewModifier {
    let toast: AppToast?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let toast {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    ZStack {
                        Circle().fill(iconColor.opacity(0.14)).frame(width: 30, height: 30)
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(iconColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(toast.message)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.sm)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                )
                .softShadow(opacity: 0.12)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast)
    }

    private var iconName: String {
        switch toast?.style {
        case .success: return "checkmark"
        case .error: return "xmark"
        case .neutral, .none: return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch toast?.style {
        case .success: return .positive
        case .error: return .negative
        case .neutral, .none: return .brandPrimary
        }
    }
}

// MARK: - Formatting helpers

extension Double {
    var currencyString: String {
        formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var compactCurrencyString: String {
        formatted(.currency(code: Locale.current.currency?.identifier ?? "USD").notation(.compactName))
    }

    var percentString: String {
        formatted(.percent.precision(.fractionLength(2)))
    }
}

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

extension Sentiment {
    var tint: Color {
        switch self {
        case .positive: return .positive
        case .neutral: return .warning
        case .negative: return .negative
        }
    }

    var label: String {
        switch self {
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .negative: return "Negative"
        }
    }
}

extension APIDataSource {
    var tint: Color {
        switch self {
        case .live: return .positive
        case .cache: return .warning
        case .mock: return .textTertiary
        }
    }
}
