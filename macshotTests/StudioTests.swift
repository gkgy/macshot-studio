import XCTest
import AVFoundation
import CoreImage

final class StudioTests: XCTestCase {
    func testCameraBackgroundsAreDistinctAndRemainBrightInCenterCrop() throws {
        XCTAssertGreaterThanOrEqual(StudioCameraBackgrounds.all.count, 10)
        XCTAssertEqual(Set(StudioCameraBackgrounds.all.map(\.id)).count, StudioCameraBackgrounds.all.count)
        let context = CIContext()
        var fingerprints = Set<Data>()
        for preset in StudioCameraBackgrounds.all {
            let image = try XCTUnwrap(StudioCameraBackgrounds.image(id: preset.id, patternScale: 1))
            // The circle uses the center of the source; test this region, not its outer edges.
            let region = CGRect(x: 160,y:160,width:320,height:320)
            var pixel = [UInt8](repeating: 0, count: 4)
            let average = image.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: region)])
            context.render(average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x:0,y:0,width:1,height:1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            XCTAssertGreaterThan(Int(pixel[0])+Int(pixel[1])+Int(pixel[2]), 240, preset.title)
            fingerprints.insert(Data(pixel))
        }
        XCTAssertEqual(fingerprints.count, StudioCameraBackgrounds.all.count)
    }
    func testFaceAnchoringCancelsTranslationWithoutChangingScale() {
        let extent = CGRect(x:0,y:0,width:1280,height:720)
        for x in [0.35,0.48,0.62] {
            let face = CGRect(x:x-0.08,y:0.60,width:0.16,height:0.20)
            let transform = StudioBackgroundProcessor.anchoring(face: face, extent: extent, strength: 1)
            let point = CGPoint(x:face.midX*extent.width,y:face.midY*extent.height).applying(transform)
            XCTAssertEqual(point.x, extent.width*0.5, accuracy:0.001)
            XCTAssertEqual(point.y, extent.height*0.66, accuracy:0.001)
            XCTAssertEqual(transform.a,1); XCTAssertEqual(transform.d,1)
            XCTAssertEqual(StudioBackgroundProcessor.anchoring(face:face,extent:extent,strength:0), .identity)
        }
    }
    func testCameraControlsPersistAndOldProjectGetsBrightDefault() throws {
        var style = VideoCameraStyle()
        style.backgroundPreset = "rose-orbit";style.backgroundBrightness = 0.2
        style.backgroundPatternScale = 1.5;style.stabilizationStrength = 0.7
        XCTAssertEqual(try JSONDecoder().decode(VideoCameraStyle.self, from: JSONEncoder().encode(style)),style)
        let old = try JSONDecoder().decode(VideoCameraStyle.self,from:Data("{}".utf8))
        XCTAssertEqual(old.backgroundPreset,"cyan-grid");XCTAssertTrue(old.stabilizePerson)
    }

    func testCameraDefaultsAndOldProjectsDecodeWithoutLosingExplicitSize() throws {
        XCTAssertEqual(VideoCameraStyle().size, 0.10)
        XCTAssertTrue(VideoCameraStyle().techBackground)
        let old = try JSONDecoder().decode(VideoCameraStyle.self, from: Data("{\"size\":0.16}".utf8))
        XCTAssertEqual(old.size, 0.16)
        XCTAssertTrue(old.techBackground)
        let saved = try JSONEncoder().encode(old)
        XCTAssertEqual(try JSONDecoder().decode(VideoCameraStyle.self, from: saved), old)
    }
    func testOnePointFiveTimesKeepsPreciseSourceTimeline() {
        let clip = VideoSpeedSegment(startTime: 0, endTime: 90, speedFactor: 1.5)
        XCTAssertEqual(clip.compositionDuration, 60, accuracy: 0.00001)
        XCTAssertTrue(VideoSpeedSegment.presetFactors.contains(1.25))
        XCTAssertTrue(VideoSpeedSegment.presetFactors.contains(1.5))
    }
    func testChineseWhisperPhrasesDoNotMergeIntoUnreadableParagraph() {
        let words = [CaptionTimeline.Word(text: "这是第一句比较长的中文字幕内容", start: 0, end: 3),
                     CaptionTimeline.Word(text: "这是第二句比较长的中文字幕内容", start: 3.1, end: 6)]
        let captions = CaptionTimeline.segments(from: words, maxWords: 7)
        XCTAssertEqual(captions.count, 2)
        XCTAssertEqual(captions[1].startTime, 3.1)
    }

    @MainActor func testNativeWaveAndOnePointFiveExportRetainTimingAndPitch() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try await RecordingMediaFixture.mixedMovie(in: folder)
        let asset = AVURLAsset(url: source)
        let wave = folder.appendingPathComponent("source.wav")
        try StudioWhisper.writeWave(asset: asset, to: wave, sampleRate: 48000, channels: 2)
        let input = try AVAudioFile(forReading: wave)
        XCTAssertEqual(input.processingFormat.channelCount, 2)
        XCTAssertEqual(Double(input.length) / input.processingFormat.sampleRate, 2, accuracy: 0.06)
        let pieces = [VideoSpeeds.Piece(kind: .speed, srcStart: 0, srcEnd: 2, compositionDuration: 2 / 1.5)]
        let built = try VideoCompositionBuilder.build(asset: asset, pieces: pieces, includeAudio: true)
        let session = try XCTUnwrap(AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetHighestQuality))
        session.outputURL = folder.appendingPathComponent("fast.mp4"); session.outputFileType = .mp4
        session.audioMix = StudioAudio.pitchMix(built.audioTracks)
        await session.export()
        XCTAssertEqual(session.status, .completed, String(describing: session.error))
        let fast = AVURLAsset(url: session.outputURL!)
        let video = try XCTUnwrap(fast.tracks(withMediaType: .video).first)
        XCTAssertEqual(video.timeRange.duration.seconds, 2 / 1.5, accuracy: 1 / 30.0)
        // AVAssetExportSession's spectral audio encoder can retain a few AAC
        // padding packets in the container. Check picture timing separately,
        // and bound the extra audio tail rather than mistaking it for slow video.
        XCTAssertLessThanOrEqual(fast.duration.seconds, 2 / 1.5 + 5 * 1024 / 48000.0 + 1 / 30.0)
        let result = folder.appendingPathComponent("fast.wav")
        try StudioWhisper.writeWave(asset: fast, to: result, sampleRate: 48000, channels: 1)
        let file = try AVAudioFile(forReading: result)
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: pcm)
        let samples = try XCTUnwrap(pcm.floatChannelData?[0])
        func magnitude(_ frequency: Double) -> Double {
            var real = 0.0, imaginary = 0.0
            let count = min(Int(pcm.frameLength), 48000)
            for n in 4800..<count {
                let phase = 2 * Double.pi * frequency * Double(n) / 48000
                real += Double(samples[n]) * cos(phase); imaginary += Double(samples[n]) * sin(phase)
            }
            return hypot(real, imaginary)
        }
        XCTAssertGreaterThan(magnitude(440), magnitude(660) * 3, "1.5× must keep a 440Hz voice tone at 440Hz")
    }
    func testAutomaticBalanceProducesPlayableAudio() async throws {
        let binary = URL(fileURLWithPath: "/Applications/Macshot Studio.app/Contents/Resources/studio-ffmpeg")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw XCTSkip("Local integration FFmpeg not installed") }
        let d = UserDefaults.standard
        let oldFlag = d.object(forKey: "studioAutoBalance"), oldPath = d.object(forKey: "studioFFmpegPath")
        d.set(true, forKey: "studioAutoBalance"); d.set(binary.path, forKey: "studioFFmpegPath")
        defer { if let oldFlag { d.set(oldFlag, forKey: "studioAutoBalance") } else { d.removeObject(forKey: "studioAutoBalance") }; if let oldPath { d.set(oldPath, forKey: "studioFFmpegPath") } else { d.removeObject(forKey: "studioFFmpegPath") } }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try await RecordingMediaFixture.mixedMovie(in: folder)
        let result = folder.appendingPathComponent("balanced.mp4")
        try await StudioAudio.mix(source: source, destination: result, volumes: [1, 1])
        try await StudioAudio.balance(result)
        let asset = AVURLAsset(url: result)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audioTracks.count, 1)
        let wave = folder.appendingPathComponent("result.wav")
        try StudioWhisper.writeWave(asset: asset, to: wave, sampleRate: 48000, channels: 2)
        let file = try AVAudioFile(forReading: wave)
        XCTAssertGreaterThan(file.length, 80000)
        XCTAssertEqual(asset.duration.seconds, 2, accuracy: 0.08)
    }
    func testCancellingLocalProcessStopsItPromptly() async throws {
        let task = Task { try await StudioProcess.run(URL(fileURLWithPath: "/bin/sleep"), ["20"]) }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must not succeed") }
        catch is CancellationError {} 
        catch { XCTFail("Expected CancellationError, got \(error)") }
    }
}
