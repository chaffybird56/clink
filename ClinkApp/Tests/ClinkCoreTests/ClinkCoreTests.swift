import XCTest
@testable import ClinkCore

final class ClinkCoreTests: XCTestCase {
    // MARK: - Fixtures

    private func fixtureURL(_ name: String) throws -> URL {
        let url = Bundle.module.resourceURL?
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try XCTUnwrap(url, "missing fixture \(name)")
    }

    private func makeExtractor() throws -> FeatureExtractor {
        try FeatureExtractor(melFiltersURL: fixtureURL("mel_filters.json"))
    }

    private struct ParityFixture: Decodable {
        let profile: String
        let vector: [Float]
    }

    private func euclidean(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<min(a.count, b.count) {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sum.squareRoot()
    }

    // MARK: - Feature extraction

    /// Swift vDSP features must stay close enough to the Python (librosa)
    /// training features that a golden clip clears its own profile threshold.
    func testFeatureParityWithPythonPipeline() throws {
        let extractor = try makeExtractor()
        let swiftVector = try extractor.extract(url: fixtureURL("golden.wav")).vector

        let fixture = try JSONDecoder().decode(
            ParityFixture.self,
            from: Data(contentsOf: fixtureURL("parity_fixture.json"))
        )
        let profile = try JSONDecoder().decode(
            ProfilePack.self,
            from: Data(contentsOf: fixtureURL("profile.json"))
        )

        XCTAssertEqual(swiftVector.count, FeatureExtractor.featureDim)
        XCTAssertEqual(fixture.vector.count, FeatureExtractor.featureDim)
        XCTAssertTrue(swiftVector.allSatisfy { $0.isFinite })

        let drift = euclidean(swiftVector, fixture.vector)
        XCTAssertLessThan(
            drift, profile.distanceThreshold,
            "Swift/Python feature drift (\(drift)) exceeds the profile gate (\(profile.distanceThreshold))"
        )
    }

    func testFeatureExtractionIsDeterministic() throws {
        let extractor = try makeExtractor()
        let a = try extractor.extract(url: fixtureURL("golden.wav")).vector
        let b = try extractor.extract(url: fixtureURL("golden.wav")).vector
        XCTAssertEqual(a, b)
    }

    func testShortClipIsZeroPadded() throws {
        let extractor = try makeExtractor()
        let halfSecond = [Float](repeating: 0.25, count: Int(FeatureExtractor.sampleRate * 0.5))
        let vector = extractor.extract(samples: halfSecond).vector
        XCTAssertEqual(vector.count, FeatureExtractor.featureDim)
        XCTAssertTrue(vector.allSatisfy { $0.isFinite })
    }

    // MARK: - Scoring policy

    func testStatusMappingBands() {
        XCTAssertEqual(HealthScorer.status(distance: 50, threshold: 100), .healthy)
        XCTAssertEqual(HealthScorer.status(distance: 100, threshold: 100), .healthy)
        XCTAssertEqual(HealthScorer.status(distance: 105, threshold: 100), .watch)
        XCTAssertEqual(HealthScorer.status(distance: 110, threshold: 100), .watch)
        XCTAssertEqual(HealthScorer.status(distance: 111, threshold: 100), .fault)
        XCTAssertEqual(HealthScorer.status(distance: 500, threshold: 100), .fault)
    }

    // MARK: - Layer 4: baseline builder

    func testBaselineBuilderSeparatesGoldenFromFault() throws {
        let extractor = try makeExtractor()
        let builder = BaselineBuilder(extractor: extractor)
        let profile = try builder.buildProfile(
            id: "test_baseline",
            title: "Test baseline",
            goldenURL: fixtureURL("golden.wav")
        )

        XCTAssertTrue(profile.isCustom)
        XCTAssertEqual(profile.centroid.count, FeatureExtractor.featureDim)
        XCTAssertGreaterThanOrEqual(profile.distanceThreshold, BaselineBuilder.thresholdFloor)

        let goldenDist = euclidean(
            try extractor.extract(url: fixtureURL("golden.wav")).vector,
            profile.centroid
        )
        let faultDist = euclidean(
            try extractor.extract(url: fixtureURL("fault.wav")).vector,
            profile.centroid
        )
        XCTAssertEqual(HealthScorer.status(distance: goldenDist, threshold: profile.distanceThreshold), .healthy)
        XCTAssertNotEqual(HealthScorer.status(distance: faultDist, threshold: profile.distanceThreshold), .healthy)
        XCTAssertGreaterThan(faultDist, goldenDist)
    }

    func testBaselineBuilderRejectsBadIds() throws {
        let builder = BaselineBuilder(extractor: try makeExtractor())
        XCTAssertThrowsError(
            try builder.buildProfile(id: "bad id!", title: "x", goldenURL: fixtureURL("golden.wav"))
        )
        XCTAssertTrue(BaselineBuilder.isValidId("my_fan-2"))
        XCTAssertFalse(BaselineBuilder.isValidId(""))
        XCTAssertFalse(BaselineBuilder.isValidId("../escape"))
    }

    // MARK: - Layer 4: custom profile persistence

    func testCustomProfileRoundTripAndDelete() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("clink-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = ProfileStore(customRoot: tempRoot)
        let builder = BaselineBuilder(extractor: try makeExtractor())
        let profile = try builder.buildProfile(
            id: "roundtrip",
            title: "Round trip",
            goldenURL: fixtureURL("golden.wav")
        )

        try store.saveCustom(profile: profile, goldenFrom: fixtureURL("golden.wav"), bundle: .module)
        let loaded = try XCTUnwrap(store.profiles.first { $0.id == "roundtrip" })
        XCTAssertTrue(loaded.isCustom)
        XCTAssertEqual(loaded.centroid, profile.centroid)
        XCTAssertEqual(loaded.distanceThreshold, profile.distanceThreshold)

        let golden = try XCTUnwrap(store.goldenURL(for: loaded, bundle: .module))
        XCTAssertTrue(FileManager.default.fileExists(atPath: golden.path))
        XCTAssertNil(store.faultURL(for: loaded, bundle: .module))

        try store.deleteCustom(id: "roundtrip", bundle: .module)
        XCTAssertNil(store.profiles.first { $0.id == "roundtrip" })
        XCTAssertFalse(FileManager.default.fileExists(atPath: golden.path))
    }
}
