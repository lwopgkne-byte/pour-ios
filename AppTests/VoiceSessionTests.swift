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
