import Foundation
import ClinkCore

enum DemoRunner {
    static func run(bundle: Bundle) throws -> Int32 {
        let store = ProfileStore()
        try store.load(bundle: bundle)
        let scorer = try HealthScorer(bundle: bundle)

        print("Clink — local demo (same scoring as GUI)\n")
        var failures = 0

        for profile in store.profiles {
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

        if failures == 0 {
            print("All bundled clips scored as expected.")
            return 0
        }
        print("\(failures) check(s) failed.")
        return 1
    }
}
