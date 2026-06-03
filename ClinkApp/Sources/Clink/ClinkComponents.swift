import SwiftUI
import ClinkCore

// MARK: - Live waveform

struct WaveformBars: View {
    var accent: Color
    var isActive: Bool

    private let bases: [CGFloat] = [0.32, 0.5, 0.78, 0.58, 0.42, 0.72, 0.48, 0.88, 0.62, 0.38, 0.68, 0.52, 0.44, 0.76]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isActive)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(bases.enumerated()), id: \.offset) { index, base in
                    let wobble = isActive ? sin(t * 4.5 + Double(index) * 0.55) * 0.14 : 0
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 36 * max(0.15, base + CGFloat(wobble)))
                }
            }
        }
        .frame(height: 40)
        .accessibilityHidden(true)
    }
}

// MARK: - Metric tile

struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.15), lineWidth: 0.5)
        }
    }
}

// MARK: - Distance meter

struct DistanceMeterView: View {
    let distance: Float
    let threshold: Float
    var accent: Color = ClinkColors.brandPrimary

    private var watchLimit: Float { threshold * 1.2 }
    private var progress: Double {
        min(Double(distance / max(watchLimit, 0.001)), 1.0)
    }

    private var zoneLabel: String {
        if distance <= threshold { return "Within healthy range" }
        if distance <= watchLimit { return "Watch band — near threshold" }
        return "Beyond watch band"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Spectral fingerprint distance")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.2f", distance))
                    .font(.title3.weight(.bold).monospacedDigit())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Capsule(style: .continuous)
                        .fill(meterGradient)
                        .frame(width: max(4, geo.size.width * progress))
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 10)

            HStack {
                thresholdMarker(label: "Healthy", at: 0, total: 1)
                Spacer()
                Text(zoneLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spectral distance \(String(format: "%.2f", distance)), threshold \(String(format: "%.2f", threshold)). \(zoneLabel)")
    }

    @ViewBuilder
    private func thresholdMarker(label: String, at: CGFloat, total: CGFloat) -> some View {
        Text(String(format: "τ %.1f", threshold))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.tertiary)
    }

    private var meterGradient: LinearGradient {
        LinearGradient(
            colors: [ClinkColors.healthy, ClinkColors.watch, ClinkColors.fault],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - ML row

struct MLProbabilityRow: View {
    let probability: Float

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ClinkColors.brandPrimary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "cpu")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ClinkColors.brandPrimary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Core ML advisory score")
                    .font(.subheadline.weight(.semibold))
                ProgressView(value: Double(probability), total: 1.0)
                    .tint(ClinkColors.brandPrimary)
            }
            Text(String(format: "%.0f%%", probability * 100))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 48, alignment: .trailing)
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
    @State private var appeared = false

    private var appearance: StatusAppearance {
        StatusAppearance.forStatus(result.status, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            statusHeader
            Divider().opacity(0.35)
            metricsGrid
            DistanceMeterView(
                distance: result.distance,
                threshold: result.distanceThreshold,
                accent: appearance.accent
            )
            MLProbabilityRow(probability: result.healthyProbability)
        }
        .padding(24)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: ClinkLayout.cardCornerLarge, style: .continuous)
                    .fill(appearance.softBackground)
                RoundedRectangle(cornerRadius: ClinkLayout.cardCornerLarge, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: ClinkLayout.cardCornerLarge, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [appearance.accent.opacity(0.5), appearance.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: appearance.glow, radius: 24, y: 8)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Health result \(appearance.label)")
    }

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(appearance.softBackground)
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(appearance.accent.opacity(0.35), lineWidth: 2)
                    .frame(width: 72, height: 72)
                Image(systemName: appearance.symbol)
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(appearance.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appearance.label)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(appearance.accent)
                if !fileName.isEmpty {
                    Label(fileName, systemImage: "waveform")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
            WaveformBars(accent: appearance.accent, isActive: true)
        }
    }

    private var metricsGrid: some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "Distance",
                value: String(format: "%.2f", result.distance),
                subtitle: "L2 vs profile centroid",
                symbol: "point.3.connected.trianglepath.dotted",
                tint: appearance.accent
            )
            MetricTile(
                title: "Threshold",
                value: String(format: "%.2f", result.distanceThreshold),
                subtitle: "Healthy gate (primary)",
                symbol: "slider.horizontal.3",
                tint: .secondary
            )
        }
    }
}

// MARK: - Empty & error

struct EmptyResultPlaceholder: View {
    var body: some View {
        GlassCard(cornerRadius: ClinkLayout.cardCornerLarge) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(ClinkColors.brandPrimary.opacity(0.1))
                        .frame(width: 88, height: 88)
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ClinkColors.brandPrimary)
                }
                VStack(spacing: 8) {
                    Text("Ready to listen")
                        .font(.title2.weight(.semibold))
                    Text("Run a bundled healthy or fault sample, or import a ~2 second WAV to compare against this profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ready to listen. Run a test or import audio.")
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(ClinkColors.fault)
            VStack(alignment: .leading, spacing: 4) {
                Text("Something went wrong")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ClinkColors.fault.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ClinkColors.fault.opacity(0.25), lineWidth: 0.5)
        }
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Sidebar

struct SidebarBrandHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            ClinkBrandMark(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clink")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Acoustic health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct ProfileSidebarRow: View {
    let profile: ProfilePack
    let isSelected: Bool

    private var tint: Color { ProfileSymbol.tint(for: profile.id) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isSelected ? tint : .clear)
                .frame(width: 3)
                .padding(.vertical, 6)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? tint.opacity(0.2)
                            : Color.primary.opacity(0.04)
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: ProfileSymbol.systemName(for: profile.id))
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? tint : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.title)
                    .font(.subheadline.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                Text(profile.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                AudiencePill(text: profile.audience)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.06))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.title), \(profile.audience)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Action cluster

struct AnalysisActionCluster: View {
    let isDisabled: Bool
    let isAnalyzing: Bool
    let onHealthy: () -> Void
    let onFault: () -> Void
    let onImport: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Analyze clip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button(action: onHealthy) {
                        Label("Healthy", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClinkProminentButtonStyle(tint: ClinkColors.healthy))
                    .disabled(isDisabled || isAnalyzing)

                    Button(action: onFault) {
                        Label("Fault", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClinkSecondaryButtonStyle())
                    .disabled(isDisabled || isAnalyzing)

                    Button(action: onImport) {
                        Label("Import", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClinkSecondaryButtonStyle())
                    .disabled(isDisabled || isAnalyzing)
                }

                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Analyzing waveform…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(18)
        }
    }
}

struct ClinkProminentButtonStyle: ButtonStyle {
    var tint: Color = ClinkColors.brandPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ClinkSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
