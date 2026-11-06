import Foundation

/// 时间线的缩放（产品主人 2026-11-06：「能够自适应放大和缩小，类似苹果日历」）：双指捏合改一小时多高，
/// 手指下面那一刻留在原地；记住上次的大小。缩得越小越简略（一屏看完一整天：钟点隔两个钟头写一个，小标签、日程只留名字），
/// 放得越大越细（画出半点的刻度，好排到准点）——和 iOS 18 日历的月视图一样：越小越简略、越大越详细
enum TimelineZoom {
    /// 一小时最矮、最高（最矮时醒着的十六七个钟头一屏放得下；最高时一刻钟比小标签还高）
    static let range: ClosedRange<Double> = 24...140
    /// 没缩放过
    static let standard: Double = 46
    /// 存在这台手机上的键（上次缩放到多大）
    static let key = "todos.timeline.hour"

    enum Density: Equatable {
        /// 一屏看完一整天：钟点隔两个钟头写一个，小标签、日程只留名字
        case compact
        case regular
        /// 放大了：半点也画一条线、写钟点
        case detailed
    }

    static func density(_ hour: Double) -> Density {
        if hour < 34 { return .compact }
        return hour >= 92 ? .detailed : .regular
    }

    static func clamp(_ hour: Double) -> Double { min(max(hour, range.lowerBound), range.upperBound) }

    /// 缩放开始时记下的：一小时多高、手指下面离时间线顶上第几分钟、那时待办页滚到哪
    struct Pinch: Equatable {
        let hour: Double
        let minute: Double
        let offset: CGFloat
    }

    /// 缩放时滚到哪：手指下面那一刻的高度变了多少，就往下滚多少（它在屏幕上的位置不动）
    static func offset(_ pinch: Pinch, hour: Double) -> CGFloat {
        max(0, pinch.offset + CGFloat(pinch.minute / 60 * (hour - pinch.hour)))
    }
}

/// 待办页现在滚到哪（缩放时用）：滚动时每一帧都在变，放在不触发重画的盒子里
@MainActor
final class ScrollOffset {
    var y: CGFloat = 0
}
