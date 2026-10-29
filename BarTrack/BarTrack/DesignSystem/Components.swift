import SwiftUI

// MARK: - Background

struct AppBackground: View {
    @AppStorage(AppStorageKey.backgroundStyle) private var styleRaw = BackgroundStyle.navy.rawValue

    var body: some View {
        let style = BackgroundStyle(rawValue: styleRaw) ?? .navy
        ZStack {
            style.baseColor
            RadialGradient(
                colors: [Theme.accent.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func appBackground() -> some View {
        background(AppBackground())
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var highlight: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(highlight.map { $0.opacity(0.45) } ?? Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - Labels

struct SectionLabel: View {
    let text: String
    var color: Color = Theme.textSecondary

    init(_ text: String, color: Color = Theme.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var unit: String? = nil
    var caption: String? = nil
    var valueColor: Color = Theme.textPrimary
    var icon: String? = nil

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    SectionLabel(title)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.metric(30, weight: .heavy))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Badges & pills

struct SpeedBadge: View {
    let speedClass: SpeedClass
    var large = false

    var body: some View {
        Text(speedClass.label)
            .font(large ? .subheadline.weight(.heavy) : .caption2.weight(.heavy))
            .tracking(1)
            .foregroundStyle(speedClass.color)
            .padding(.horizontal, large ? 12 : 8)
            .padding(.vertical, large ? 6 : 4)
            .background(Capsule().fill(speedClass.color.opacity(0.16)))
            .overlay(Capsule().strokeBorder(speedClass.color.opacity(0.35), lineWidth: 1))
    }
}

struct StatusPill: View {
    let state: MotionConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.color)
                .frame(width: 7, height: 7)
                .shadow(color: state.color.opacity(0.8), radius: 4)
            Text(state.shortTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.surfaceRaised))
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }
}

extension MotionConnectionState {
    var color: Color {
        switch self {
        case .simulated: Theme.accent
        case .notConnected: Theme.textTertiary
        case .connectedNoMotion: Theme.warning
        case .streaming: Theme.fast
        }
    }

    var symbol: String {
        switch self {
        case .simulated: "wand.and.stars"
        case .notConnected: "airpodspro"
        case .connectedNoMotion: "airpodspro"
        case .streaming: "waveform.path.ecg"
        }
    }
}

struct ExperimentalNotice: View {
    var text = "Speed scores are relative (0–100) and experimental. They are not validated m/s velocity measurements."

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flask.fill")
                .font(.footnote)
                .foregroundStyle(Theme.warning)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .fill(Theme.warning.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .strokeBorder(Theme.warning.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Speed zone

extension SpeedZone.Status {
    var color: Color {
        switch self {
        case .below: Theme.slow
        case .inZone: Theme.accent
        case .above: Theme.medium
        }
    }

    var symbol: String {
        switch self {
        case .below: "arrow.down"
        case .inZone: "checkmark"
        case .above: "arrow.up"
        }
    }
}

/// "IN ZONE" / "TOO SLOW" / "TOO FAST" chip.
struct ZoneStatusBadge: View {
    let status: SpeedZone.Status

    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.caption.weight(.heavy))
            .tracking(0.8)
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(status.color.opacity(0.15)))
            .overlay(Capsule().strokeBorder(status.color.opacity(0.35), lineWidth: 1))
    }
}

/// A 0–100 track with the target zone highlighted.
struct SpeedZoneBar: View {
    let zone: SpeedZone

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Theme.slow.opacity(0.35), Theme.medium.opacity(0.35), Theme.fast.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.accent.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, lineWidth: 2))
                        .frame(width: max(8, width * (zone.upper - zone.lower) / 100))
                        .offset(x: width * zone.lower / 100)
                }
            }
            .frame(height: 16)
            HStack {
                Text("0 · SLOW").font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("FAST · 100").font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            }
        }
        .animation(.snappy, value: zone)
        .accessibilityLabel("Target speed zone \(zone.text)")
    }
}

// MARK: - Logo

struct BarbellGlyph: View {
    var color: Color = Theme.onAccent

    var body: some View {
        HStack(spacing: 1.5) {
            plate(height: 10)
            plate(height: 16)
            Capsule().fill(color).frame(width: 12, height: 3)
            plate(height: 16)
            plate(height: 10)
        }
    }

    private func plate(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3.5, height: height)
    }
}

struct BarTrackLogo: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Theme.accent, Theme.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 38, height: 38)
                    .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 3)
                BarbellGlyph()
            }
            HStack(spacing: 0) {
                Text("BAR").foregroundStyle(Theme.textPrimary)
                Text("TRACK").foregroundStyle(Theme.accent)
            }
            .font(.system(size: 22, weight: .black, design: .rounded))
            .tracking(1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BarTrack")
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var height: CGFloat = 56
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(isEnabled ? Theme.onAccent : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(isEnabled ? tint : Theme.surfaceRaised)
            )
            .shadow(color: tint.opacity(isEnabled ? 0.35 : 0), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 56
    var foreground: Color = Theme.textPrimary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isEnabled ? foreground : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.borderStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Subtle press feedback for tappable cards.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// Round icon button used for steppers (+/−) and close buttons.
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.surfaceRaised))
                .overlay(Circle().strokeBorder(Theme.borderStrong, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
