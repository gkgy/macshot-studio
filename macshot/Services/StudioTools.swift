import AppKit
import AVFoundation

/// Local Studio preferences. The official application's defaults are never modified.
nonisolated enum StudioPreferences {
    static var autoBalance: Bool { UserDefaults.standard.object(forKey: "studioAutoBalance") as? Bool ?? false }
    static var pythonPath: String {
        if let configured = UserDefaults.standard.string(forKey: "studioWhisperPython"), !configured.isEmpty { return configured }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let standard = home.appendingPathComponent(".local/share/macshot-studio/whisper-venv/bin/python").path
        let legacy = home.appendingPathComponent("Documents/moxingdeep/video-tools/venv/bin/python").path
        return FileManager.default.isExecutableFile(atPath: standard) ? standard :
            (FileManager.default.isExecutableFile(atPath: legacy) ? legacy : standard)
    }
    static var modelPath: String { UserDefaults.standard.string(forKey: "studioWhisperModel") ?? "" }
    static var backgroundPath: String { UserDefaults.standard.string(forKey: "studioBackgroundPath") ?? "" }
    static var ffmpeg: URL {
        if let path = UserDefaults.standard.string(forKey: "studioFFmpegPath") { return URL(fileURLWithPath: path) }
        return Bundle.main.resourceURL!.appendingPathComponent("studio-ffmpeg")
    }
    static let audioFilter = "dynaudnorm=f=250:g=9:p=0.85:m=10:r=0.08:t=0.003,alimiter=limit=0.8414:level=0:latency=1"
    @MainActor static func register() {
        UserDefaults.standard.register(defaults: ["studioAutoBalance": true, "recordMicAudio": true, "recordSystemAudio": true, "recordWebcam": true, "automaticallyCheckForUpdates": false])
    }
}

nonisolated enum StudioProcess {
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false
        func start(_ p: Process) throws {
            lock.lock(); defer { lock.unlock() }
            if cancelled { throw CancellationError() }
            process = p; try p.run()
        }
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
        func cancel() {
            lock.lock(); defer { lock.unlock() }; cancelled = true
            if let process, process.isRunning { process.terminate() }
        }
    }
    struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }
    static func run(_ executable: URL, _ arguments: [String]) async throws -> Data {
        let state = State()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-process-\(UUID().uuidString)")
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        defer { try? FileManager.default.removeItem(at: folder) }
                        let stdout = folder.appendingPathComponent("stdout"), stderr = folder.appendingPathComponent("stderr")
                        FileManager.default.createFile(atPath: stdout.path, contents: nil)
                        FileManager.default.createFile(atPath: stderr.path, contents: nil)
                        let out = try FileHandle(forWritingTo: stdout), err = try FileHandle(forWritingTo: stderr)
                        defer { try? out.close(); try? err.close() }
                        let p = Process(); p.executableURL = executable; p.arguments = arguments
                        p.standardOutput = out; p.standardError = err; p.standardInput = FileHandle.nullDevice
                        p.environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("DYLD_") }
                        try state.start(p); p.waitUntilExit()
                        if state.isCancelled { throw CancellationError() }
                        guard p.terminationStatus == 0 else {
                            let detail = (try? String(contentsOf: stderr, encoding: .utf8)) ?? ""
                            throw Failure(message: "本地处理失败（\(p.terminationStatus)）：\(detail.suffix(1200))")
                        }
                        continuation.resume(returning: try Data(contentsOf: stdout))
                    } catch { continuation.resume(throwing: error) }
                }
            }
            try Task.checkCancellation(); return data
        }, onCancel: { state.cancel() })
    }
}

