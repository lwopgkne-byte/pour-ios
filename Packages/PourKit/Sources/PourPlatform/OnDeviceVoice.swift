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
        /// 说到现在的字（按录音时间拼，同一段识别两遍不会重复）
        private var transcript = VoiceTranscript()
        /// 来电话、换耳机这些打断：听着的时候才盯着
        private var observers: [NSObjectProtocol] = []

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
            transcript = VoiceTranscript()
            reading = Task { await self.read(transcriber) }
            let engine = try Self.listen(into: feed, format: format, events: events)
            self.engine = engine
            watchInterruptions(engine)
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
            return transcript.text
        }

        public func cancel() async {
            closeMicrophone()
            await analyzer?.cancelAndFinishNow()
            analyzer = nil
            reading?.cancel()
            reading = nil
            events?.finish()
            events = nil
            transcript = VoiceTranscript()
        }

        /// 关麦克风、不再送声音进去
        private func closeMicrophone() {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers = []
            engine?.inputNode.removeTap(onBus: 0)
            engine?.stop()
            engine = nil
            feed?.finish()
            feed = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        /// 收字：按录音时间拼（同一段声音识别两遍、定两次稿，后来的换掉先来的）
        private func read(_ transcriber: SpeechTranscriber) async {
            do {
                for try await result in transcriber.results {
                    let piece = VoiceTranscript.Piece(
                        start: result.range.start.seconds, end: result.range.end.seconds,
                        text: String(result.text.characters))
                    transcript.add(piece, isFinal: result.isFinal)
                    events?.yield(.text(final: transcript.settled, volatile: transcript.volatile))
                }
            } catch {
                events?.yield(.failed(.other(error.localizedDescription)))
            }
        }

        /// 来电话、闹钟、Siri（系统打断录音），插拔耳机（录音的设备换了，引擎停了）：关麦克风，告诉界面
        private func watchInterruptions(_ engine: AVAudioEngine) {
            let began: @Sendable (Notification) -> Void = { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw.flatMap(AVAudioSession.InterruptionType.init) == .began else { return }
                Task { await self?.interrupted() }
            }
            let changed: @Sendable (Notification) -> Void = { [weak self] _ in Task { await self?.interrupted() } }
            let center = NotificationCenter.default
            observers = [
                center.addObserver(
                    forName: AVAudioSession.interruptionNotification, object: nil, queue: nil, using: began),
                center.addObserver(
                    forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil, using: changed),
            ]
        }

        private func interrupted() {
            guard engine != nil else { return }
            closeMicrophone()
            events?.yield(.interrupted)
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

        /// 打开麦克风：每一小段声音换成听写要的格式送进去，顺便算音量（画声波）。
        /// 一小段 1024 个采样（大约 0.02 秒）：声波一秒动四十多次，跟得上说话
        private static func listen(
            into feed: AsyncStream<AnalyzerInput>.Continuation, format: AVAudioFormat,
            events: AsyncStream<VoiceEvent>.Continuation
        ) throws -> AVAudioEngine {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                // 打着电话、别的 App 在录音：系统不给麦克风
                throw VoiceError.micBusy
            }
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let natural = input.outputFormat(forBus: 0)
            guard let converter = SoundConverter(from: natural, to: format) else { throw VoiceError.unsupported }
            let meter = Meter()
            // iOS 27 起带出错信息的那个版本（旧的不推荐用了）：Swift 里苹果还没包好，名字前面带两个下划线；
            // 出错参数在中间，导进来变成了一个空的 `()` 占位，出错时直接抛出来
            try input.__installTap(onBus: 0, bufferSize: 1024, format: natural, error: ()) { buffer, _ in
                events.yield(.level(meter.next(buffer)))
                if let converted = converter.convert(buffer) { feed.yield(AnalyzerInput(buffer: converted)) }
            }
            engine.prepare()
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                throw VoiceError.micBusy
            }
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

    }

    /// 声波的高低：每一小段声音的均方根交给 LevelMeter（扣掉底噪、起得快落得慢）。只在录音的那个线程上用
    private final class Meter: @unchecked Sendable {
        private var meter = LevelMeter()

        func next(_ buffer: AVAudioPCMBuffer) -> Double {
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
            return meter.next(rms: Double((sum / Float(buffer.frameLength)).squareRoot()))
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
