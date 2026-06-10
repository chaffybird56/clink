import Foundation
import ClinkCore

enum DemoRunner {
    static func run(bundle: Bundle) throws -> Int32 {
        let store = ProfileStore()
        try store.load(bundle: bundle)
        let scorer = try HealthScorer(bundle: bundle)

        print("Clink — local demo (same scoring as GUI)\n")
        var failures = 0

        for profile in store.profiles where !profile.isCustom {
            print("=== \(profile.title) (\(profile.id)) ===")
            for golden in [true, false] {
                let label = golden ? "golden" : "fault"
                guard let url = golden
                    ? store.goldenURL(for: profile, bundle: bundle)
                    : store.faultURL(for: profile, bundle: bundle)
                else {
                    print("  \(label): MISSING")
                    failures += 1
                    continue
                }
                let result = try scorer.score(profile: profile, audioURL: url)
                let ok = golden
                    ? result.status == .healthy
                    : result.status == .fault
                if !ok { failures += 1 }
                let mark = ok ? "OK" : "FAIL"
                print(
                    "  \(label.padding(toLength: 6, withPad: " ", startingAt: 0)) "
                        + "[\(mark)] \(result.status.rawValue)  "
                        + String(format: "dist=%.2f thresh=%.2f ml=%.0f%%",
                                 result.distance, result.distanceThreshold,
                                 result.healthyProbability * 100)
                )
            }
            print()
        }

        failures += try baselineSelfCheck(bundle: bundle, scorer: scorer, store: store)

        if failures == 0 {
            print("All bundled clips scored as expected.")
            return 0
        }
        print("\(failures) check(s) failed.")
        return 1
    }

    /// Layer 4 gate: build a custom profile from a bundled golden clip and make
    /// sure its own clip stays HEALTHY while the paired fault clip is flagged.
    private static func baselineSelfCheck(bundle: Bundle, scorer: HealthScorer, store: ProfileStore) throws -> Int {
        print("=== Layer 4 — record-your-baseline self-check ===")
        guard let reference = store.profiles.first(where: { !$0.isCustom }),
              let golden = store.goldenURL(for: reference, bundle: bundle),
              let fault = store.faultURL(for: reference, bundle: bundle)
        else {
            print("  SKIP (no bundled profile with golden/fault pair)")
            return 0
        }

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("clink-demo-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let extractor = try FeatureExtractor(bundle: bundle)
        let builder = BaselineBuilder(extractor: extractor)
        let custom = try builder.buildProfile(
            id: "demo_baseline",
            title: "Demo baseline",
            goldenURL: golden
        )
        let tempStore = ProfileStore(customRoot: tempRoot)
        try tempStore.saveCustom(profile: custom, goldenFrom: golden, bundle: bundle)
        guard let saved = tempStore.profiles.first(where: { $0.id == "demo_baseline" }),
              let savedGolden = tempStore.goldenURL(for: saved, bundle: bundle)
        else {
            print("  FAIL custom profile did not round-trip through the store")
            print()
            return 1
        }

        var failures = 0
        let healthy = try scorer.score(profile: saved, audioURL: savedGolden)
        let drifted = try scorer.score(profile: saved, audioURL: fault)
        for (label, result, ok) in [
            ("golden", healthy, healthy.status == .healthy),
            ("fault ", drifted, drifted.status != .healthy),
        ] {
            if !ok { failures += 1 }
            print(
                "  \(label) [\(ok ? "OK" : "FAIL")] \(result.status.rawValue)  "
                    + String(format: "dist=%.2f thresh=%.2f", result.distance, result.distanceThreshold)
            )
        }
        print()
        return failures
    }
}
