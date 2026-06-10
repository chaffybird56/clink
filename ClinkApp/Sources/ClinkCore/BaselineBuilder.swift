import Foundation

public enum BaselineBuilderError: LocalizedError {
    case clipTooShort(seconds: Double)
    case invalidIdentifier(String)

    public var errorDescription: String? {
        switch self {
        case .clipTooShort(let seconds):
            return String(format: "Clip is %.2f s — record at least %.1f s of steady healthy sound.",
                          seconds, BaselineBuilder.minimumSeconds)
        case .invalidIdentifier(let id):
            return "\"\(id)\" is not a valid profile id (use letters, digits, _ or -)."
        }
    }
}

/// Layer 4 — "record your baseline": turns one healthy WAV into a custom
/// profile pack (centroid + self-calibrated distance threshold).
///
/// The clip is sliced into overlapping 2.0 s windows; the centroid is the mean
/// feature vector and the threshold is the worst intra-clip drift scaled with
/// headroom (floored so very steady sounds keep a usable WATCH band).
public struct BaselineBuilder {
    public static let minimumSeconds: Double = 1.0
    public static let windowHopSeconds: Double = 1.0
    public static let thresholdHeadroom: Float = 1.6
    public static let thresholdFloor: Float = 30.0

    private let extractor: FeatureExtractor

    public init(extractor: FeatureExtractor) {
        self.extractor = extractor
    }

    public func buildProfile(
        id: String,
        title: String,
        goldenURL: URL,
        blurb: String = "Custom baseline learned from your own clip.",
        audience: String = "You"
    ) throws -> ProfilePack {
        guard Self.isValidId(id) else { throw BaselineBuilderError.invalidIdentifier(id) }

        let samples = try FeatureExtractor.loadSamples(url: goldenURL)
        let seconds = Double(samples.count) / FeatureExtractor.sampleRate
        guard seconds >= Self.minimumSeconds else {
            throw BaselineBuilderError.clipTooShort(seconds: seconds)
        }

        let vectors = windowVectors(samples: samples)
        let centroid = mean(of: vectors)
        let worstDrift = vectors.map { euclidean($0, centroid) }.max() ?? 0
        let threshold = max(Self.thresholdFloor, Self.thresholdHeadroom * worstDrift)

        return ProfilePack(
            id: id,
            title: title,
            blurb: blurb,
            audience: audience,
            centroid: centroid,
            distanceThreshold: threshold,
            healthyMlProbability: nil,
            faultMlProbability: nil,
            custom: true
        )
    }

    public static func isValidId(_ id: String) -> Bool {
        !id.isEmpty && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    /// Overlapping 2.0 s windows (1.0 s hop); short clips yield one padded window.
    private func windowVectors(samples: [Float]) -> [[Float]] {
        let win = Int(FeatureExtractor.sampleRate * FeatureExtractor.duration)
        let hop = Int(FeatureExtractor.sampleRate * Self.windowHopSeconds)
        guard samples.count > win else {
            return [extractor.extract(samples: samples).vector]
        }
        var vectors: [[Float]] = []
        var start = 0
        while start + win <= samples.count {
            vectors.append(extractor.extract(samples: Array(samples[start..<(start + win)])).vector)
            start += hop
        }
        // Cover the tail so the end of the clip also informs the baseline.
        if start < samples.count, samples.count - (start - hop) > win / 2 {
            vectors.append(extractor.extract(samples: Array(samples.suffix(win))).vector)
        }
        return vectors
    }

    private func mean(of vectors: [[Float]]) -> [Float] {
        guard let first = vectors.first else { return [] }
        var acc = [Float](repeating: 0, count: first.count)
        for v in vectors {
            for i in 0..<acc.count { acc[i] += v[i] }
        }
        let n = Float(vectors.count)
        return acc.map { $0 / n }
    }

    private func euclidean(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<min(a.count, b.count) {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sum.squareRoot()
    }
}
