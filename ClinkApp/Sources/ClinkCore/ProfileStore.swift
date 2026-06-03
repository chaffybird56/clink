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

    enum CodingKeys: String, CodingKey {
        case id, title, blurb, audience, centroid
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

    public init() {}

    public func load(bundle: Bundle) throws {
        guard let base = bundle.resourceURL?.appendingPathComponent("profiles") else { return }
        let urls = try FileManager.default.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }

        profiles = try urls.compactMap { dir -> ProfilePack? in
            let json = dir.appendingPathComponent("profile.json")
            guard FileManager.default.fileExists(atPath: json.path) else { return nil }
            let data = try Data(contentsOf: json)
            return try JSONDecoder().decode(ProfilePack.self, from: data)
        }.sorted { $0.title < $1.title }
    }

    public func goldenURL(for profile: ProfilePack, bundle: Bundle) -> URL? {
        bundle.url(forResource: "golden", withExtension: "wav", subdirectory: "profiles/\(profile.id)")
    }

    public func faultURL(for profile: ProfilePack, bundle: Bundle) -> URL? {
        bundle.url(forResource: "fault", withExtension: "wav", subdirectory: "profiles/\(profile.id)")
    }
}
