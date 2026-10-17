public import SwiftUI

/// 品牌字标：「倾」+ 一条青线 + 「Pour」（启动页、以后的关于页）。
///
/// 三样东西按**同一条放大曲线**（跟随大标题）一起缩放：动态字体调到最大，比例也不走样，
/// 而且不设上限——系统的无障碍审计不接受给文字封顶。
public struct PourBrandMark: View {
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var nameSize: CGFloat = 15
    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth: CGFloat = 24
    @ScaledMetric(relativeTo: .largeTitle) private var lineHeight: CGFloat = 2

    public init() {}

    public var body: some View {
        VStack(spacing: PourSpace.tight) {
            Text(verbatim: "倾")
                // 系统字体（苹方）：产品主人 2026-10-17 决定全部用苹果的默认字体（规范 02）
                .font(.system(size: markSize, weight: .medium))
                .foregroundStyle(PourColor.ink.color)
            // 品牌标志里唯一的青：倾倒之后落成的那条平稳的线（App 图标的意象，规范 04 第 4 节）
            Capsule()
                .fill(PourColor.qing.color)
                .frame(width: lineWidth, height: lineHeight)
            Text(verbatim: "Pour")
                .font(.system(size: nameSize))
                .foregroundStyle(PourColor.inkSecondary.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Pour 倾"))
        .accessibilityAddTraits(.isHeader)
    }
}
