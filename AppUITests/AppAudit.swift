import XCTest

/// App 的无障碍审计：系统的审计有几类误报，画廊的实验证明过（GalleryUITests 的 testAudit… 几个实验，
/// 哪天苹果修好了它们会失败），这里照同样的规矩放过，别的一律算数。放过的也打出来，数得清
enum AppAudit {
    @MainActor
    static func run(_ app: XCUIApplication, name: String) throws {
        let bar = app.buttons["pourbar"]
        let barFrame = bar.exists ? bar.frame : nil
        try app.performAccessibilityAudit { issue in
            let frame = issue.element?.frame
            let label = issue.element?.label ?? ""
            if let reason = exemption(type: issue.auditType, frame: frame, label: label, bar: barFrame) {
                print("放过（\(reason)）[\(name)] \(issue.compactDescription) ← \(label)")
                return true
            }
            print("审计问题 [\(name)] \(issue.compactDescription) ← \(label) \(frame.map { "\($0)" } ?? "")")
            return false
        }
    }

    static func exemption(type: XCUIAccessibilityAuditType, frame: CGRect?, label: String, bar: CGRect?) -> String? {
        guard let frame else { return nil }
        // 倾倒栏在标签栏的底部附件里：系统的栏不随字号长高，字号封顶、长按看大字；玻璃上量对比度不准
        // 见画廊的 isSystemBar、isSystemEdge，截图核实过
        if let bar, bar.insetBy(dx: -2, dy: -2).contains(frame), [.dynamicType, .textClipped, .contrast].contains(type)
        {
            return "系统的栏"
        }
        // 会换行的字一律被报截断（testAuditProbeStillMisreportsWrappedText）
        if type == .textClipped && frame.height >= 30 { return "审计自己的毛病" }
        // 带全角括号的一行字一律被报截断（testAuditProbeParentheses）
        if type == .textClipped && (label.contains("（") || label.contains("）")) { return "审计自己的毛病" }
        return nil
    }
}
