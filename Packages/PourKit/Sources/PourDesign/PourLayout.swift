public import CoreGraphics
public import SwiftUI

/// 间距令牌（docs/ios/设计规范/05-布局与间距.md 第 1 节）。M0 只放启动页用得到的。
public enum PourSpace {
    /// 标题和它的副标题之间
    public static let tight: CGFloat = 4
    /// 卡片内边距
    public static let card: CGFloat = 16
    /// 节和节之间
    public static let section: CGFloat = 32
}

/// 字的令牌（docs/ios/设计规范/02-字体与排版.md）。全部绑定系统文字样式，跟着动态字体缩放。
public enum PourFont {
    /// 结构之声的小字：日期、时间、来源、版本号
    public static let caption = Font.footnote
    /// 次要信息
    public static let meta = Font.subheadline
}
