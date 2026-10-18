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
    private let screen: CGRect
    var screenBottom: CGFloat { screen.maxY }

    init(app: XCUIApplication, hasBottomGlass: Bool) {
        self.app = app
        self.hasBottomGlass = hasBottomGlass
        navigationBar = Self.navigationBar(app)
        bottomBars =
            hasBottomGlass
            ? [app.tabBars.firstMatch, app.descendants(matching: .any)["pourbar"].firstMatch].filter(\.exists) : []
        screen = app.frame
    }

    /// 滚动区域里的一段字：「字 + 第几次出现」认出是同一段（同样的字可能出现好几次）
    struct TextKey: Hashable {
        let label: String
        let index: Int
    }

    /// steps：每一屏按顺序做的事（截图和审计），参数是第几屏、页面滑过没有。每一步之前都把页面拖回这一屏——
    /// 有的审计审完会把页面挪走。只有露出了还没审过的字，这一屏才审
    func walk(_ steps: [(_ screen: Int, _ scrolled: Bool) -> Void]) -> [String] {
        let start = settled()
        var frames: [TextKey: CGRect] = [:]  // 每段字在整页上的位置（页面在最顶上时的屏幕坐标）
        var covered: Set<TextKey> = []
        var givenUp: Set<TextKey> = []  // 专门拖过去也没能完整露出来的：不再追，最后报出来
        var now = start
        var screen = 0
        for _ in 1...150 {
            let offset = Self.scrolled(from: start, to: now) ?? 0
            let scrolled = offset > 1
            let view = clearViewport(scrolled: scrolled)
            for (key, frame) in now { frames[key] = frame.offsetBy(dx: 0, dy: offset) }
            let visible = Set(now.filter { Self.isFullyVisible($0.value, in: view) }.keys)
            if !visible.isSubset(of: covered) {
                screen += 1
                covered.formUnion(visible)
                for (index, step) in steps.enumerated() {
                    if index > 0 { _ = go(to: offset, from: start) }
                    step(screen, scrolled)
                }
            }
            // 下一屏：还没审过的、最靠上的那段字，拖到「滑过以后」清楚区的顶上（上面留一点边）
            let pending = frames.filter { !covered.contains($0.key) && !givenUp.contains($0.key) }
            guard let next = pending.min(by: { $0.value.minY < $1.value.minY }) else { break }
            now = go(to: next.value.minY - clearViewport(scrolled: true).lowerBound - 12, from: start)
            let reached = Self.scrolled(from: start, to: now) ?? offset
            let shown = now[next.key].map { Self.isFullyVisible($0, in: clearViewport(scrolled: reached > 1)) } ?? false
            if !shown { givenUp.insert(next.key) }
        }
        return frames.keys.filter { !covered.contains($0) }.map(\.label).sorted()
    }

    /// 现在看得见的导航栏。样张盖在画廊首页上，首页的导航栏还在界面里、只是点不到——只看第一个会找错（踩过）
    static func navigationBar(_ app: XCUIApplication) -> XCUIElement? {
        app.navigationBars.allElementsBoundByIndex.first { $0.isHittable }
    }

    /// 系统的滚动边缘效果（导航栏下面的一段渐变）和底部浮动玻璃栏往上的一段投影：内容在那里时，审计量出来的对比度
    /// 不准（GalleryUITests 按同样的数放过），所以一段字要完整地出现在这两段以外才算审过。
    /// 数是从截图的像素量的（M1 自验收）：导航栏下沿往下约 26 点；玻璃栏往上的投影亮色约 24 点、暗色约 36 点，
    /// 审计在离玻璃 40 点以内都量不准——各留一点余量。页面最后一条离玻璃栏 64 点（PourSpace.pageEnd），在投影以外
    static let topFade: CGFloat = 40
    static let bottomFade: CGFloat = 44

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

    /// 拖到整页上的 target 位置（从最顶上往下滚了多少点），差 20 点以内就行；滚不动了就停
    private func go(to target: CGFloat, from start: [TextKey: CGRect]) -> [TextKey: CGRect] {
        var now = settled()
        for _ in 0..<12 {
            guard let offset = Self.scrolled(from: start, to: now), abs(target - offset) >= 20 else { break }
            drag(by: target - offset)
            let after = settled()
            if abs(Self.scrolled(from: now, to: after) ?? 0) < 1 { return after }  // 滚不动了
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
        // 系统认出「在拖」之前手指要先动一小段（约 10 点），这一段页面不动：多拖这么多
        let length = min(abs(distance) + 10, bottom - top)
        let (fromY, toY) = distance > 0 ? (bottom, bottom - length) : (top, top + length)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = screen.midX
        origin.withOffset(CGVector(dx: x, dy: fromY)).press(
            forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: toY)),
            withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// 页面从 before 到 after 往下滚了多少点（同一段字位置差的中位数）；没有共同的字就说不出来
    static func scrolled(from before: [TextKey: CGRect], to after: [TextKey: CGRect]) -> CGFloat? {
        let deltas = before.compactMap { key, frame in after[key].map { frame.minY - $0.minY } }.sorted()
        return deltas.isEmpty ? nil : deltas[deltas.count / 2]
    }

    /// 完整露出来了（比整个可见区还高的字：占满可见区也算）
    static func isFullyVisible(_ frame: CGRect, in view: ClosedRange<CGFloat>) -> Bool {
        let shown = min(frame.maxY, view.upperBound) - max(frame.minY, view.lowerBound)
        return shown >= min(frame.height, view.upperBound - view.lowerBound) - 1
    }
}
