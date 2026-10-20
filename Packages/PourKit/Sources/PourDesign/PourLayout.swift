public import CoreGraphics
public import SwiftUI

/// 间距令牌（docs/归档/设计规范/05-布局与间距.md 第 1 节）。基数 4 点；代码里只用这些名字。
public enum PourSpace {
    /// 图标和文字之间（SF Symbols 和文字的标准间距）
    public static let inline: CGFloat = 6
    /// 标题和它的副标题之间
    public static let tight: CGFloat = 4
    /// 一组里相关的元素之间
    public static let related: CGFloat = 8
    /// 卡片和卡片之间、列表组之间
    public static let element: CGFloat = 12
    /// 卡片内边距
    public static let card: CGFloat = 16
    /// 一节里的两组之间
    public static let group: CGFloat = 24
    /// 节和节之间
    public static let section: CGFloat = 32
    /// 标签页最后一段内容到底部浮动栏之间：浮动的玻璃栏往上有一段投影（亮色约 24 点、暗色约 36 点），
    /// 最后一条要完整地停在投影以外，看着也不贴着栏（M1 自验收，规范 05）
    public static let pageEnd: CGFloat = 64

    /// 屏幕左右边距：屏宽 ≤ 375 点用 16，其余 20
    public static func page(forWidth width: CGFloat) -> CGFloat { width <= 375 ? 16 : 20 }
}

/// 尺寸令牌（05 第 2 节、04 第 1、3 节）
public enum PourSize {
    /// 最小可点范围
    public static let minTap: CGFloat = 44
    public static let rowSingle: CGFloat = 52
    public static let rowDouble: CGFloat = 64
    public static let buttonLarge: CGFloat = 50
    public static let buttonRegular: CGFloat = 44
    public static let buttonSmall: CGFloat = 32
    public static let pourBarCollapsed: CGFloat = 52
    public static let chipVisual: CGFloat = 32
    public static let chipInfo: CGFloat = 28
    public static let aiBadge: CGFloat = 18
    public static let domainDot: CGFloat = 8
    public static let timelineDot: CGFloat = 10
    public static let moodCellCalendar: CGFloat = 32
    public static let moodPixel: CGFloat = 14
    public static let moodPixelGap: CGFloat = 3
    public static let progressBar: CGFloat = 6
    public static let timelineTimeColumn: CGFloat = 52
    public static let sendButton: CGFloat = 32
    public static let avatarInline: CGFloat = 24
    public static let avatarList: CGFloat = 32
    public static let avatarDetail: CGFloat = 44
    public static let miniChartHeight: CGFloat = 40
    /// 列表分割线从文字起点开始：卡片内边距 16 + 图标位 28 + 间距 12（规范 05 第 6 节）
    public static let listDividerInset: CGFloat = 56
    /// 内容最大宽度（iPad 上居中）
    public static let contentMaxWidth: CGFloat = 600
}

/// 圆角令牌（06 第 1 节）。全部是连续圆角。
public enum PourRadius {
    /// 荧光高亮、心情像素
    public static let xs: CGFloat = 3
    /// 卡片里的小块（骨架占位、迷你图）
    public static let sm: CGFloat = 8
    /// 输入框、分段控件、图片缩略
    public static let md: CGFloat = 12
    /// 卡片、列表组
    public static let lg: CGFloat = 20

    /// 同心圆角：里面的圆角 = 外面的圆角 − 间距，小于 8 取 8
    public static func concentric(outer: CGFloat, inset: CGFloat) -> CGFloat { max(outer - inset, sm) }
}

/// 图标大小令牌（04 第 1 节）：跟着旁边的字走
public enum PourIconSize {
    public static let small = Font.TextStyle.footnote
    public static let body = Font.TextStyle.body
    public static let large = Font.TextStyle.title3
    /// 空状态（固定 32，随动态字体放大见 `PourEmptyState`）
    public static let display: CGFloat = 32
}

extension Shape where Self == RoundedRectangle {
    /// 连续圆角矩形
    public static func pour(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
