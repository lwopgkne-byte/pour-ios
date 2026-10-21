#if DEBUG
    import Foundation
    import PourPlatform

    /// 界面测试用的听写（启动参数 -uiTest）：不开麦克风，假装听到「早上跑了五公里」——一边说一边出字（先是还没定下来的），
    /// 声波起伏；说完了返回整句
    actor FakeVoice: VoiceInput {
        static let sentence = "早上跑了五公里"
        private var events: AsyncStream<VoiceEvent>.Continuation?
        private var speaking: Task<Void, Never>?

        func start() async throws -> AsyncStream<VoiceEvent> {
            let (stream, events) = AsyncStream<VoiceEvent>.makeStream()
            self.events = events
            speaking = Task { await speak(events) }
            return stream
        }

        func stop() async -> String {
            speaking?.cancel()
            events?.finish()
            events = nil
            return Self.sentence
        }

        func cancel() async {
            speaking?.cancel()
            events?.finish()
            events = nil
        }

        private func speak(_ events: AsyncStream<VoiceEvent>.Continuation) async {
            events.yield(.listening)
            let parts = ["早上", "早上跑了", Self.sentence]
            for (index, part) in parts.enumerated() {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                for level in [0.3, 0.8, 0.5, 0.9, 0.4] { events.yield(.level(level)) }
                let done = index == parts.count - 1
                events.yield(.text(final: done ? part : "", volatile: done ? "" : part))
            }
        }
    }
#endif
