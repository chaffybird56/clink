import Foundation
import AVFoundation

public enum BaselineRecorderError: LocalizedError {
    case permissionDenied
    case alreadyRecording

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied. Enable it in System Settings → Privacy & Security → Microphone."
        case .alreadyRecording:
            return "A recording is already in progress."
        }
    }
}

/// Captures a short clip from the default microphone and writes it as a
/// 22.05 kHz mono WAV — the exact format the feature pipeline trains on.
public final class BaselineRecorder {
    private let engine = AVAudioEngine()
    private var isRecording = false

    public init() {}

    public static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    /// Records `seconds` of audio, then calls back on the main queue with the
    /// temp WAV URL (or an error).
    public func record(seconds: Double, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(BaselineRecorderError.alreadyRecording))
            return
        }
        isRecording = true

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: FeatureExtractor.sampleRate,
            channels: 1,
            interleaved: false
        )!

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clink-baseline-\(UUID().uuidString).wav")

        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: targetFormat.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw BaselineRecorderError.permissionDenied
            }

            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
                let ratio = targetFormat.sampleRate / inputFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
                guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
                var fed = false
                var convError: NSError?
                converter.convert(to: out, error: &convError) { _, status in
                    if fed {
                        status.pointee = .noDataNow
                        return nil
                    }
                    fed = true
                    status.pointee = .haveData
                    return buffer
                }
                if convError == nil {
                    try? file.write(from: out)
                }
            }

            engine.prepare()
            try engine.start()
        } catch {
            isRecording = false
            completion(.failure(error))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            self.engine.inputNode.removeTap(onBus: 0)
            self.engine.stop()
            self.isRecording = false
            completion(.success(url))
        }
    }
}
