import Foundation
import AVFoundation

nonisolated enum StudioWhisper {
    struct Word: Decodable { let text: String; let start: Double; let end: Double }
    static func transcribe(asset: AVAsset) async throws -> [CaptionTimeline.Word] {
        guard FileManager.default.isExecutableFile(atPath: StudioPreferences.pythonPath),
              let script = Bundle.main.url(forResource: "studio-whisper", withExtension: "py") else {
            throw StudioProcess.Failure(message: "请在 Studio 设置中填写已安装 faster-whisper 的 Python 路径。")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("studio-whisper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wave = directory.appendingPathComponent("audio.wav")
        nonisolated(unsafe) let source = asset
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do { try writeWave(asset: source, to: wave); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
        try Task.checkCancellation()
        let data = try await StudioProcess.run(URL(fileURLWithPath: StudioPreferences.pythonPath), [script.path, wave.path, StudioPreferences.modelPath])
        let words = try JSONDecoder().decode([Word].self, from: data)
        return words.filter { $0.start.isFinite && $0.end.isFinite && $0.end > $0.start && !$0.text.isEmpty }
            .map { CaptionTimeline.Word(text: $0.text, start: $0.start, end: $0.end) }
    }
    /// Decode with AVFoundation so Apple's edit lists and actual sample times are respected.
    static func writeWave(asset: AVAsset, to url: URL, sampleRate: Int = 16000, channels: Int = 1, selectedTracks: [AVAssetTrack]? = nil) throws {
        let tracks = selectedTracks ?? asset.tracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw StudioProcess.Failure(message: "此视频没有音轨") }
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0, duration * Double(sampleRate * channels * 2) < Double(UInt32.max - 44) else { throw StudioProcess.Failure(message: "视频时长无效或超过音频处理长度上限") }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false])
        reader.add(output)
        guard reader.startReading() else { throw reader.error! }
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 0, count: 44))
        let file = try FileHandle(forWritingTo: url); defer { try? file.close() }
        var last: UInt64 = 44
        while let sample = output.copyNextSampleBuffer() {
            let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard t.isFinite, t >= 0, t < duration + 1, let buffer = CMSampleBufferGetDataBuffer(sample) else { continue }
            var bytes = Data(count: CMBlockBufferGetDataLength(buffer))
            let result = bytes.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
            guard result == kCMBlockBufferNoErr else { throw StudioProcess.Failure(message: "无法读取音频采样") }
            let position = 44 + UInt64((t * Double(sampleRate)).rounded()) * UInt64(channels * 2)
            try file.seek(toOffset: position); try file.write(contentsOf: bytes)
            last = max(last, position + UInt64(bytes.count))
        }
        guard reader.status == .completed else { throw reader.error ?? StudioProcess.Failure(message: "音轨解码失败") }
        var header = Data()
        func tag(_ s: String) { header.append(contentsOf: s.utf8) }
        func u32(_ n: UInt32) { var v=n.littleEndian; withUnsafeBytes(of: &v) { header.append(contentsOf: $0) } }
        func u16(_ n: UInt16) { var v=n.littleEndian; withUnsafeBytes(of: &v) { header.append(contentsOf: $0) } }
        tag("RIFF"); u32(UInt32(last-8)); tag("WAVEfmt "); u32(16); u16(1); u16(UInt16(channels)); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * channels * 2)); u16(UInt16(channels * 2)); u16(16); tag("data"); u32(UInt32(last-44))
        try file.seek(toOffset: 0); try file.write(contentsOf: header)
    }
}
