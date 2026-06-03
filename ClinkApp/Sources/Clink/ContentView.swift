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
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
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
                SidebarBrandHeader()
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if model.profiles.isEmpty {
                    sidebarEmpty
                } else {
                    ForEach(model.profiles) { profile in
                        ProfileSidebarRow(
                            profile: profile,
                            isSelected: model.selectedId == profile.id
                        )
                        .tag(profile.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .navigationSplitViewColumnWidth(min: 240, ideal: ClinkLayout.sidebarWidth, max: 300)
    }

    private var sidebarEmpty: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No profiles loaded")
                .font(.subheadline.weight(.medium))
            if let err = model.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }

    // MARK: - Detail

    private var detailPane: some View {
        ZStack {
            MeshBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: ClinkLayout.sectionSpacing) {
                    profileHero
                    if let err = model.errorMessage {
                        ErrorBanner(message: err)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    AnalysisActionCluster(
                        isDisabled: model.selectedProfile == nil,
                        isAnalyzing: model.isAnalyzing,
                        onHealthy: { model.runBundled(golden: true) },
                        onFault: { model.runBundled(golden: false) },
                        onImport: { openWAV() }
                    )
                    resultSection
                }
                .padding(ClinkLayout.detailPadding)
                .frame(maxWidth: ClinkLayout.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .toolbar { detailToolbar }
        .navigationTitle("")
    }

    private var profileHero: some View {
        GlassCard(cornerRadius: ClinkLayout.cardCornerLarge) {
            HStack(alignment: .top, spacing: 20) {
                if let profile = model.selectedProfile {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ProfileSymbol.tint(for: profile.id).opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: ProfileSymbol.systemName(for: profile.id))
                            .font(.system(size: 26, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ProfileSymbol.tint(for: profile.id))
                    }
                } else {
                    ClinkBrandMark(size: 56)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.selectedProfile?.title ?? "Select a profile")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(model.selectedProfile?.blurb ?? "Choose a machine signature from the sidebar — each pack learns a golden spectral fingerprint.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let profile = model.selectedProfile {
                        HStack(spacing: 8) {
                            AudiencePill(text: profile.audience)
                            Label("~2 s WAV", systemImage: "clock")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(22)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = model.result {
            HealthResultCard(result: result, fileName: model.lastFile)
                .id("\(result.profileId)-\(result.status.rawValue)-\(model.lastFile)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 12)),
                    removal: .opacity
                ))
        } else if model.selectedProfile != nil {
            EmptyResultPlaceholder()
                .transition(.opacity)
        }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                ClinkBrandMark(size: 22)
                Text("Clink")
                    .font(.headline.weight(.semibold))
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                openWAV()
            } label: {
                Label("Import WAV", systemImage: "doc.badge.plus")
            }
            .help("Import a short WAV clip for analysis")
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