nonisolated enum StudioAudio {
    @MainActor static func pitchMix(_ tracks: [AVAssetTrack]) -> AVAudioMix {
        let mix = AVMutableAudioMix()
        mix.inputParameters = tracks.map { track in
            let p = AVMutableAudioMixInputParameters(track: track)
            p.audioTimePitchAlgorithm = .spectral
            return p
        }
        return mix
    }
    static func decode(_ asset: AVAsset, tracks: [AVAssetTrack], to url: URL) async throws {
        nonisolated(unsafe) let source = asset
        nonisolated(unsafe) let selected = tracks
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do { try StudioWhisper.writeWave(asset: source, to: url, sampleRate: 48000, channels: 2, selectedTracks: selected); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
        try Task.checkCancellation()
    }
    static func balance(_ url: URL) async throws {
        guard StudioPreferences.autoBalance else { return }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { return }
        let wave = FileManager.default.temporaryDirectory.appendingPathComponent("studio-audio-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wave) }
        try await decode(asset, tracks: tracks, to: wave)
        let save = try AtomicMediaSave(destinationURL: url)
        _ = try await StudioProcess.run(StudioPreferences.ffmpeg, ["-nostdin", "-hide_banner", "-loglevel", "error", "-i", url.path, "-i", wave.path, "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-af", StudioPreferences.audioFilter, "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", save.stagingURL.path])
        try Task.checkCancellation(); try save.commit(overwritingExisting: true)
    }
    static func mix(source: URL, destination: URL, volumes: [Float]) async throws {
        let asset = AVURLAsset(url: source)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard volumes.count >= 2, tracks.count == volumes.count, volumes.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { throw StudioProcess.Failure(message: "音轨或音量无效") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-mix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let save = try AtomicMediaSave(destinationURL: destination)
        var args = ["-nostdin", "-hide_banner", "-loglevel", "error", "-i", source.path]
        var filter = ""
        for (i, v) in volumes.enumerated() {
            let wave = folder.appendingPathComponent("track-\(i).wav")
            try await decode(asset, tracks: [tracks[i]], to: wave)
            args += ["-i", wave.path]
            filter += "[\(i+1):a:0]\(StudioPreferences.audioFilter),volume=\(v)[a\(i)];"
        }
        filter += volumes.indices.map { "[a\($0)]" }.joined() + "amix=inputs=\(volumes.count):normalize=0:duration=longest,alimiter=limit=0.8414:level=0:latency=1[a]"
        args += ["-filter_complex", filter, "-map", "0:v:0", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", save.stagingURL.path]
        _ = try await StudioProcess.run(StudioPreferences.ffmpeg, args)
        try Task.checkCancellation(); try save.commit(overwritingExisting: false)
    }

}

@MainActor final class StudioSettingsWindow: NSWindowController {
    static let shared = StudioSettingsWindow()
    private let balance = NSButton(checkboxWithTitle: "导出与混音时自动平衡音量（本机处理）", target: nil, action: nil)
    private let python = NSTextField(), model = NSTextField(), background = NSTextField()
    init() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 450), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "Macshot Studio · 定制功能"; win.center(); win.isReleasedWhenClosed = false
        super.init(window: win)
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        win.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: win.contentView!.leadingAnchor, constant: 22), stack.trailingAnchor.constraint(equalTo: win.contentView!.trailingAnchor, constant: -22), stack.topAnchor.constraint(equalTo: win.contentView!.topAnchor, constant: 20)])
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "本地 Whisper 字幕 · 科技背景人像分割 · 默认 10% 头像\n整段变速：编辑器「添加 → 整段变速」，声音保持原音高。"))
        balance.state = StudioPreferences.autoBalance ? .on : .off; stack.addArrangedSubview(balance)
        for (title, field, value) in [("Whisper Python 路径", python, StudioPreferences.pythonPath), ("本地模型文件夹（空白则使用已缓存 large-v3-turbo）", model, StudioPreferences.modelPath), ("科技背景图片路径（空白则使用内置背景）", background, StudioPreferences.backgroundPath)] {
            stack.addArrangedSubview(NSTextField(labelWithString: title)); field.stringValue = value; stack.addArrangedSubview(field)
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        let save = NSButton(title: "保存设置", target: self, action: #selector(saveSettings)); save.bezelStyle = .rounded; stack.addArrangedSubview(save)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func saveSettings() {
        let d = UserDefaults.standard
        d.set(balance.state == .on, forKey: "studioAutoBalance"); d.set(python.stringValue, forKey: "studioWhisperPython")
        d.set(model.stringValue, forKey: "studioWhisperModel"); d.set(background.stringValue, forKey: "studioBackgroundPath")
        window?.close()
    }
    @objc static func openSettings() { shared.showWindow(nil); NSApp.activate(ignoringOtherApps: true) }
}
