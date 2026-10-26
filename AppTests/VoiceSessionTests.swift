import Foundation
import PourPlatform
import Testing

@testable import Pour

/// 说一次话（VoiceSession）：用假的听写走一遍——一边说一边出字、说完拿到整句；✕ 什么都不留；
/// 没听到字说「没听清」；麦克风没开说去设置里打开
@Suite("说一次话")
@MainActor
struct VoiceSessionTests {
    @Test func listensAndFinishes() async throws {
        let session = VoiceSession(input: FakeVoice())
        session.start(.tap)
        #expect(session.active)
        try await until { session.text == FakeVoice.sentence }
        #expect(session.phase == .listening)
        #expect(session.levels.contains { $0 > 0 })
        let words = await session.finish()
        #expect(words == FakeVoice.sentence)
        #expect(session.phase == .idle)
        #expect(session.text.isEmpty)
    }

    @Test func cancelLeavesNothing() async throws {
        let session = VoiceSession(input: FakeVoice())
        session.start(.hold)
        try await until { session.phase == .listening }
        session.cancel()
        #expect(session.phase == .idle)
        #expect(session.text.isEmpty)
        #expect(!session.active)
    }

    @Test func nothingHeard() async throws {
        let session = VoiceSession(input: Silent())
        session.start(.tap)
        try await until { session.phase == .listening }
        let words = await session.finish()
        #expect(words == nil)
        #expect(session.phase == .failed("没听清，再说一次", settings: false))
    }

    @Test func noMicrophone() async throws {
        let session = VoiceSession(input: Denied())
        session.start(.tap)
        try await until { !session.active }
        #expect(session.phase == .failed(VoiceError.noPermission.message, settings: true))
    }

    /// 被打断了（来电话、换耳机）：交给外面收尾，说到的字还在；什么都没说就安静地收起，不说「没听清」
    @Test func interruptionKeepsTheWords() async throws {
        let session = VoiceSession(input: Interrupted(words: "跑了五公里"))
        var handed = false
        session.onInterrupted = { handed = true }
        session.start(.tap)
        try await until { handed }
        #expect(await session.finish(quiet: true) == "跑了五公里")
        #expect(session.phase == .idle)

        let quiet = VoiceSession(input: Interrupted(words: ""))
        quiet.onInterrupted = { handed = true }
        quiet.start(.hold)
        try await until { quiet.phase == .listening }
        #expect(await quiet.finish(quiet: true) == nil)
        #expect(quiet.phase == .idle)
    }

    /// 提示：开始 4 秒还没听到声音；说过话以后停了 5 秒（点一下说的才提示可以发了）
    @Test func hints() {
        let start = Date()
        let spoke = start.addingTimeInterval(1)
        #expect(
            VoiceSession.hint(startedAt: start, lastVoice: nil, now: start.addingTimeInterval(2), mode: .tap) == nil)
        #expect(
            VoiceSession.hint(startedAt: start, lastVoice: nil, now: start.addingTimeInterval(5), mode: .hold)
                == "没听到声音，靠近手机说")
        #expect(
            VoiceSession.hint(startedAt: start, lastVoice: spoke, now: spoke.addingTimeInterval(3), mode: .tap) == nil)
        #expect(
            VoiceSession.hint(startedAt: start, lastVoice: spoke, now: spoke.addingTimeInterval(6), mode: .tap)?
                .hasPrefix("说完了") == true)
        #expect(
            VoiceSession.hint(startedAt: start, lastVoice: spoke, now: spoke.addingTimeInterval(6), mode: .hold) == nil)
    }

    /// 等到条件成立（最多两秒）
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(condition())
    }
}

/// 开始听了但什么都没听到
private actor Silent: VoiceInput {
    private var events: AsyncStream<VoiceEvent>.Continuation?

    func start() async throws -> AsyncStream<VoiceEvent> {
        let (stream, events) = AsyncStream<VoiceEvent>.makeStream()
        self.events = events
        events.yield(.listening)
        return stream
    }

    func stop() async -> String {
        events?.finish()
        return ""
    }

    func cancel() async { events?.finish() }
}

/// 麦克风没开
private struct Denied: VoiceInput {
    func start() async throws -> AsyncStream<VoiceEvent> { throw VoiceError.noPermission }
    func stop() async -> String { "" }
    func cancel() async {}
}

/// 说了几个字以后被打断（来电话）：麦克风关了，字还在
private actor Interrupted: VoiceInput {
    let words: String
    private var events: AsyncStream<VoiceEvent>.Continuation?

    init(words: String) {
        self.words = words
    }

    func start() async throws -> AsyncStream<VoiceEvent> {
        let (stream, events) = AsyncStream<VoiceEvent>.makeStream()
        self.events = events
        events.yield(.listening)
        if !words.isEmpty { events.yield(.text(final: words, volatile: "")) }
        events.yield(.interrupted)
        return stream
    }

    func stop() async -> String {
        events?.finish()
        return words
    }

    func cancel() async { events?.finish() }
}
