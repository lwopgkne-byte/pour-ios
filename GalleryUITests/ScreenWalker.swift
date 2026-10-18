import XCTest

/// 把一个页面从上到下一屏一屏地走完（M1 自验收）：每一屏都停稳了再做 steps（截图、审计），
/// 直到滚动区域里的每一段字都完整露出来过一次；走完返回没露出来过的字（应该是空的）。
///
/// 为什么不直接 swipeUp、看某一段字动没动：
/// - 「到底了没有」不能只看一段字：第一段字常常是导航栏的标题，收起以后就不动了，会以为到底了（踩过：每页最多审了两屏）
/// - 系统审计的「截断」「动态字体」两项检查审完常常把页面挪走（实测几十点到一屏多）：
///   这里每一屏、每一步之前都按「在整页上的位置」拖回该去的地方
/// - swipeUp 滑多远、带多少惯性说不准；这里按住慢慢拖、停住再松手，滚多少就是拖多少
@MainActor
struct ScreenWalker {
    let app: XCUIApplication
    let hasBottomGlass: Bool
    /// 这一页看得见的导航栏、底部玻璃栏和屏幕：开始走的时候找一次（每次都在整棵树里找很慢——M1 一屏要走近一分钟）
    private let navigationBar: XCUIElement?
    private let bottomBars: [XCUIElement]
    /// 倾倒栏（标签栏的底部附件）：收起、展开时位置不一样，用的时候现取
    private let pourBar: XCUIElement?
    private let screen: CGRect
    var screenBottom: CGFloat { screen.maxY }
    var pourBarFrame: CGRect? { pourBar.flatMap { $0.exists ? $0.frame : nil } }

    init(app: XCUIApplication, hasBottomGlass: Bool) {
        self.app = app
        self.hasBottomGlass = hasBottomGlass
        navigationBar = Self.navigationBar(app)
        let bar = app.descendants(matching: .any)["pourbar"].firstMatch
        pourBar = hasBottomGlass && bar.exists ? bar : nil
        // 浮在底部的撤销条也是玻璃栏：内容滑到它下面量不准，从它下面开始拖也拖不动（最大字号时它很高——M1 自验收）
        let toast = app.descendants(matching: .any)["undoToast"].firstMatch
        bottomBars = hasBottomGlass ? [app.tabBars.firstMatch, bar, toast].filter(\.exists) : []
        screen = app.frame
    }

    /// 滚动区域里的一段字：「字 + 第几次出现」认出是同一段（同样的字可能出现好几次）
    struct TextKey: Hashable {
        let label: String
        let index: Int
    }

    /// steps：每一屏按顺序做的事（截图和审计），参数是第几屏、页面滑过没有。每一步之前都把页面拖回这一屏——
    /// 有的审计审完会把页面挪走。只有露出了还没审过的字，这一屏才审。
    ///
    /// 页面滚了多少，只拿**屏幕上看得见的字**算（前后两次都在屏幕上的那些字，位置差的中位数），一屏一屏累加：
    /// 屏幕外的字报的位置不可靠——最大字号时页面很长，拿开头时屏幕外的位置推算，会以为滚到了底（iPhone 15 自验收踩到）
    func walk(_ steps: [(_ screen: Int, _ scrolled: Bool) -> Void]) -> [String] {
        var walk = Progress(now: settled())
        for _ in 1...150 {
            walk.all.formUnion(walk.now.keys)
            auditIfNew(&walk, steps)
            let pending = walk.pending
            if pending.isEmpty { break }
            // 审完拖回来时页面会挪一点：有的字这时才完整露出来——先把它们审掉，再往下走
            let view = clearViewport(scrolled: walk.offset > 1)
            if walk.now.contains(where: { pending.contains($0.key) && Self.isFullyVisible($0.value, in: view) }) {
                continue
            }
            if !advance(&walk, pending: pending) { break }
        }
        return walk.all.filter { !walk.covered.contains($0) }.map(\.label).sorted()
    }

    /// 走到哪了
    private struct Progress {
        var now: [TextKey: CGRect]
        var all: Set<TextKey> = []  // 滚动区域里的全部字（只用来数有哪些，位置不用）
        var covered: Set<TextKey> = []
        var givenUp: Set<TextKey> = []  // 对准了也没能完整露出来的：不再追，最后报出来
        var offset: CGFloat = 0  // 从最顶上往下滚了多少
        var screen = 0
        var pending: Set<TextKey> { all.subtracting(covered).subtracting(givenUp) }
    }

    /// 这一屏露出了还没审过的字：截图、审计（每一步之前拖回这一屏）
    private func auditIfNew(_ walk: inout Progress, _ steps: [(_ screen: Int, _ scrolled: Bool) -> Void]) {
        let visible = Set(
            walk.now.filter { Self.isFullyVisible($0.value, in: clearViewport(scrolled: walk.offset > 1)) }.keys)
        guard !visible.isSubset(of: walk.covered) else { return }
        walk.screen += 1
        walk.covered.formUnion(visible)
        let anchor = walk.now
        for (index, step) in steps.enumerated() {
            if index > 0 { walk.now = restore(anchor) }
            step(walk.screen, walk.offset > 1)
        }
        walk.now = restore(anchor)
    }

