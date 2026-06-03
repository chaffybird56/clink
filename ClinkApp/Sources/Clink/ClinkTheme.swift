import SwiftUI
import ClinkCore

// MARK: - Layout

enum ClinkLayout {
    static let sidebarWidth: CGFloat = 272
    static let detailPadding: CGFloat = 32
    static let contentMaxWidth: CGFloat = 720
    static let cardCorner: CGFloat = 16
    static let cardCornerLarge: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let innerSpacing: CGFloat = 16
}

// MARK: - Brand palette

enum ClinkColors {
    static let healthy = Color(red: 0.18, green: 0.78, blue: 0.52)
    static let watch = Color(red: 0.98, green: 0.62, blue: 0.18)
    static let fault = Color(red: 0.96, green: 0.30, blue: 0.36)
    static let brandPrimary = Color(red: 0.22, green: 0.48, blue: 0.95)
    static let brandSecondary = Color(red: 0.35, green: 0.72, blue: 0.88)

    static func meshBlobs(for scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [
                brandPrimary.opacity(0.35),
                brandSecondary.opacity(0.22),
                healthy.opacity(0.12),
            ]
        }
        return [
            brandPrimary.opacity(0.18),
            brandSecondary.opacity(0.14),
            healthy.opacity(0.08),
        ]
    }
}

// MARK: - Profile symbols

enum ProfileSymbol {
    static func systemName(for profileId: String) -> String {
        switch profileId {
        case "microwave_hum": return "microwave"
        case "relay_click": return "bolt.circle.fill"
        case "vacuum_cleaner": return "fanblades.fill"
        case "garage_door": return "door.left.hand.closed"
        case "smoke_alarm_chirp": return "bell.and.waves.left.and.right.fill"
        default: return "waveform.circle.fill"
        }
    }

    static func tint(for profileId: String) -> Color {
        switch profileId {
        case "microwave_hum": return Color(red: 0.55, green: 0.45, blue: 0.95)
        case "relay_click": return Color(red: 0.95, green: 0.75, blue: 0.25)
        case "vacuum_cleaner": return Color(red: 0.45, green: 0.65, blue: 0.95)
        case "garage_door": return Color(red: 0.55, green: 0.55, blue: 0.62)
        case "smoke_alarm_chirp": return Color(red: 0.95, green: 0.45, blue: 0.40)
        default: return ClinkColors.brandPrimary
        }
    }
}

// MARK: - Status styling

struct StatusAppearance {
    let label: String
    let symbol: String
    let accent: Color
    let softBackground: Color
    let glow: Color

    static func forStatus(_ status: HealthResult.Status, colorScheme: ColorScheme) -> StatusAppearance {
        let dim: Double = colorScheme == .dark ? 0.28 : 0.14
        switch status {
        case .healthy:
            let c = ClinkColors.healthy
            return StatusAppearance(
                label: status.rawValue,
                symbol: "checkmark.seal.fill",
                accent: c,
                softBackground: c.opacity(dim),
                glow: c.opacity(colorScheme == .dark ? 0.45 : 0.25)
            )
        case .watch:
            let c = ClinkColors.watch
            return StatusAppearance(
                label: status.rawValue,
                symbol: "exclamationmark.triangle.fill",
                accent: c,
                softBackground: c.opacity(dim),
                glow: c.opacity(colorScheme == .dark ? 0.4 : 0.22)
            )
        case .fault:
            let c = ClinkColors.fault
            return StatusAppearance(
                label: status.rawValue,
                symbol: "xmark.octagon.fill",
                accent: c,
                softBackground: c.opacity(dim),
                glow: c.opacity(colorScheme == .dark ? 0.42 : 0.2)
            )
        }
    }
}

// MARK: - Reusable chrome

struct AudiencePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(.quaternary.opacity(0.6))
            }
            .accessibilityLabel("Audience: \(text)")
    }
}

struct ClinkBrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ClinkColors.brandPrimary, ClinkColors.brandSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "ear.and.waveform")
                .font(.system(size: size * 0.42, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .white.opacity(0.85))
        }
        .frame(width: size, height: size)
        .shadow(color: ClinkColors.brandPrimary.opacity(0.35), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

struct MeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let blobs = ClinkColors.meshBlobs(for: colorScheme)
                Circle()
                    .fill(blobs[0])
                    .frame(width: w * 0.55, height: w * 0.55)
                    .blur(radius: 80)
                    .offset(x: w * 0.55, y: -h * 0.05)
                Circle()
                    .fill(blobs[1])
                    .frame(width: w * 0.45, height: w * 0.45)
                    .blur(radius: 70)
                    .offset(x: -w * 0.1, y: h * 0.35)
                Circle()
                    .fill(blobs[2])
                    .frame(width: w * 0.35, height: w * 0.35)
                    .blur(radius: 60)
                    .offset(x: w * 0.25, y: h * 0.55)
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = ClinkLayout.cardCorner
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
    }
}
