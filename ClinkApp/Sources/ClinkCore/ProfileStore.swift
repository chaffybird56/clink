import Foundation

public struct ProfilePack: Identifiable, Codable {
    public let id: String
    public let title: String
    public let blurb: String
    public let audience: String
    public let centroid: [Float]
    public let distanceThreshold: Float
    public let healthyMlProbability: Float?
    public let faultMlProbability: Float?
    /// True for user-created baselines persisted outside the app bundle.
    public let custom: Bool?

    public var isCustom: Bool { custom ?? false }

    public init(
        id: String,
        title: String,
        blurb: String,
        audience: String,
        centroid: [Float],
        distanceThreshold: Float,
        healthyMlProbability: Float? = nil,
        faultMlProbability: Float? = nil,
        custom: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.blurb = blurb
        self.audience = audience
        self.centroid = centroid
        self.distanceThreshold = distanceThreshold
        self.healthyMlProbability = healthyMlProbability
        self.faultMlProbability = faultMlProbability
        self.custom = custom
    }

    enum CodingKeys: String, CodingKey {
        case id, title, blurb, audience, centroid, custom
        case distanceThreshold = "distance_threshold"
        case healthyMlProbability = "healthy_ml_probability"
        case faultMlProbability = "fault_ml_probability"
    }
}

public struct HealthResult {
    public let profileId: String
    public let distance: Float
    public let distanceThreshold: Float
    public let healthyProbability: Float
    public let status: Status

    public enum Status: String {
        case healthy = "HEALTHY"
        case watch = "WATCH"
        case fault = "FAULT"
    }
}

public final class ProfileStore {
    public private(set) var profiles: [ProfilePack] = []

    /// Directory holding user-created profiles (overridable for tests/CLI).
    public let customRoot: URL

    public init(customRoot: URL? = nil) {
        if let customRoot {
            self.customRoot = customRoot
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.customRoot = support.appendingPathComponent("Clink/profiles", isDirectory: true)
        }
    }

    public func load(bundle: Bundle) throws {
        var all: [ProfilePack] = []
        if let base = bundle.resourceURL?.appendingPathComponent("profiles") {
            all += try loadPacks(in: base)
        }
        all += (try? loadPacks(in: customRoot)) ?? []
        profiles = all.sorted {
            if $0.isCustom != $1.isCustom { return !$0.isCustom }
            return $0.title < $1.title
        }
    }

    private func loadPacks(in base: URL) throws -> [ProfilePack] {
        guard FileManager.default.fileExists(atPath: base.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }

        return try urls.compactMap { dir -> ProfilePack? in
            let json = dir.appendingPathComponent("profile.json")
            guard FileManager.default.fileExists(atPath: json.path) else { return nil }
            let data = try Data(contentsOf: json)
            return try JSONDecoder().decode(ProfilePack.self, from: data)
        }
    }

    // MARK: - Custom profile persistence (Layer 4)

    /// Persists a custom profile plus a copy of its golden clip, then reloads.
    @discardableResult
    public func saveCustom(profile: ProfilePack, goldenFrom sourceURL: URL, bundle: Bundle) throws -> URL {
        let dir = customRoot.appendingPathComponent(profile.id, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: dir.appendingPathComponent("profile.json"))

        let goldenDest = dir.appendingPathComponent("golden.wav")
        if FileManager.default.fileExists(atPath: goldenDest.path) {
            try FileManager.default.removeItem(at: goldenDest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: goldenDest)

        try load(bundle: bundle)
        return dir
    }

    public func deleteCustom(id: String, bundle: Bundle) throws {
        let dir = customRoot.appendingPathComponent(id, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        try load(bundle: bundle)
    }

    // MARK: - Clip lookup

    public func goldenURL(for profile: ProfilePack, bundle: Bundle) -> URL? {
        if profile.isCustom {
            let url = customRoot.appendingPathComponent("\(profile.id)/golden.wav")
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return bundle.url(forResource: "golden", withExtension: "wav", subdirectory: "profiles/\(profile.id)")
    }

    public func faultURL(for profile: ProfilePack, bundle: Bundle) -> URL? {
        guard !profile.isCustom else { return nil }
        return bundle.url(forResource: "fault", withExtension: "wav", subdirectory: "profiles/\(profile.id)")
    }
}