    /// 往下走一屏（或者放弃对准了还露不全的那一段）；走不动、也没有要审的了就返回 false
    private func advance(_ walk: inout Progress, pending: Set<TextKey>) -> Bool {
        let distance: CGFloat
        switch next(walk.now, pending: pending) {
        case .move(let length):
            distance = length
        case .giveUp(let key, let frame):
            giveUp(key, frame: frame, view: clearViewport(scrolled: true), into: &walk.givenUp)
            return true
        }
        let before = walk.now
        walk.now = move(by: distance)
        // 算不出滚了多少（前后没有共同在屏幕上的字）：不当成到底了，按想滚的距离估
        guard let moved = Self.scrolled(from: before, to: walk.now, onScreen: isOnScreen) else {
            walk.offset += distance
            return true
        }
        walk.offset += moved
        guard abs(moved) < 1 else { return true }
        // 滚不动了（到底了）：屏幕上露不全的放弃，完整露出来的下一轮审掉；屏幕上一段没审过的都没有，就走完了
        let stuck = walk.now.filter { pending.contains($0.key) && isOnScreen($0.value) }
        if stuck.isEmpty { return false }
        let view = clearViewport(scrolled: walk.offset > 1)
        for (key, frame) in stuck where !Self.isFullyVisible(frame, in: view) {
            giveUp(key, frame: frame, view: view, into: &walk.givenUp)
        }
        return true
    }

    private enum Next {
        case move(CGFloat)
        case giveUp(TextKey, CGRect)
    }

    /// 下一步往下滚多远：屏幕上还没审过的字里最靠上的那段，对准清楚区的顶（比清楚区还高的字对准再往上一点，好占满）；
    /// 屏幕上没有就往下翻一屏；已经对准了还露不全（最大字号下比整屏还高、或者被屏幕边切着）就放弃这一段
    private func next(_ now: [TextKey: CGRect], pending: Set<TextKey>) -> Next {
        let clear = clearViewport(scrolled: true)
        let height = clear.upperBound - clear.lowerBound
        let onScreen = now.filter { pending.contains($0.key) && isOnScreen($0.value) }
        guard let next = onScreen.min(by: { $0.value.minY < $1.value.minY }) else { return .move(height - 24) }
        let tall = next.value.height >= height - 1
        let distance = next.value.minY - clear.lowerBound + (tall ? 2 : -12)
        return abs(distance) < 20 ? .giveUp(next.key, next.value) : .move(distance)
    }

    private func giveUp(_ key: TextKey, frame: CGRect, view: ClosedRange<CGFloat>, into givenUp: inout Set<TextKey>) {
        givenUp.insert(key)
        print("巡检：「\(key.label.prefix(20))」露不全，放弃（现在在 \(frame)，清楚区 \(view)）")
    }

    /// 在屏幕上（哪怕只露出一点）：这样的字报的位置才可靠
    private func isOnScreen(_ frame: CGRect) -> Bool { frame.maxY > screen.minY && frame.minY < screen.maxY }

    /// 现在看得见的导航栏。样张盖在画廊首页上，首页的导航栏还在界面里、只是点不到——只看第一个会找错（踩过）
    static func navigationBar(_ app: XCUIApplication) -> XCUIElement? {
        app.navigationBars.allElementsBoundByIndex.first { $0.isHittable }
    }

    /// 系统的滚动边缘效果（导航栏下面的一段渐变）和底部浮动玻璃栏往上的一段投影：内容在那里时，审计量出来的对比度
    /// 不准（GalleryUITests 按同样的数放过），所以一段字要完整地出现在这两段以外才算审过。
    /// 数是从截图的像素量的（M1 自验收）：导航栏下沿往下约 26 点；玻璃栏往上的投影亮色约 24 点、暗色约 36 点，
    /// 审计在离看得见的玻璃 40 点以内都量不准。底部按界面树里倾倒栏内容的上沿算——看得见的玻璃比它高约 13 点，
    /// 所以是 40 + 13，再留一点余量。页面最后一条离玻璃栏 64 点（PourSpace.pageEnd），在这一段以外
    static let topFade: CGFloat = 40
    static let bottomFade: CGFloat = 56

    /// 审得清楚的那一段：可见区去掉渐变（页面在最顶上时，顶上还没有渐变）
    func clearViewport(scrolled: Bool) -> ClosedRange<CGFloat> {
        let view = viewport()
        let top = view.lowerBound + (scrolled ? Self.topFade : 0)
        let bottom = view.upperBound - (hasBottomGlass ? Self.bottomFade : 0)
        return top...max(bottom, top + 1)
    }

