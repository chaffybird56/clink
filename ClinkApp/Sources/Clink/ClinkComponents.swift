import SwiftUI
import ClinkCore

// MARK: - Waveform metaphor

struct WaveformPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme
    var accent: Color = .accentColor
    var isActive: Bool = false

    private let barHeights: [CGFloat] = [0.35, 0.55, 0.85, 0.65, 0.45, 0.75, 0.5, 0.9, 0.6, 0.4, 0.7, 0.55]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(colorScheme == .dark ? 0.55 : 0.4))
                    .frame(width: 4, height: 28 * height)
                    .animation(
                        isActive
                            ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(index) * 0.04)
                            : .default,
                        value: isActive
                    )
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

// MARK: - Distance meter

struct DistanceMeterView: View {
    let distance: Float
    let threshold: Float

    private var watchLimit: Float { threshold * 1.2 }
    private var progress: Double {
        let cap = max(watchLimit, 0.001)
        return min(Double(distance / cap), 1.0)
    }

    private var zoneLabel: String {
        if distance <= threshold { return "Within healthy range" }
        if distance <= watchLimit { return "Watch band — near threshold" }
        return "Beyond watch band"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Spectral distance", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.3f", distance))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(meterGradient)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Spectral distance \(String(format: "%.3f", distance)), threshold \(String(format: "%.3f", threshold))")
            .accessibilityValue(zoneLabel)

            HStack {
                Text(String(format: "Threshold %.3f", threshold))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(zoneLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var meterGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.72, blue: 0.45),
                Color(red: 0.95, green: 0.58, blue: 0.2),
                Color(red: 0.92, green: 0.32, blue: 0.34),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - ML probability

struct MLProbabilityRow: View {
    let probability: Float

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text("Core ML healthy probability")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(probability), total: 1.0)
                    .progressViewStyle(.linear)
            }
            Text(String(format: "%.0f%%", probability * 100))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Core ML healthy probability \(Int(probability * 100)) percent")
    }
}

// MARK: - Result card

struct HealthResultCard: View {
    let result: HealthResult
    let fileName: String
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: StatusAppearance {
        StatusAppearance.forStatus(result.status, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: appearance.symbol)
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(appearance.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appearance.label)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(appearance.accent)
                    if !fileName.isEmpty {
                        Label(fileName, systemImage: "doc.waveform")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                WaveformPlaceholder(accent: appearance.accent, isActive: true)
            }

            Divider().opacity(0.5)

            DistanceMeterView(distance: result.distance, threshold: result.distanceThreshold)

            MLProbabilityRow(probability: result.healthyProbability)
        }
        .padding(20)
        .background(appearance.softBackground)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ClinkLayout.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ClinkLayout.cardCorner, style: .continuous)
                .strokeBorder(appearance.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Health result \(appearance.label)")
    }
}

// MARK: - Empty & error

struct EmptyResultPlaceholder: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("No analysis yet")
                .font(.headline)
            Text("Run a healthy or fault sample, or import a short WAV clip (~2 seconds).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No analysis yet. Run a test or import audio.")
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(red: 0.92, green: 0.32, blue: 0.34))
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(red: 0.92, green: 0.32, blue: 0.34).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Sidebar row

struct ProfileSidebarRow: View {
    let profile: ProfilePack
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                    .frame(width: 36, height: 36)
                Image(systemName: ProfileSymbol.systemName(for: profile.id))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(profile.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                AudiencePill(text: profile.audience)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.title), \(profile.audience)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
