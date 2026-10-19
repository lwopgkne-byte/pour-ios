import XCTest

/// App 的无障碍审计：系统的审计有几类误报，画廊的实验证明过（GalleryUITests 的 testAudit… 几个实验，
/// 哪天苹果修好了它们会失败），这里照同样的规矩放过，别的一律算数。放过的也打出来，数得清
enum AppAudit {
    /// 「截断」「动态字体」单独审：和别的一起审时，倾倒栏里的字常常给不出是哪个元素（M2b 实测：单独审就给得出），
    /// 豁免就对不上了。画廊也是分开审的
    @MainActor
    static func run(_ app: XCUIApplication, name: String) throws {
        for types in [
            XCUIAccessibilityAuditType.all.subtracting([.textClipped, .dynamicType]), .textClipped, .dynamicType,
        ] {
            try run(app, name: name, types: types)
        }
    }

    /// 审一种（或几种）。指不出元素的问题先不判：审计自己会滚动页面，页面一滚倾倒栏就收起成小的、原来的元素没了
    /// （M2b 实测）——把页面拉回顶上、等一下再审一次，第二次还在才算数
    @MainActor
    private static func run(_ app: XCUIApplication, name: String, types: XCUIAccessibilityAuditType) throws {
        var unresolved = 0
        try audit(app, name: name, types: types) { _ in
            unresolved += 1
            return true
        }
        guard unresolved > 0 else { return }
        print("（\(name)：\(unresolved) 个问题指不出元素，拉回顶上再审一次）")
        app.swipeDown()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        try audit(app, name: name, types: types) { issue in
            print("审计问题 [\(name)] \(issue.compactDescription) ← 无元素：\(issue.detailedDescription)")
            print("当时的界面：\(app.debugDescription)")
            return false
        }
    }

    /// 跑一次审计：有元素的按规矩判；指不出元素的交给 unresolved 决定
    @MainActor
    private static func audit(
        _ app: XCUIApplication, name: String, types: XCUIAccessibilityAuditType,
        unresolved: @escaping (XCUIAccessibilityAuditIssue) -> Bool
    ) throws {
        // 浮在底部的玻璃：倾倒栏（标签栏的底部附件）、撤销条；导航栏
        let glass = [app.buttons["pourbar"], app.descendants(matching: .any)["undoToast"]].filter(\.exists).map(\.frame)
        let navigation = app.navigationBars.allElementsBoundByIndex.filter(\.exists).map(\.frame)
        // 底部的输入框（网页版 composer-dock）：页面在它后面滚，压在它下面、只露出一半的字量出来对比度不准、像被截断
        let bar = ["pourbar.input", "pourbar.chat", "pourbar.send"]
            .map { app.descendants(matching: .any)[$0] }.filter(\.exists).map(\.frame.minY).min()
        let place = Place(glass: glass, navigation: navigation, barTop: bar.map { $0 - Self.barPadding })
        // 审计自己偶尔超时（「Audit failed to complete in time」）：检查用的模拟器刚开机、电脑同时在忙别的时更常见
        // （设置页那么长的一页，推送前检查里连着超时三次）。等十秒再审，最多四次
        for attempt in 1...4 {
            do {
                try audit(app, name: name, types: types, place: place, unresolved: unresolved)
                return
            } catch let error as NSError where error.code == -56 && attempt < 4 {
                print("审计超时，等十秒重审 [\(name)]")
                RunLoop.current.run(until: Date().addingTimeInterval(10))
            }
        }
    }

    @MainActor
    private static func audit(
        _ app: XCUIApplication, name: String, types: XCUIAccessibilityAuditType, place: Place,
        unresolved: @escaping (XCUIAccessibilityAuditIssue) -> Bool
    ) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            guard let element = issue.element else { return unresolved(issue) }
            // 网页版的辅助文字（60% 的墨色，对比度约 3.6:1）：产品主人 2026-10-19 要界面 1 比 1 照网页版，
            // 网页版这个值是定过的（tokens.ts「fg-tertiary」）；只放过「差一点」的，差得多的照样算
            if issue.auditType == .contrast, issue.compactDescription.contains("nearly") {
                print("放过（网页版的辅助文字）[\(name)] \(issue.compactDescription) ← \(element.label)")
                return true
            }
            // 输入框自己的字和按钮照样审
            var place = place
            if element.identifier.hasPrefix("pourbar") { place.barTop = nil }
            if let reason = exemption(type: issue.auditType, frame: element.frame, label: element.label, place: place) {
                print("放过（\(reason)）[\(name)] \(issue.compactDescription) ← \(element.label)")
                return true
            }
            print("审计问题 [\(name)] \(issue.compactDescription) ← \(element.label) \(element.frame)")
            return false
        }
    }

    /// 输入框上沿到里面的字、按钮的距离（Composer：上下各 4 点、外面再 8 点）
    private static let barPadding: CGFloat = 12

    /// 屏幕上系统的栏在哪
    struct Place {
        let glass: [CGRect]
        let navigation: [CGRect]
        /// 底部输入框的上沿（没有输入框是 nil）
        var barTop: CGFloat?

        func inside(_ frames: [CGRect], _ frame: CGRect) -> Bool {
            frames.contains { $0.insetBy(dx: -2, dy: -2).contains(frame) }
        }
    }

    static func exemption(type: XCUIAccessibilityAuditType, frame: CGRect?, label: String, place: Place) -> String? {
        guard let frame else { return nil }
        // 浮在底部的玻璃（倾倒栏、撤销条）：系统的栏不随字号长高，字号封顶、长按看大字；玻璃上量对比度不准
        // （见画廊的 isSystemBar、isSystemEdge，截图核实过）
        if place.inside(place.glass, frame), [.dynamicType, .textClipped, .contrast].contains(type) {
            return "系统的栏"
        }
        // 导航栏里系统自己的按钮（「完成」）：也是字号封顶、长按看大字；玻璃上量对比度不准
        if place.inside(place.navigation, frame), [.dynamicType, .textClipped, .contrast].contains(type) {
            return "系统的栏"
        }
        // 压在底部输入框下面的（页面滚到它后面了）：露出来的那一截量不准；滚上来以后照样审
        if let top = place.barTop, frame.maxY > top, [.textClipped, .contrast].contains(type) {
            return "在输入框后面"
        }
        // 只有一个表情（卡片标题前的 🏃）：是彩色的图，不是字，量对比度、量截断都没有意义
        if [.contrast, .textClipped].contains(type), !label.isEmpty,
            label.unicodeScalars.allSatisfy({
                $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0x238C
            })
        {
            return "表情不是字"
        }
        // 对话里的「昨天的回顾好了 · …」「上周的周报好了 · …」：网页版这一行本来就只占一行、放不下用省略号（truncate），
        // 完整的点开就是；读屏念的是整行
        if type == .textClipped, ["昨天的回顾好了 · ", "上周的周报好了 · ", "上个月的月报好了 · "].contains(where: label.hasPrefix) {
            return "网页版就是一行"
        }
        // 会换行的字一律被报截断（testAuditProbeStillMisreportsWrappedText）
        if type == .textClipped && frame.height >= 30 { return "审计自己的毛病" }
        // 带全角括号的一行字一律被报截断（testAuditProbeParentheses）
        if type == .textClipped && (label.contains("（") || label.contains("）")) { return "审计自己的毛病" }
        return nil
    }
}
