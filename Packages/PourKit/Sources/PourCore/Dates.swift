public import Foundation

/// 日子：YYYY-MM-DD，按日界线算的那一天（凌晨 4 点前说的话算前一天）
public typealias DayString = String

/// 本地时刻：YYYY-MM-DDTHH:mm，说这句话的地方墙上的钟点，不带时区（和网关的接口契约一致）
public typealias LocalDateTime = String

/// 日历上的加减（和网页版 shared/src/date.ts 对拍：fixtures/golden/date.json）。
/// 一律当成 UTC 的零点算——只做日历换算，碰不到夏令时；「现在几点、属于哪一天」由 `logicalDay` 按手机的时区算
public enum PourDate {
    /// 日界线默认凌晨 4:00（当日 240 分钟）：这之前说的话算前一天
    public static let defaultBoundary = 240

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// "2026-10-18" → 那天 UTC 零点；格式不对返回 nil
    private static func utcDate(_ day: DayString) -> Date? {
        let parts = day.split(separator: "-")
        guard day.count == 10, parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]),
            let date = Int(parts[2])
        else { return nil }
        return utc.date(from: DateComponents(year: year, month: month, day: date))
    }

    private static func dayString(_ date: Date) -> DayString {
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 是不是真实存在的一天（"2026-02-29" 不是）
    public static func isValid(_ day: String) -> Bool {
        guard day.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil, let date = utcDate(day) else { return false }
        return dayString(date) == day
    }

    public static func addDays(_ day: DayString, _ days: Int) -> DayString {
        guard let date = utcDate(day) else { return day }
        return dayString(date.addingTimeInterval(TimeInterval(days) * 86_400))
    }

    /// lhs - rhs，单位天
    public static func diffDays(_ lhs: DayString, _ rhs: DayString) -> Int {
        guard let left = utcDate(lhs), let right = utcDate(rhs) else { return 0 }
        return Int((left.timeIntervalSince(right) / 86_400).rounded())
    }

    /// 0 = 周一 … 6 = 周日
    public static func weekdayMon0(_ day: DayString) -> Int {
        guard let date = utcDate(day) else { return 0 }
        return (utc.component(.weekday, from: date) + 5) % 7
    }

    /// 一个时刻在某个时区里墙上的钟点
    public static func localDateTime(_ date: Date, in timeZone: TimeZone) -> LocalDateTime {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04d-%02d-%02dT%02d:%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0,
            parts.minute ?? 0)
    }

    /// 一个本地时刻属于哪一天：早于日界线的算前一天
    public static func logicalDay(of local: LocalDateTime, boundary: Int = defaultBoundary) -> DayString {
        let day = String(local.prefix(10))
        guard let minutes = minutesOfDay(local) else { return day }
        return minutes < boundary ? addDays(day, -1) : day
    }

    /// 一个时刻在某个时区里属于哪一天
    public static func logicalDay(_ date: Date, in timeZone: TimeZone, boundary: Int = defaultBoundary) -> DayString {
        logicalDay(of: localDateTime(date, in: timeZone), boundary: boundary)
    }

    /// "2026-10-18T07:05" → 425（当日分钟数）
    public static func minutesOfDay(_ local: LocalDateTime) -> Int? {
        let clock = local.split(separator: "T").last.map(String.init) ?? ""
        return parseTime(clock)
    }

    /// "HH:mm" 或 "H:mm" → 当日分钟数；不合法返回 nil（和网页版 parseTime 对拍）
    public static func parseTime(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.wholeMatch(of: /(\d{1,2}):(\d{2})/), let hour = Int(match.1),
            let minute = Int(match.2), (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    /// 当日分钟数 → "HH:mm"（对 1440 取模，跨零点的溢出值也行；和网页版 formatTime 对拍）
    public static func formatTime(_ minutes: Double) -> String {
        let rounded = Int(jsRound(minutes))
        let wrapped = ((rounded % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
    }
}
