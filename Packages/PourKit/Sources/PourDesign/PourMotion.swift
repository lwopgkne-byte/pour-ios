public import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// 动效令牌（docs/归档/设计规范/07-动效与触感.md 第 1 节）：动效表达因果和去向，不炫技、可打断、能关掉。
public enum PourMotion {
    /// 按下的回应
    public static let instant: Double = 0.1
    /// 小元素出现、消失、切换
    public static let fast: Double = 0.2
    /// 大多数过渡
    public static let standard: Double = 0.3
    /// 图表生长、展开
    public static let emphasized: Double = 0.45
    /// 只有「倾倒 → 凝结」
    public static let signature: Double = 0.7

    /// 快、不回弹：按下、开关、切换
    public static let snappy = Animation.snappy(duration: fast, extraBounce: 0)
    /// 稳、不回弹：绝大多数过渡、列表增删、面板
    public static let smooth = Animation.smooth(duration: standard, extraBounce: 0)
    /// 带一点点回弹：只用于收据凝结完成落定的那一下
    public static let lively = Animation.spring(duration: standard, bounce: 0.18)

    /// 按下时缩到的比例
    public static let pressedScale: CGFloat = 0.97

    /// 「减少动态效果」打开时：一律换成 0.2 秒淡入淡出（07 第 4 节）
    public static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: fast) : animation
    }
}

/// 触感（07 第 5 节）：每个有意义的结果都摸得到，一次操作最多一下，滚动时不响，跟随系统开关。
public enum PourHaptic: String, CaseIterable, Sendable {
    /// 发送
    case send
    /// 收据凝结完成
    case success
    /// 没整理成、出错
    case error
    /// 开始录音
    case recordStart
    /// 上滑取消录音
    case warning
    /// 切换、选择、拖动吸附
    case selection

    /// 画廊里的说明
    public var title: String {
        switch self {
        case .send: "发送"
        case .success: "收据凝结完成"
        case .error: "没整理成、出错"
        case .recordStart: "开始录音"
        case .warning: "上滑取消录音"
        case .selection: "切换、选择"
        }
    }

    @MainActor
    public func play() {
        #if canImport(UIKit)
            switch self {
            case .send: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .recordStart: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .selection: UISelectionFeedbackGenerator().selectionChanged()
            }
        #endif
    }
}
