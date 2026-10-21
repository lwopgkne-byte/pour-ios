import PourDesign
import SwiftUI
import Testing

@testable import Pour

/// 整理好了、没整理成的触感（ComposerHaptics.feedback）：只在看着的那一段变了的时候震；
/// 刚打开 App 拿到以前的记录、换成了另一段话都不震
@Suite("整理的触感")
@MainActor
struct ComposerHapticsTests {
    typealias Note = ComposerHaptics.LastNote

    @Test func finishedNoteIsASuccess() {
        let feedback = ComposerHaptics.feedback(Note(id: 7, status: "processing"), Note(id: 7, status: "done"))
        #expect(feedback == Theme.Haptics.done)
    }

    @Test func failedNoteIsAnError() {
        let feedback = ComposerHaptics.feedback(Note(id: 7, status: "pending"), Note(id: 7, status: "failed"))
        #expect(feedback == Theme.Haptics.failed)
    }

    @Test func loadingOldNotesIsQuiet() {
        #expect(ComposerHaptics.feedback(nil, Note(id: 7, status: "done")) == nil)
        #expect(ComposerHaptics.feedback(nil, Note(id: 7, status: "failed")) == nil)
    }

    @Test func anotherNoteIsQuiet() {
        #expect(ComposerHaptics.feedback(Note(id: 6, status: "done"), Note(id: 7, status: "processing")) == nil)
        #expect(ComposerHaptics.feedback(Note(id: 6, status: "processing"), Note(id: 7, status: "done")) == nil)
    }

    @Test func stillWorkingIsQuiet() {
        #expect(ComposerHaptics.feedback(Note(id: 7, status: "pending"), Note(id: 7, status: "processing")) == nil)
        #expect(ComposerHaptics.feedback(Note(id: 7, status: "processing"), Note(id: 7, status: "confirm")) == nil)
    }
}
