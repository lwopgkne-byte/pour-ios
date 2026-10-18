import XCTest

/// 哪些审计问题不算数（每一条都有证据，见 M1 自验收报告第 4 节）：系统的边缘和玻璃栏、
/// 审计自己的毛病（实验证明过，修好了实验会失败）、截图核实过的几处原文。别的一律算数
enum AuditRules {

    struct AuditContext {
        let hasBottomGlass: Bool
        let glassTop: CGFloat
        let topEdge: CGFloat
        let screenBottom: CGFloat
        let scrolled: Bool
        /// 倾倒栏（标签栏的底部附件）现在在哪：收起、展开时不一样
        let barFrame: CGRect?
    }

    struct Finding {
        let type: XCUIAccessibilityAuditType
        /// nil：审计说不出是哪个元素（SwiftUI 内部节点）
        let frame: CGRect?
        let label: String?
    }

    static func exemption(for finding: Finding, _ context: AuditContext) -> String? {
        if isSystemEdge(finding, context) { return "系统边缘" }
        if isSystemBar(finding, context) { return "系统的栏" }
        if isProvenAuditBug(finding) { return "审计自己的毛病" }
        if isVerifiedMisreport(finding) { return "截图核实" }
        return nil
    }

    /// 系统的玻璃和渐隐区、屏幕边缘：内容滚到那里时量出来的对比度不是要读的内容的对比度
    static func isSystemEdge(_ finding: Finding, _ context: AuditContext) -> Bool {
        let isContrast = finding.type == .contrast
        guard let frame = finding.frame else { return false }
        if isContrast, context.hasBottomGlass, frame.maxY > context.glassTop { return true }  // 底部玻璃和它上方的渐隐
        // 顶上导航栏和它下方的渐隐：只有滑过以后内容才会在那里（第一屏那里的字照样算）
        if isContrast, context.scrolled, frame.minY < context.topEdge { return true }
        // 被屏幕下沿切掉一半的内容：只露出一部分，量出来的不算数，滑上来那一屏会再审
        return [.contrast, .textClipped].contains(finding.type) && frame.maxY > context.screenBottom
    }

    /// 倾倒栏在标签栏的底部附件里：附件的高度由系统定、不随字号长高，所以和系统标签栏一样，字号封顶、长按看大字
    /// （大字查看器，苹果的人机界面指南）。审计照样报「动态字体只支持一部分」，还把放得下的占位字报成「截断」——
    /// 亮色、暗色、最大字号、收起时的截图都核实过字是完整的（iPhone 15 · iOS 27.0 自验收）
    static func isSystemBar(_ finding: Finding, _ context: AuditContext) -> Bool {
        guard [.dynamicType, .textClipped].contains(finding.type), let frame = finding.frame,
            let bar = context.barFrame
        else { return false }
        return bar.insetBy(dx: -2, dy: -2).contains(frame)
    }

    /// 系统审计自己的毛病，用实验证明过（testAuditProbeStillMisreportsWrappedText、testAuditStillMismeasuresGlyphsAndHighlights，
    /// 修好了它们会失败）
    static func isProvenAuditBug(_ finding: Finding) -> Bool {
        guard let frame = finding.frame else { return false }
        // 图表的星期：一个字一个字的小标签，审计量不准（同色同号「三」报、「一」不报）；颜色由 PourColorTests 实算（7:1 以上）
        if finding.type == .contrast, let label = finding.label, weekdayGlyphs.contains(label) { return true }
        // 最小的字（caption2）：系统自带的 caption2 也被报「动态字体只支持一部分」——只放过一行高不超过 14 点的
        if finding.type == .dynamicType, frame.height <= 14 { return true }
        // 换行的文字：系统自带的 Text 怎么写都被报截断——只放过两行以上的（两行最小的字约 32 点高）。
        // 代价：28 点以上的大字单行被截断时审计查不出——这类标题都很短，靠截图检查
        if finding.type == .textClipped && frame.height >= 30 { return true }
        // 带全角括号的一行字：iOS 27.0 一律报截断（testAuditProbeParentheses）。代价同上：这种字真被截断时审计查不出，靠截图
        if finding.type == .textClipped, let label = finding.label, label.contains("（") || label.contains("）") {
            return true
        }
        return false
    }

    /// 截图核实过的误报：只按原文放过这三处，别的照样算
    static func isVerifiedMisreport(_ finding: Finding) -> Bool {
        guard let label = finding.label else { return false }
        if finding.type == .contrast { return verifiedContrastMisreports.contains(label) }
        if finding.type == .textClipped { return verifiedClippedMisreports.contains(label) }
        return false
    }

    /// 图表的星期
    static let weekdayGlyphs: Set<String> = ["一", "二", "三", "四", "五", "六", "日"]

    /// 系统审计报了、核实是正常的（M1 自验收报告第 4 节）：每条都写清是哪一屏、哪段字
    /// - 画廊·颜色「杏」：黑字白底，截图清楚；同一列别的领域名都不报
    /// - 画廊·字的原话块：带荧光的原话审计量不准（testAuditStillMismeasuresGlyphsAndHighlights）
    /// - 画廊·图表 钱的月历的「7」（iPhone 15 亮色报过一次）：淡墨在最深的格子上也有 5.27:1（PourColorTests 实算），
    ///   同一个月历里 1–6、8–31 都不报；一个细笔画的字量不准（同类的「三」有实验）
    /// - 画廊·组件 倾倒栏（发送中）玻璃上的字（最大字号时报）：截图黑字浅底，玻璃上量对比度不准
    static let verifiedContrastMisreports: Set<String> = [
        "杏", AuditProbe2Quote.highlighted, "7", "中午和小王吃面 三十二",
    ]

    /// 画廊·颜色、画廊·组件（倾倒栏输入中）、样张·关于我（统计卡）：一行字完整显示，截图核实；
    /// 系统自带的 Text 放「最常在一起 · 34 天」也被报（testAuditProbeStillMisreportsWrappedText）
    static let verifiedClippedMisreports: Set<String> = [
        "操作 · 按钮、链接、选中", "中午和小王吃面 三十二", "最常在一起 · 34 天",
    ]
}
