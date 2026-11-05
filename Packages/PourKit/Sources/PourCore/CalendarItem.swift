/// 日历里的一件事（docs/模块/产品优化.md R6）：只在这台手机上用，不送到电脑上的 Pour
public struct CalendarItem: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    /// 本地时刻「2026-10-26T15:00」；全天的是那天的 00:00
    public let start: LocalDateTime
    public let end: LocalDateTime
    /// 全天的（节假日、生日）
    public let allDay: Bool
    /// 哪个日历（「工作」「生日」「中国节假日」）
    public let calendar: String
    /// 那个日历的颜色（0xRRGGBB，系统日历里设的）；演示数据没有
    public let color: UInt32?

    public init(
        id: String, title: String, start: LocalDateTime, end: LocalDateTime, allDay: Bool, calendar: String,
        color: UInt32? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.calendar = calendar
        self.color = color
    }
}
