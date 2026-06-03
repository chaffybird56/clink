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

    private var store = ProfileStore()
    private var scorer: HealthScorer?
    private let bundle = Bundle.module

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
        do {
            result = try scorer.score(profile: profile, audioURL: url)
        } catch {
            errorMessage = error.localizedDescription
            result = nil
        }
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

    var body: some View {
        NavigationSplitView {
            List(model.profiles, selection: $model.selectedId) { p in
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.title).font(.headline)
                    Text(p.blurb).font(.caption).foregroundStyle(.secondary)
                    Text(p.audience).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary.opacity(0.6)).clipShape(Capsule())
                }
                .tag(p.id)
            }
            .navigationTitle("Profile packs")
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                Text("Clink — acoustic health check")
                    .font(.title2.bold())
                Text("Import a short clip (~2 s) or test the built-in healthy / fault sounds for the selected profile.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Test healthy sound") { model.runBundled(golden: true) }
                    Button("Test fault sound") { model.runBundled(golden: false) }
                    Button("Import WAV…") { openWAV() }
                }

                if let r = model.result {
                    resultCard(r)
                }

                if let err = model.errorMessage {
                    Text(err).foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear { model.bootstrap() }
    }

    @ViewBuilder
    private func resultCard(_ r: HealthResult) -> some View {
        let color: Color = {
            switch r.status {
            case .healthy: return .green
            case .watch: return .orange
            case .fault: return .red
            }
        }()
        VStack(alignment: .leading, spacing: 8) {
            Text(r.status.rawValue)
                .font(.largeTitle.bold())
                .foregroundStyle(color)
            Text("File: \(model.lastFile)")
            Text(String(format: "Spectral distance: %.3f (threshold %.3f)", r.distance, r.distanceThreshold))
            Text(String(format: "Core ML healthy probability: %.0f%%", r.healthyProbability * 100))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openWAV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .audio]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.run(url: url)
        }
    }
}
