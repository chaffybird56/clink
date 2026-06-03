import AppKit
import SwiftUI
import ClinkCore
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [ProfilePack] = []
    @Published var selectedId: String = ""
    @Published var result: HealthResult?
    @Published var lastFile: String = ""
    @Published var errorMessage: String?
    @Published var isAnalyzing: Bool = false

    private var store = ProfileStore()
    private var scorer: HealthScorer?
    private let bundle = Bundle.module

    var selectedProfile: ProfilePack? {
        profiles.first { $0.id == selectedId }
    }

    func bootstrap() {
        do {
            try store.load(bundle: bundle)
            profiles = store.profiles
            selectedId = profiles.first?.id ?? ""
            scorer = try HealthScorer(bundle: bundle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func run(url: URL) {
        guard let scorer, let profile = profiles.first(where: { $0.id == selectedId }) else { return }
        errorMessage = nil
        lastFile = url.lastPathComponent
        isAnalyzing = true
        do {
            let scored = try scorer.score(profile: profile, audioURL: url)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                result = scored
            }
        } catch {
            errorMessage = error.localizedDescription
            result = nil
        }
        isAnalyzing = false
    }

    func runBundled(golden: Bool) {
        guard let profile = profiles.first(where: { $0.id == selectedId }) else { return }
        let url = golden
            ? store.goldenURL(for: profile, bundle: bundle)
            : store.faultURL(for: profile, bundle: bundle)
        guard let url else {
            errorMessage = "Bundled clip missing"
            return
        }
        run(url: url)
    }
}

struct ContentView: View {
    @StateObject private var model = AppModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { model.bootstrap() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $model.selectedId) {
            Section {
                if model.profiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No profiles")
                            .font(.headline)
                        Text(model.errorMessage ?? "Profile packs could not be loaded.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(model.profiles) { profile in
                        ProfileSidebarRow(
                            profile: profile,
                            isSelected: model.selectedId == profile.id
                        )
                        .tag(profile.id)
                    }
                }
            } header: {
                Label("Profile packs", systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Clink")
        .navigationSplitViewColumnWidth(min: 220, ideal: ClinkLayout.sidebarWidth, max: 320)
    }

    // MARK: - Detail

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClinkLayout.sectionSpacing) {
                heroHeader

                if let err = model.errorMessage {
                    ErrorBanner(message: err)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                actionBar

                resultSection
            }
            .padding(ClinkLayout.detailPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(detailBackground)
        .toolbar { detailToolbar }
        .navigationTitle(model.selectedProfile?.title ?? "Acoustic health")
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "ear.and.waveform")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acoustic health check")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                    Text("Compare a short clip against the selected profile centroid and Core ML advisory score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let profile = model.selectedProfile {
                HStack(spacing: 8) {
                    Image(systemName: ProfileSymbol.systemName(for: profile.id))
                        .foregroundStyle(.secondary)
                    Text(profile.blurb)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    AudiencePill(text: profile.audience)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                model.runBundled(golden: true)
            } label: {
                Label("Test healthy", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.2, green: 0.62, blue: 0.48))
            .disabled(model.selectedProfile == nil || model.isAnalyzing)
            .accessibilityHint("Plays the bundled golden reference clip for this profile")

            Button {
                model.runBundled(golden: false)
            } label: {
                Label("Test fault", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(model.selectedProfile == nil || model.isAnalyzing)
            .accessibilityHint("Plays the bundled fault reference clip for this profile")

            Button {
                openWAV()
            } label: {
                Label("Import WAV…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(model.selectedProfile == nil || model.isAnalyzing)
            .accessibilityHint("Opens a file panel to analyze a WAV clip")

            if model.isAnalyzing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = model.result {
            HealthResultCard(result: result, fileName: model.lastFile)
                .id("\(result.profileId)-\(result.status.rawValue)-\(model.lastFile)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
        } else if model.selectedProfile != nil {
            EmptyResultPlaceholder()
        }
    }

    private var detailBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.06 : 0.04),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                openWAV()
            } label: {
                Label("Import WAV", systemImage: "doc.badge.plus")
            }
            .help("Import a WAV clip for analysis")
            .disabled(model.selectedProfile == nil)
        }
    }

    private func openWAV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .audio]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a short WAV clip (~2 seconds)"
        if panel.runModal() == .OK, let url = panel.url {
            model.run(url: url)
        }
    }
}
