import Foundation
import Testing

@testable import PourPlatform

@Suite("待办的提醒")
struct RemindersTests {
    @Test func localClockBecomesCalendarParts() {
        let parts = Reminders.components("2026-10-19T10:35")
        #expect(parts == DateComponents(year: 2026, month: 10, day: 19, hour: 10, minute: 35))
        #expect(Reminders.components("10:35") == nil)
    }
}
