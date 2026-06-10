import AppKit
import ClinkCore

let args = CommandLine.arguments

func argValue(_ flag: String) -> String? {
    guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

if args.contains("--demo") {
    do {
        let code = try DemoRunner.run(bundle: .module)
        exit(code)
    } catch {
        fputs("Clink demo error: \(error)\n", stderr)
        exit(2)
    }
}

// Layer 4 CLI: Clink --make-profile <golden.wav> --id my_fan [--name "My fan"]
if let wavPath = argValue("--make-profile") {
    do {
        guard let id = argValue("--id") else {
            fputs("Usage: Clink --make-profile <golden.wav> --id <id> [--name <display name>]\n", stderr)
            exit(64)
        }
        let name = argValue("--name") ?? id
        let url = URL(fileURLWithPath: wavPath)

        let extractor = try FeatureExtractor(bundle: .module)
        let builder = BaselineBuilder(extractor: extractor)
        let profile = try builder.buildProfile(id: id, title: name, goldenURL: url)

        let store = ProfileStore()
        let dir = try store.saveCustom(profile: profile, goldenFrom: url, bundle: .module)

        let scorer = try HealthScorer(bundle: .module)
        let check = try scorer.score(profile: profile, audioURL: url)

        print("Created custom profile \"\(name)\" (\(id))")
        print(String(format: "  threshold=%.2f  self-check=%@ dist=%.2f",
                     profile.distanceThreshold, check.status.rawValue, check.distance))
        print("  saved to \(dir.path)")
        exit(check.status == .healthy ? 0 : 1)
    } catch {
        fputs("Clink make-profile error: \(error.localizedDescription)\n", stderr)
        exit(2)
    }
}

ClinkApp.main()
