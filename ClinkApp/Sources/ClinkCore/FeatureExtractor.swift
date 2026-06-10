import Foundation
import Accelerate
import AVFoundation

public struct AudioFeatures {
    public let vector: [Float]
}

public enum FeatureExtractorError: Error {
    case loadFailed
    case invalidFilters
}

public final class FeatureExtractor {
    public static let sampleRate: Double = 22_050
    public static let duration: Double = 2.0
    public static let featureDim = 64

    private let nFFT: Int
    private let hop: Int = 512
    private let nMels: Int
    private let melFilters: [[Float]]
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]

    public convenience init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "mel_filters", withExtension: "json") else {
            throw FeatureExtractorError.invalidFilters
        }
        try self.init(melFiltersURL: url)
    }

    public init(melFiltersURL url: URL) throws {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nfft = json["n_fft"] as? Int,
              let nm = json["n_mels"] as? Int,
              let raw = json["filters"] as? [[Double]]
        else { throw FeatureExtractorError.invalidFilters }
        nFFT = nfft
        nMels = nm
        melFilters = raw.map { $0.map { Float($0) } }
        log2n = vDSP_Length(log2(Float(nFFT)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw FeatureExtractorError.invalidFilters
        }
        fftSetup = setup
        window = [Float](repeating: 0, count: nFFT)
        vDSP_hann_window(&window, vDSP_Length(nFFT), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    public func extract(url: URL) throws -> AudioFeatures {
        let samples = try Self.loadSamples(url: url)
        return extract(samples: samples)
    }

    /// Feature vector from raw 22.05 kHz mono samples, padded/truncated to 2.0 s.
    public func extract(samples: [Float]) -> AudioFeatures {
        let need = Int(Self.sampleRate * Self.duration)
        var clip = Array(samples.prefix(need))
        if clip.count < need { clip += [Float](repeating: 0, count: need - clip.count) }
        return AudioFeatures(vector: melFeatureVector(samples: clip))
    }

    /// Loads the entire file as 22.05 kHz mono float samples.
    /// Files already in the target format are read directly (bit-exact with the
    /// training pipeline); anything else goes through AVAudioConverter.
    public static func loadSamples(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let native = file.processingFormat
        if native.sampleRate == target.sampleRate && native.channelCount == 1 {
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: frames) else {
                throw FeatureExtractorError.loadFailed
            }
            try file.read(into: buffer, frameCount: frames)
            guard let ch = buffer.floatChannelData?[0] else { throw FeatureExtractorError.loadFailed }
            return Array(UnsafeBufferPointer(start: ch, count: Int(buffer.frameLength)))
        }

        // Arbitrary user WAVs: resample / downmix to the training format.
        let inFrames = AVAudioFrameCount(file.length)
        guard inFrames > 0, let inBuffer = AVAudioPCMBuffer(pcmFormat: native, frameCapacity: inFrames) else {
            throw FeatureExtractorError.loadFailed
        }
        try file.read(into: inBuffer, frameCount: inFrames)

        guard let converter = AVAudioConverter(from: native, to: target) else {
            throw FeatureExtractorError.loadFailed
        }
        let ratio = target.sampleRate / native.sampleRate
        let outCapacity = AVAudioFrameCount((Double(inFrames) * ratio).rounded(.up) + 1024)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCapacity) else {
            throw FeatureExtractorError.loadFailed
        }
        var fed = false
        var convError: NSError?
        converter.convert(to: outBuffer, error: &convError) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return inBuffer
        }
        if let convError { throw convError }
        guard let ch = outBuffer.floatChannelData?[0] else { throw FeatureExtractorError.loadFailed }
        return Array(UnsafeBufferPointer(start: ch, count: Int(outBuffer.frameLength)))
    }

    /// Matches train/features.py: melspectrogram power + librosa.power_to_db(ref=max).
    private func melFeatureVector(samples: [Float]) -> [Float] {
        let frameCount = max(1, 1 + (samples.count - nFFT) / hop)
        var powerFrames = [[Float]](repeating: [Float](repeating: 0, count: nMels), count: frameCount)

        let half = nFFT / 2
        var realIn = [Float](repeating: 0, count: half)
        var imagIn = [Float](repeating: 0, count: half)
        var mag = [Float](repeating: 0, count: half + 1)

        for f in 0..<frameCount {
            let start = f * hop
            for i in 0..<half {
                let i0 = start + 2 * i
                let i1 = start + 2 * i + 1
                realIn[i] = (i0 < samples.count ? samples[i0] : 0) * window[2 * i]
                imagIn[i] = (i1 < samples.count ? samples[i1] : 0) * window[2 * i + 1]
            }
            realIn.withUnsafeMutableBufferPointer { rBuf in
                imagIn.withUnsafeMutableBufferPointer { iBuf in
                    var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &mag, 1, vDSP_Length(half))
                }
            }
            mag[0] = realIn[0] * realIn[0]
            for m in 0..<nMels {
                var e: Float = 0
                for k in 0..<mag.count where k < melFilters[m].count {
                    e += melFilters[m][k] * mag[k]
                }
                powerFrames[f][m] = e
            }
        }

        var globalMax: Float = 1e-10
        for row in powerFrames {
            for v in row { globalMax = max(globalMax, v) }
        }

        var logMel = powerFrames
        for fi in 0..<frameCount {
            for m in 0..<nMels {
                let ratio = max(logMel[fi][m] / globalMax, 1e-10)
                logMel[fi][m] = 10 * log10(ratio)
            }
        }

        var means = [Float](repeating: 0, count: nMels)
        var stds = [Float](repeating: 0, count: nMels)
        for m in 0..<nMels {
            let col = logMel.map { $0[m] }
            var mu: Float = 0
            var sq: Float = 0
            vDSP_meanv(col, 1, &mu, vDSP_Length(col.count))
            let diff = col.map { $0 - mu }
            vDSP_measqv(diff, 1, &sq, vDSP_Length(diff.count))
            means[m] = mu
            stds[m] = sqrt(sq)
        }
        return means + stds
    }
}
