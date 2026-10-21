#if os(iOS)
    import AVFAudio
    public import Foundation
    import Speech

    /// 手机上的听写：系统的 SpeechAnalyzer + SpeechTranscriber（中文，一边说一边出字，还没定下来的字单独给）。
    /// 录音只在内存里转成字，不存不传；第一次用时系统下载中文的听写模型（报进度）
    public actor OnDeviceVoice: VoiceInput {
        private let locale: Locale
        private var engine: AVAudioEngine?
        private var analyzer: SpeechAnalyzer?
        private var feed: AsyncStream<AnalyzerInput>.Continuation?
        private var events: AsyncStream<VoiceEvent>.Continuation?
        private var reading: Task<Void, Never>?
        /// 已经定下来的字
        private var settled = ""
        /// 还没定下来的字（一边说一边会改）
        private var pending = ""

        public init(locale: Locale = Locale(identifier: "zh_CN")) {
            self.locale = locale
        }

        public func start() async throws -> AsyncStream<VoiceEvent> {
            await cancel()
            guard await AVAudioApplication.requestRecordPermission() else { throw VoiceError.noPermission }
            guard let language = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
                throw VoiceError.unsupported
            }
            let transcriber = SpeechTranscriber(
                locale: language, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
            let (stream, events) = AsyncStream<VoiceEvent>.makeStream()
            self.events = events
            try await Self.install(transcriber, events: events)
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw VoiceError.unsupported
            }
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let (inputs, feed) = AsyncStream<AnalyzerInput>.makeStream()
            try await analyzer.start(inputSequence: inputs)
            self.analyzer = analyzer
            self.feed = feed
            settled = ""
            pending = ""
            reading = Task { await self.read(transcriber) }
            engine = try Self.listen(into: feed, format: format, events: events)
            events.yield(.listening)
            return stream
        }

        public func stop() async -> String {
            closeMicrophone()
            try? await analyzer?.finalizeAndFinishThroughEndOfInput()
            analyzer = nil
            await reading?.value
            reading = nil
            events?.finish()
            events = nil
            return (settled + pending).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public func cancel() async {
            closeMicrophone()
            await analyzer?.cancelAndFinishNow()
            analyzer = nil
            reading?.cancel()
            reading = nil
            events?.finish()
            events = nil
            settled = ""
            pending = ""
        }

        /// 关麦克风、不再送声音进去
        private func closeMicrophone() {
            engine?.inputNode.removeTap(onBus: 0)
            engine?.stop()
            engine = nil
            feed?.finish()
            feed = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        /// 收字：定下来的接在后面，还没定下来的单独放
        private func read(_ transcriber: SpeechTranscriber) async {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        settled += text
                        pending = ""
                    } else {
                        pending = text
                    }
                    events?.yield(.text(final: settled, volatile: pending))
                }
            } catch {
                events?.yield(.failed(.other(error.localizedDescription)))
            }
        }

        /// 第一次用：下载中文的听写模型，一边下一边报进度
        private static func install(
            _ transcriber: SpeechTranscriber, events: AsyncStream<VoiceEvent>.Continuation
        ) async throws {
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                return
            }
            let progress = request.progress
            let watcher = Task {
                while !Task.isCancelled {
                    events.yield(.preparing(progress.fractionCompleted))
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            defer { watcher.cancel() }
            do {
                try await request.downloadAndInstall()
            } catch {
                throw VoiceError.downloadFailed
            }
        }

        /// 打开麦克风：每一小段声音换成听写要的格式送进去，顺便算音量（画声波）
        private static func listen(
            into feed: AsyncStream<AnalyzerInput>.Continuation, format: AVAudioFormat,
            events: AsyncStream<VoiceEvent>.Continuation
        ) throws -> AVAudioEngine {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let natural = input.outputFormat(forBus: 0)
            guard let converter = SoundConverter(from: natural, to: format) else { throw VoiceError.unsupported }
            // iOS 27 起带出错信息的那个版本（旧的不推荐用了）：Swift 里苹果还没包好，名字前面带两个下划线；
            // 出错参数在中间，导进来变成了一个空的 `()` 占位，出错时直接抛出来
            try input.__installTap(onBus: 0, bufferSize: 4096, format: natural, error: ()) { buffer, _ in
                events.yield(.level(SoundConverter.level(buffer)))
                if let converted = converter.convert(buffer) { feed.yield(AnalyzerInput(buffer: converted)) }
            }
            engine.prepare()
            try engine.start()
            return engine
        }
    }

    /// 把麦克风的声音换成听写要的格式。只在录音的那个线程上一段一段地用，不会同时用两次
    private final class SoundConverter: @unchecked Sendable {
        private let converter: AVAudioConverter
        private let target: AVAudioFormat

        init?(from source: AVAudioFormat, to target: AVAudioFormat) {
            guard let converter = AVAudioConverter(from: source, to: target) else { return nil }
            self.converter = converter
            self.target = target
        }

        func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
            let source = OneShot(buffer)
            var failure: NSError?
            converter.convert(to: output, error: &failure) { _, status in
                guard let next = source.take() else {
                    status.pointee = .noDataNow
                    return nil
                }
                status.pointee = .haveData
                return next
            }
            return failure == nil ? output : nil
        }

        /// 一段声音的音量（0–1）：均方根换成分贝，-50 分贝以下算 0
        static func level(_ buffer: AVAudioPCMBuffer) -> Double {
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
            let rms = (sum / Float(buffer.frameLength)).squareRoot()
            let decibels = 20 * log10(max(rms, 0.000_01))
            return Double(min(1, max(0, (decibels + 50) / 50)))
        }
    }

    /// 只给一次的那段声音（换格式时系统来要，给过一次就说「暂时没有了」）
    private final class OneShot: @unchecked Sendable {
        private var buffer: AVAudioPCMBuffer?

        init(_ buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }

        func take() -> AVAudioPCMBuffer? {
            defer { buffer = nil }
            return buffer
        }
    }
#endif
