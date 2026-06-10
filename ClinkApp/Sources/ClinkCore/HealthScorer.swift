import Foundation
import CoreML

public enum HealthScorerError: Error {
    case modelMissing
}

public final class HealthScorer {
    private let model: MLModel
    private let extractor: FeatureExtractor

    public init(bundle: Bundle) throws {
        guard let modelURL = bundle.url(forResource: "ClinkHealth", withExtension: "mlpackage") else {
            throw HealthScorerError.modelMissing
        }
        // ML Program packages must be compiled before inference (Xcode does this automatically).
        let compiledURL = try MLModel.compileModel(at: modelURL)
        model = try MLModel(contentsOf: compiledURL)
        extractor = try FeatureExtractor(bundle: bundle)
    }

    /// Distance to profile centroid is primary; Core ML probability is advisory (WATCH band).
    public static func status(distance: Float, threshold: Float) -> HealthResult.Status {
        if distance <= threshold { return .healthy }
        if distance <= threshold * 1.1 { return .watch }
        return .fault
    }

    public func score(profile: ProfilePack, audioURL: URL) throws -> HealthResult {
        let feats = try extractor.extract(url: audioURL).vector
        let dist = euclidean(feats, profile.centroid)
        let prob = try healthyProbability(features: feats)
        let status = Self.status(distance: dist, threshold: profile.distanceThreshold)

        return HealthResult(
            profileId: profile.id,
            distance: dist,
            distanceThreshold: profile.distanceThreshold,
            healthyProbability: prob,
            status: status
        )
    }

    private func healthyProbability(features: [Float]) throws -> Float {
        let arr = try MLMultiArray(features)
        let provider = try MLDictionaryFeatureProvider(dictionary: ["features": arr])
        let out = try model.prediction(from: provider)
        if let multi = out.featureValue(for: "healthy_probability")?.multiArrayValue {
            return multi[0].floatValue
        }
        return 0.5
    }

    private func euclidean(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<min(a.count, b.count) {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sqrt(sum)
    }
}

extension MLMultiArray {
    convenience init(_ floats: [Float]) throws {
        try self.init(shape: [1, NSNumber(value: floats.count)], dataType: .float32)
        let ptr = self.dataPointer.bindMemory(to: Float.self, capacity: floats.count)
        for (i, v) in floats.enumerated() { ptr[i] = v }
    }
}