    /// 内容能完整露出来的那一段（屏幕坐标）：导航栏下沿到底部玻璃上沿；没有底部玻璃就到屏幕下沿
    func viewport() -> ClosedRange<CGFloat> {
        let top = navigationBar?.frame.maxY ?? screen.minY
        let bottom = bottomBars.map(\.frame.minY).min() ?? screen.maxY
        return top...max(bottom, top + 1)
    }

    /// 滚动区域里所有的字和位置（包括滑出屏幕的），一次取整棵树。导航栏、标签栏、倾倒栏里的字不跟着滚，不算
    func scrollTexts() -> [TextKey: CGRect] {
        guard let root = try? app.snapshot() else { return [:] }
        var found: [TextKey: CGRect] = [:]
        var seen: [String: Int] = [:]
        var stack: [(node: any XCUIElementSnapshot, inScroll: Bool)] = [(root, false)]
        while let item = stack.popLast() {
            let inside = item.inScroll || item.node.elementType == .scrollView
            if inside, item.node.elementType == .staticText {
                let index = seen[item.node.label, default: 0]
                seen[item.node.label] = index + 1
                found[TextKey(label: item.node.label, index: index)] = item.node.frame
            }
            stack += item.node.children.reversed().map { ($0, inside) }  // 按界面里的先后顺序走
        }
        return found
    }

    /// 等滚动停下：隔 0.3 秒取两次，位置一样才算停了（最多等 3 秒）
    func settled() -> [TextKey: CGRect] {
        var last = scrollTexts()
        for _ in 0..<10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let now = scrollTexts()
            if now == last { return now }
            last = now
        }
        return last
    }

    /// 把页面拖回 anchor 那一屏：按两次都在屏幕上的字算差多少，差 20 点以内就行；最多拖 5 次
    /// （标签栏滑动时会收起、展开，页面跟着挪一点，追不上就停在这里——没审到的字下一轮还会再来）
    private func restore(_ anchor: [TextKey: CGRect]) -> [TextKey: CGRect] {
        var now = settled()
        for _ in 0..<5 {
            guard let away = Self.scrolled(from: anchor, to: now, onScreen: isOnScreen), abs(away) >= 20 else { break }
            drag(by: -away)
            let after = settled()
            if abs(Self.scrolled(from: now, to: after, onScreen: isOnScreen) ?? 0) < 1 { return after }  // 拖不动了
            now = after
        }
        return now
    }

    /// 往下滚 distance 点（负数往上）：一次拖不完就多拖几次，最多 5 次；滚不动了就停
    private func move(by distance: CGFloat) -> [TextKey: CGRect] {
        var now = settled()
        var remaining = distance
        for _ in 0..<5 where abs(remaining) >= 20 {
            drag(by: remaining)
            let after = settled()
            guard let moved = Self.scrolled(from: now, to: after, onScreen: isOnScreen), abs(moved) >= 1 else {
                return after
            }
            remaining -= moved
            now = after
        }
        return now
    }

    /// 把页面往下滚 distance 点（负数往上滚）：按住、慢慢拖、停住再松手——没有惯性。一次最多滚大半屏
    private func drag(by distance: CGFloat) {
        let view = viewport()
        // 离开导航栏、底部玻璃和主屏指示条（从屏幕最下面往上拖会回到主屏）
        let top = view.lowerBound + 24
        let bottom = min(view.upperBound, screen.maxY - 60) - 24
        // 系统认出「在拖」之前手指要先动一小段（约 10 点），这一段页面不动：多拖这么多。
        // 一次最多拖半屏：前后两次总有共同在屏幕上的字，才算得出滚了多少（最大字号时字很大，拖一整屏就没有了——iPhone 15 自验收）
        let length = min(abs(distance) + 10, (bottom - top) / 2)
        let (fromY, toY) = distance > 0 ? (bottom, bottom - length) : (top, top + length)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = screen.midX
        origin.withOffset(CGVector(dx: x, dy: fromY)).press(
            forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: toY)),
            withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// 页面从 before 到 after 往下滚了多少点：两次都在屏幕上的同一段字，位置差的中位数；没有共同的字就说不出来
    static func scrolled(
        from before: [TextKey: CGRect], to after: [TextKey: CGRect], onScreen: (CGRect) -> Bool
    ) -> CGFloat? {
        let deltas = before.compactMap { key, frame -> CGFloat? in
            guard onScreen(frame), let later = after[key], onScreen(later) else { return nil }
            return frame.minY - later.minY
        }.sorted()
        return deltas.isEmpty ? nil : deltas[deltas.count / 2]
    }

    /// 完整露出来了（比整个可见区还高的字：占满可见区也算）
    static func isFullyVisible(_ frame: CGRect, in view: ClosedRange<CGFloat>) -> Bool {
        let shown = min(frame.maxY, view.upperBound) - max(frame.minY, view.lowerBound)
        return shown >= min(frame.height, view.upperBound - view.lowerBound) - 1
    }
}
