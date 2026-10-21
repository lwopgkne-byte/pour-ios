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
            // 「字号调大可能被截」又指不出是哪段字：是按钮里的字（不单独算一个元素），页面底下被输入框盖住一半的那一行
            // 换个位置也总有一行（回顾里「做了什么」一行一个按钮时稳定出现）。指得出的字照样审，这一类打出来、放过
            if issue.auditType == .textClipped {
                print("放过（指不出是哪段字，多半是被输入框盖住一半的那一行）[\(name)] \(issue.compactDescription)")
                return true
            }
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
        // 底部的输入框：页面在它后面滚，压在它下面、只露出一半的字量出来对比度不准、像被截断
        let bar = ["pourbar.input", "pourbar.chat", "pourbar.send"]
            .map { app.descendants(matching: .any)[$0] }.filter(\.exists).map(\.frame.minY).min()
        // 顶栏（菜单、搜索）：页面往上滚到它后面去的字也只露出一截
        let header = app.descendants(matching: .any)["today.menu"]
        let headerBottom = header.exists ? header.frame.maxY + Self.headerPadding : nil
        // 对话面板开着：面板里的字往上滚到面板上沿后面，只露出一截
        let chatOpen = app.buttons["pourbar.chat"].exists && app.buttons["pourbar.chat"].label == "收起对话"
        let panelTop =
            chatOpen
            ? app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.frame.height > 200 }
                .map(\.frame.minY).max() : nil
        var place = Place(
            glass: glass, navigation: navigation, barTop: bar.map { $0 - Self.barPadding }, headerBottom: headerBottom)
        place.panelTop = panelTop
        // 横着滑的一排（目标小卡、没说时间的小胶囊）：矮的那几个能滚的
        place.strips = app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.frame.height < 240 }.map(
            \.frame)
        if chatOpen { print("对话面板上沿：\(panelTop.map { "\($0)" } ?? "没找到")") }
        // 审计自己偶尔超时（「Audit failed to complete in time」）：检查用的模拟器刚开机、电脑同时在忙别的时更常见
        // （设置页那么长的一页，推送前检查里连着超时三次）。等十秒再审，最多四次
        // 连着超时两次：一类一类分开审（一次审的少，就审得完）
        for attempt in 1...2 {
            do {
                try audit(app, name: name, types: types, place: place, unresolved: unresolved)
                return
            } catch let error as NSError where error.code == -56 {
                print("审计超时，等十秒重审 [\(name)]")
                RunLoop.current.run(until: Date().addingTimeInterval(10))
                if attempt == 2 { break }
            }
        }
        for single in Self.singles where types.contains(single) {
            for attempt in 1...3 {
                do {
                    try audit(app, name: name, types: single, place: place, unresolved: unresolved)
                    break
                } catch let error as NSError where error.code == -56 && attempt < 3 {
                    print("审计超时（分开审），等十秒重审 [\(name)]")
                    RunLoop.current.run(until: Date().addingTimeInterval(10))
                }
            }
        }
    }

    /// 审计的每一类（分开审时一类一类来）
    private static let singles: [XCUIAccessibilityAuditType] = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .dynamicType, .textClipped, .trait,
    ]

    @MainActor
    private static func audit(
        _ app: XCUIApplication, name: String, types: XCUIAccessibilityAuditType, place: Place,
        unresolved: @escaping (XCUIAccessibilityAuditIssue) -> Bool
    ) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            // 字号封顶在 xxxLarge（产品主人 2026-10-21：特别大的那几档不兼容）：审计开到辅助功能那几档时字不再变大，
            // 报「部分不支持」，放过；完全不跟着字号变的照样算
            if issue.auditType == .dynamicType, issue.compactDescription.contains("partially unsupported") {
                print("放过（字号封顶）[\(name)] \(issue.compactDescription) ← \(issue.element?.label ?? "")")
                return true
            }
            guard let element = issue.element else { return unresolved(issue) }
            // 审计的时候页面还在动（数据刚拿回来、重新排了一遍），报出来的元素已经不在了：当成指不出元素的，拉回顶上再审
            guard element.exists else { return unresolved(issue) }
            // 辅助文字（Web.fgTertiary，60% 的墨色，对比度约 3.6:1）：产品主人 2026-10-19 要界面 1 比 1 照原来的样子，
            // 这个值是定过的；只放过「差一点」的，差得多的照样算（下一阶段统一设计系统时重新定）
            if issue.auditType == .contrast, issue.compactDescription.contains("nearly") {
                print("放过（辅助文字）[\(name)] \(issue.compactDescription) ← \(element.label)")
                return true
            }
            // 输入框自己的字和按钮照样审
            var place = place
            if element.identifier.hasPrefix("pourbar") { place.barTop = nil }
            place.oneLine = element.identifier == "webOneLine"
            // 顶栏自己的菜单、搜索也照样审
            if element.identifier == "today.menu" || element.label == "搜索" { place.headerBottom = nil }
            // 类别小标签（WebChip）：字是令牌色、对比度够；前面的彩色表情让审计量不准（和「表情不是字」一样）
            if issue.auditType == .contrast, element.identifier == "webChip" {
                print("放过（表情不是字）[\(name)] \(issue.compactDescription) ← \(element.label)")
                return true
            }
            // 系统键盘上面的联想词条（TUIPredictionViewCell）：系统自己的，不是 App 的；有时审计时刚好冒出来
            if issue.detailedDescription.contains("TUIPredictionViewCell") {
                print("放过（键盘的联想词条，系统的）[\(name)] \(issue.compactDescription)")
                return true
            }
            if let reason = exemption(type: issue.auditType, frame: element.frame, label: element.label, place: place) {
                print("放过（\(reason)）[\(name)] \(issue.compactDescription) ← \(element.label)")
                return true
            }
            // 对比度：截下这一块实量最深、最浅的像素（AuditPixels），够了才放过，把量出来的数打出来
            if issue.auditType == .contrast, let ratio = AuditPixels.contrast(of: element),
                ratio >= AuditPixels.readable
            {
                let measured = String(format: "%.1f", ratio)
                print("放过（截图实量 \(measured):1）[\(name)] \(issue.compactDescription) ← \(element.label)")
                return true
            }
            print("审计问题 [\(name)] \(issue.compactDescription) ← \(element.label) \(element.frame)")
            print("  详细：\(issue.detailedDescription)（编号：\(element.identifier)）")
            return false
        }
    }

    /// 输入框里的字、按钮到整条输入栏上沿那条分隔线的距离（Composer：上下各 4 点、外面再 8 点，再加分隔线上下几点：
    /// 检查用的模拟器上，压着分隔线的那一行字量出来对比度不够）
    private static let barPadding: CGFloat = 18
    /// 顶栏 48 点高，菜单按钮 44 点、上下各空 2 点
    private static let headerPadding: CGFloat = 2

    /// 屏幕上系统的栏在哪
    struct Place {
        let glass: [CGRect]
        let navigation: [CGRect]
        /// 底部输入框的上沿（没有输入框是 nil）
        var barTop: CGFloat?
        /// 顶栏的下沿
        var headerBottom: CGFloat?
        /// 对话面板里能滚的那一块的上沿（面板没开是 nil）
        var panelTop: CGFloat?
        /// 这段字本来就只占一行、放不下用省略号（webOneLine）
        var oneLine = false
        /// 横着滑的一排
        var strips: [CGRect] = []

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
        if let reason = edge(type: type, frame: frame, place: place) { return reason }
        // 只有一个表情（卡片标题前的 🏃）：是彩色的图，不是字，量对比度、量截断都没有意义
        if [.contrast, .textClipped].contains(type), !label.isEmpty,
            label.unicodeScalars.allSatisfy({
                // 一家人 👨‍👩‍👧 这种是几个表情用「零宽连接符」连起来的，连接符和变体选择符也算在表情里
                $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0x238C
                    || [0x200D, 0xFE0F].contains($0.value)
            })
        {
            return "表情不是字"
        }
        // 对话里的「昨天的回顾好了 · …」「上周的周报好了 · …」：这一行本来就只占一行、放不下用省略号（truncate），
        // 完整的点开就是；读屏念的是整行
        if type == .textClipped, ["昨天的回顾好了 · ", "上周的周报好了 · ", "上个月的月报好了 · "].contains(where: label.hasPrefix) {
            return "本来就是一行"
        }
        // 这一行本来就只占一行、放不下用省略号（搜索结果）：字很大时会折行，读屏念的是整行
        if type == .textClipped, place.oneLine { return "本来就是一行" }
        // 会换行的字一律被报截断（testAuditProbeStillMisreportsWrappedText）
        if type == .textClipped && frame.height >= 30 { return "审计自己的毛病" }
        // 带全角括号的一行字一律被报截断（testAuditProbeParentheses）
        if type == .textClipped && (label.contains("（") || label.contains("）")) { return "审计自己的毛病" }
        return nil
    }

    /// 页面滚到输入框、顶栏、对话面板上沿后面，只露出一截：量出来的对比度、截断都不准；滚出来以后照样审
    private static func edge(type: XCUIAccessibilityAuditType, frame: CGRect, place: Place) -> String? {
        guard [.textClipped, .contrast].contains(type) else { return nil }
        // 压在底部输入框下面的（页面滚到它后面了）：露出来的那一截量不准；滚上来以后照样审
        if let top = place.barTop, frame.maxY > top {
            return "在输入框后面"
        }
        if let bottom = place.headerBottom, frame.minY < bottom {
            return "在顶栏后面"
        }
        // 对话开着时，面板里往上滚出面板上沿的（整个在上沿上面，被面板裁掉、看不见）：后面的页面压暗了、读屏不读
        if let top = place.panelTop, frame.maxY <= top + 2 {
            return "滚到对话面板上沿外面了"
        }
        if let top = place.panelTop, frame.minY < top + 2, frame.maxY > top {
            return "在对话面板上沿后面"
        }
        // 横着滑的一排两头只露出一部分的（提示还能往旁边滑）：露出来的那一截量不准；滑出来以后照样审
        let middle = CGPoint(x: frame.midX, y: frame.midY)
        if let strip = place.strips.first(where: { $0.contains(middle) }),
            !strip.insetBy(dx: -1, dy: -1).contains(frame)
        {
            return "横着滑的一排里只露出一部分"
        }
        return nil
    }
}
