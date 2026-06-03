import SwiftUI
import ClinkCore

// MARK: - Layout & typography

enum ClinkLayout {
    static let sidebarWidth: CGFloat = 260
    static let detailPadding: CGFloat = 28
    static let cardCorner: CGFloat = 14
    static let sectionSpacing: CGFloat = 24
}

// MARK: - Profile presentation

enum ProfileSymbol {
    static func systemName(for profileId: String) -> String {
        switch profileId {
        case "microwave_hum": return "microwave"
        case "relay_click": return "bolt.circle"
        case "vacuum_cleaner": return "fanblades"
        case "garage_door": return "door.left.hand.closed"
        case "smoke_alarm_chirp": return "bell.and.waves.left.and.right"
        default: return "waveform"
        }
    }
}

struct AudiencePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
            .clipShape(Capsule())
            .accessibilityLabel("Audience: \(text)")
    }
}

// MARK: - Health status styling

struct StatusAppearance {
    let label: String
    let symbol: String
    let accent: Color
    let softBackground: Color

    static func forStatus(_ status: HealthResult.Status, colorScheme: ColorScheme) -> StatusAppearance {
        let dim: Double = colorScheme == .dark ? 0.22 : 0.12
        switch status {
        case .healthy:
            return StatusAppearance(
                label: status.rawValue,
                symbol: "checkmark.circle.fill",
                accent: Color(red: 0.2, green: 0.72, blue: 0.45),
                softBackground: Color(red: 0.2, green: 0.72, blue: 0.45).opacity(dim)
            )
        case .watch:
            return StatusAppearance(
                label: status.rawValue,
                symbol: "exclamationmark.triangle.fill",
                accent: Color(red: 0.95, green: 0.58, blue: 0.2),
                softBackground: Color(red: 0.95, green: 0.58, blue: 0.2).opacity(dim)
            )
        case .fault:
            return StatusAppearance(
                label: status.rawValue,
                symbol: "xmark.octagon.fill",
                accent: Color(red: 0.92, green: 0.32, blue: 0.34),
                softBackground: Color(red: 0.92, green: 0.32, blue: 0.34).opacity(dim)
            )
        }
    }
}
