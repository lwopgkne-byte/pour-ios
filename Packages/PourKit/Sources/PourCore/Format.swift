import Foundation

/// 界面上的日期、时刻、时长、金额、心情的写法（规范 10 第 3 节）：全部从这里出，界面不自己拼
public enum PourFormat {
    public static let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    public static let moodWords = ["很差", "不太好", "一般", "挺好", "很好"]
    public static let energyWords = ["很累", "有点累", "一般", "有精神", "精力充沛"]

    /// "2026-10-18T07:05" → "07:05"（24 小时制、两位）
    public static func clock(_ local: LocalDateTime) -> String {
        guard let minutes = PourDate.minutesOfDay(local) else { return "" }
        return PourDate.formatTime(Double(minutes))
    }

    /// 「45 分钟」「1 小时 20 分」「2 小时」
    public static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分"
    }

    /// 「¥28」「¥28.50」「¥12,800」
    public static func money(_ value: Double) -> String {
        let isWhole = value.rounded() == value
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = isWhole ? 0 : 2
        formatter.maximumFractionDigits = isWhole ? 0 : 2
        return "¥" + (formatter.string(from: NSNumber(value: value)) ?? "\(value)")
    }

    /// 不是钱的数：「5」「2.5」（最多两位小数，去掉末尾的 0）
    public static func amount(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 { return String(Int(value)) }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// 日子的大标题：「今天」「昨天」「明天」（待办的期限）；今年的「10月14日」；往年的「2025年10月14日」
    /// 提醒的时刻：今天的只写钟点（「10:35」），别的日子带上哪天（「明天 08:00」「10月21日 15:00」）
    public static func remindAt(_ time: LocalDateTime, today: DayString) -> String {
        let day = String(time.prefix(10))
        return day == today ? clock(time) : "\(dayTitle(day, today: today)) \(clock(time))"
    }

    public static func dayTitle(_ day: DayString, today: DayString) -> String {
        switch PourDate.diffDays(day, today) {
        case 0: return "今天"
        case -1: return "昨天"
        case 1: return "明天"
        default: return monthDay(day, today: today)
        }
    }

    /// 「10月14日」；不在今年的带上年份
    public static func monthDay(_ day: DayString, today: DayString) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return day }
        let year = day.prefix(4) == today.prefix(4) ? "" : "\(parts[0])年"
        return "\(year)\(parts[1])月\(parts[2])日"
    }

    /// 「周六」
    public static func weekday(_ day: DayString) -> String { weekdays[PourDate.weekdayMon0(day)] }

    public static func moodWord(_ level: Int) -> String { moodWords[min(max(level, 1), 5) - 1] }
    public static func energyWord(_ level: Int) -> String { energyWords[min(max(level, 1), 5) - 1] }
}

extension Metric {
    /// 网页版 tidy.ts 的 isMoney：单位是元、块钱……；「块」既是钱又是量词，名字也说的是钱才算
    public var isMoney: Bool {
        let unit = self.unit.trimmingCharacters(in: .whitespaces)
        if ["元", "块钱", "¥", "￥", "人民币", "rmb", "RMB"].contains(unit) { return true }
        guard unit == "块" else { return false }
        let name = self.name.replacing(/\s/, with: "")
        let moneyNames = ["收入", "进账", "工资", "花费", "花了", "消费", "支出", "费用", "价格", "金额", "钱", "价", "账"]
        return moneyNames.contains { name.contains($0) } || name.hasSuffix("费")
    }

    /// 钱一律「¥32」（有名目带上名目「菜 ¥860」），别的「5 公里」
    public var display: String {
        if isMoney { return (item.map { "\($0) " } ?? "") + PourFormat.money(value) }
        return "\(PourFormat.amount(value)) \(unit)".trimmingCharacters(in: .whitespaces)
    }
}
