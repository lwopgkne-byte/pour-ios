import Foundation
import Testing

@testable import PourPlatform

/// 说话转字的拼法、声波的高低（产品主人 2026-10-26）
@Suite("说话：拼字、声波")
struct VoiceTests {
    typealias Piece = VoiceTranscript.Piece

    /// 截图里的毛病：同一段声音定了两次稿（第二次带问号），以前两次都接上去
    @Test func sameSpeechFinalizedTwiceIsNotRepeated() {
        var transcript = VoiceTranscript()
        transcript.add(Piece(start: 0, end: 2, text: "今天的待办有哪些"), isFinal: true)
        transcript.add(Piece(start: 0, end: 2.4, text: "今天的待办有哪些？"), isFinal: true)
        #expect(transcript.text == "今天的待办有哪些？")
    }

    /// 定了稿以后，系统又对同一段声音给了一个还没定下来的新说法：以新的为准，不接在后面
    @Test func revisedVolatileReplacesTheSettledPart() {
        var transcript = VoiceTranscript()
        transcript.add(Piece(start: 0, end: 2, text: "今天的待办有哪些"), isFinal: true)
        transcript.add(Piece(start: 0, end: 2.4, text: "今天的待办有哪些？"), isFinal: false)
        #expect(transcript.text == "今天的待办有哪些？")
    }

    @Test func piecesFollowEachOther() {
        var transcript = VoiceTranscript()
        transcript.add(Piece(start: 0, end: 1, text: "早上"), isFinal: false)
        #expect(transcript.text == "早上")
        transcript.add(Piece(start: 0, end: 1.5, text: "早上跑了"), isFinal: true)
        transcript.add(Piece(start: 1.5, end: 2.6, text: "五公里"), isFinal: false)
        #expect(transcript.settled == "早上跑了")
        #expect(transcript.volatile == "五公里")
        transcript.add(Piece(start: 1.5, end: 2.8, text: "五公里。"), isFinal: true)
        #expect(transcript.text == "早上跑了五公里。")
    }

    /// 前后两段擦个边（时间算得有一点点重叠）：两段都留着
    @Test func touchingPiecesBothStay() {
        var transcript = VoiceTranscript()
        transcript.add(Piece(start: 0, end: 2, text: "跑了五公里"), isFinal: true)
        transcript.add(Piece(start: 1.9, end: 4, text: "吃了碗面"), isFinal: true)
        #expect(transcript.text == "跑了五公里吃了碗面")
    }

    /// 一句话的最后补上一个问号（时间很短）
    @Test func punctuationTailIsKept() {
        var transcript = VoiceTranscript()
        transcript.add(Piece(start: 0, end: 2, text: "今天的提醒有哪些"), isFinal: true)
        transcript.add(Piece(start: 2, end: 2, text: "？"), isFinal: true)
        #expect(transcript.text == "今天的提醒有哪些？")
    }

    /// 安静：平的；开口说话：立起来；说完：慢慢落回去
    @Test func levelRisesWithSpeechAndFallsSlowly() {
        var meter = LevelMeter()
        for _ in 0..<20 { _ = meter.next(rms: 0.002) }
        let quiet = meter.next(rms: 0.002)
        #expect(quiet < 0.05)
        var loud = 0.0
        for _ in 0..<5 { loud = meter.next(rms: 0.08) }
        #expect(loud > 0.7)
        let after = meter.next(rms: 0.002)
        #expect(after < loud && after > 0.3, "说完不该一下子掉到底")
    }

    /// 一直很吵（街上）：底噪跟上去，没说话时声波还是平的
    @Test func steadyNoiseFlattensOut() {
        var meter = LevelMeter()
        var level = 1.0
        for _ in 0..<3000 { level = meter.next(rms: 0.02) }
        #expect(level < 0.2)
    }
}
