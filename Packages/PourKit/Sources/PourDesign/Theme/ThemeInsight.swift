public import SwiftUI

// 3.0 感悟（docs/3.0/06-交互细节.md 第 5 节）：宋体的那一句是主角，底是纸一样的暖白；语录是一颗黄星。
// 一张感悟、今天重温（点了翻过来看原话）、分享出去的竖版卡片

extension Theme {
    /// 感悟的颜色：字用深金棕（和待办「过了」同一个，对比度够），星星亮一点（图形 ≥ 3:1，ThemeColorTests 量）
    public enum Idea {
        public static let paperToken = Tokens.one(0xFFFDF8)
        public static let paperBackToken = Tokens.one(0xFBF8F1)
        public static let starToken = Tokens.one(0xBF7A10)
        /// 「今天重温」、已收藏、标签上的字
        public static let ink = Tokens.warnInk.color
        /// 已收藏的胶囊、标签、刚记下那张亮一下的底
        public static let soft = Tokens.warnFill.color
        /// 收藏了的星
        public static let star = starToken.color
        /// 纸：今天重温的正面、记一句的输入框、一条感悟的那一句
        public static let paper = paperToken.color
        /// 今天重温翻过来的背面
        public static let paperBack = paperBackToken.color
        /// 一张感悟上的那一句
        public static let cardQuote = Font.custom("Songti SC", size: 18, relativeTo: .body)

        /// 今天重温、一条感悟里的大字：短的更大
        public static func bigQuote(_ text: String) -> Font {
            .custom("Songti SC", size: text.count > 14 ? 23 : 28, relativeTo: .title2)
        }
    }
}

/// 感悟的小标签（浅黄底深金棕字）
public struct InsightTag: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text).font(Theme.Typeface.caption).foregroundStyle(Theme.Idea.ink)
            .padding(.horizontal, Theme.Space.snug).padding(.vertical, Theme.Space.hairline)
            .background(Theme.Idea.soft, in: Capsule())
    }
}

/// 一张感悟（感悟页按月分组的卡片）：宋体那一句；下面日期 · 标签；右上角一颗星（点了收藏 / 取消）。
/// 刚记下的那张亮一下（fresh）；还在整理的写一句「整理中」、没有星
public struct InsightCard: View {
    let quote: String
    let date: String
    let tags: [String]
    let starred: Bool
    let status: String?
    let fresh: Bool
    /// 界面测试认这张卡（「insight.244」，星是「insight.244.star」）
    let identifier: String
    let open: () -> Void
    let star: (() -> Void)?
    @State private var glow = false

    public init(
        quote: String, date: String, tags: [String], starred: Bool, status: String? = nil, fresh: Bool = false,
        identifier: String = "insight", open: @escaping () -> Void, star: (() -> Void)?
    ) {
        self.quote = quote
        self.date = date
        self.tags = tags
        self.starred = starred
        self.status = status
        self.fresh = fresh
        self.identifier = identifier
        self.open = open
        self.star = star
    }

    public var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text(quote).font(Theme.Idea.cardQuote).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.quote - 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, star == nil ? 0 : Theme.Size.touch - Theme.Space.small)
                PourFlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.tight) {
                    Text(date).font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                    ForEach(tags, id: \.self) { InsightTag($0) }
                    if let status {
                        Text(status).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
            }
            .themeCard()
            .overlay {
                // 刚记下的亮一下：浅黄叠在白底上（字还是原来的颜色）
                Theme.rounded(Theme.Corner.card).fill(Theme.Idea.soft).blendMode(.multiply)
                    .opacity(glow ? 1 : 0).allowsHitTesting(false)
            }
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(([quote, date] + tags + [status].compactMap(\.self)).joined(separator: "，")))
        .accessibilityValue(Text(starred ? "语录" : ""))
        .accessibilityIdentifier(identifier)
        .overlay(alignment: .topTrailing) {
            if let star { starButton(star) }
        }
        .task(id: fresh) {
            guard fresh else { return }
            glow = true
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 1.2)) { glow = false }
        }
    }

    private func starButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // 照原型：星星在一个浅灰的圆里
            Image(systemName: starred ? "star.fill" : "star").font(Theme.Typeface.subheadline.weight(.semibold))
                .foregroundStyle(starred ? Theme.Idea.star : Theme.Palette.secondaryLabel)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Theme.Size.smallRing, height: Theme.Size.smallRing)
                .background(Theme.Palette.fill, in: Circle())
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .padding(Theme.Space.tight)
        .accessibilityLabel(Text(starred ? "取消收藏" : "收藏成语录"))
        .accessibilityIdentifier("\(identifier).star")
        .themeSelectionFeedback(trigger: starred)
    }
}

/// 今天重温（06 交互细节 5.1）：正面「今天重温 · 16 天前你说」、宋体大字、日期 · 标签、「点一下看原话」；
/// 点了翻过来（3D）看你当时说的整段话（那一句标出来）、「以前也说过类似的 2 条 ›」，再点翻回来。
/// 两面一样高（高的那面说了算）；减弱动态效果时不转，只渐变
public struct InsightRevisitCard: View {
    let ago: String
    let quote: String
    let meta: String
    let said: String?
    let related: Int
    @Binding var flipped: Bool
    let openRelated: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        ago: String, quote: String, meta: String, said: String?, related: Int, flipped: Binding<Bool>,
        openRelated: @escaping () -> Void
    ) {
        self.ago = ago
        self.quote = quote
        self.meta = meta
        self.said = said
        self.related = related
        self._flipped = flipped
        self.openRelated = openRelated
    }

    public var body: some View {
        let angle: Double = flipped ? 180 : 0
        EqualHeights {
            front.modifier(FlipFace(angle: angle, back: false))
            back.rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                .modifier(FlipFace(angle: angle, back: true))
        }
        .rotation3DEffect(.degrees(reduceMotion ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .animation(Theme.Motion.pick(.smooth(duration: 0.5), reduceMotion: reduceMotion), value: flipped)
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("今天重温 · \(ago)").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Idea.ink)
            Spacer(minLength: 0)
            Text(quote).font(Theme.Idea.bigQuote(quote)).foregroundStyle(Theme.Palette.label)
                .lineSpacing(Theme.Leading.quote)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    metaText; Spacer(minLength: Theme.Space.small); hint
                }
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    metaText; hint
                }
            }
        }
        .face(Theme.Idea.paper)
        .contentShape(Theme.rounded(Theme.Corner.hero))
        .onTapGesture { flipped.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("今天重温，\(ago)：\(quote)。\(meta)"))
        .accessibilityHint(Text("翻过来看你当时说的整段话"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { flipped.toggle() }
        .accessibilityIdentifier("insights.revisit")
    }

    private var metaText: some View {
        Text(meta).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
    }

    private var hint: some View {
        HStack(spacing: Theme.Space.hairline) {
            Image(systemName: "arrow.left.arrow.right")
            Text("点一下看原话")
        }
        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            // 「你当时说的」和那段话是一整块（读屏念一遍），点了翻回来；下面「以前也说过类似的」单独能点
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                Text("你当时说的").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                Text(marked).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.quote)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { flipped.toggle() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("翻回正面"))
            .accessibilityIdentifier("insights.revisit.back")
            if related > 0 {
                Button(action: openRelated) {
                    Text("\(meta) · 以前也说过类似的 \(related) 条 ›").font(Theme.Typeface.footnoteSemibold)
                        .monospacedDigit().foregroundStyle(Theme.Palette.accent)
                        .frame(minHeight: Theme.Size.touch, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("insights.revisit.related")
            } else {
                metaText
            }
        }
        .face(Theme.Idea.paperBack)
        .accessibilityElement(children: .contain)
    }

    /// 原话里那一句标出来
    private var marked: AttributedString {
        var value = AttributedString(said ?? quote)
        if let range = value.range(of: quote) { value[range].backgroundColor = Theme.Idea.soft }
        return value
    }
}

extension View {
    /// 今天重温的一面：纸底、大圆角、和卡片一样的影子；两面一样高时铺满
    fileprivate func face(_ paper: Color) -> some View {
        padding(Theme.Space.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(minHeight: 220)
            .background(paper, in: Theme.rounded(Theme.Corner.hero))
            .themeEdge(radius: Theme.Corner.hero)
    }
}

/// 翻到一半（90°）时换面：背着的那面看不见、点不到、读屏也跳过
nonisolated private struct FlipFace: ViewModifier, Animatable {
    var angle: Double
    let back: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let shown = (angle > 90) == back
        content.opacity(shown ? 1 : 0).allowsHitTesting(shown).accessibilityHidden(!shown)
    }
}

/// 叠在一起、一样高：高的那个说了算（今天重温的两面）
private struct EqualHeights: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
        return CGSize(
            width: proposal.width ?? sizes.map(\.width).max() ?? 0, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for view in subviews { view.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size)) }
    }
}

/// 分享出去的竖版卡片（06 交互细节 5.3）：引号、宋体那句话、「—— 我，2026年10月11日」、角上「POUR · 倾」。
/// 画成图片用：宽 300 点，字号固定（不跟系统字号走），长的句子自己往下长、不截断
public struct InsightShareCard: View {
    /// 三种样子：暖白、墨色、月白
    public enum Look: String, CaseIterable, Identifiable, Sendable {
        case warm, ink, moon

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .warm: "暖白"
            case .ink: "墨色"
            case .moon: "月白"
            }
        }

        /// 底
        public var background: Color { Theme.Tokens.one(hexes[0]).color }
        /// 字
        public var text: Color { Theme.Tokens.one(hexes[1]).color }
        /// 引号
        public var mark: Color { Theme.Tokens.one(hexes[2]).color }

        private var hexes: [UInt32] {
            switch self {
            case .warm: [0xFBF8F1, 0x2A2723, 0xC9B892]
            case .ink: [0x22211E, 0xEFE9DC, 0x8C8270]
            case .moon: [0xE9EEF5, 0x22324E, 0x8FA2C2]
            }
        }
    }

    public static let width: CGFloat = 300
    let quote: String
    let signature: String
    let look: Look

    public init(quote: String, signature: String, look: Look) {
        self.quote = quote
        self.signature = signature
        self.look = look
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("“").font(.custom("Songti SC", fixedSize: 56)).foregroundStyle(look.mark)
                .frame(height: 36, alignment: .top)
            Text(quote).font(.custom("Songti SC", fixedSize: quote.count > 14 ? 22 : 27))
                .lineSpacing(10).foregroundStyle(look.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.small)
            Spacer(minLength: Theme.Space.section)
            Text(signature).font(.custom("Songti SC", fixedSize: 14)).foregroundStyle(look.text.opacity(0.72))
            Text("POUR · 倾").font(.system(size: 11, weight: .medium)).tracking(2)
                .foregroundStyle(look.text.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, Theme.Space.regular)
        }
        .padding(.horizontal, 30).padding(.top, 40).padding(.bottom, 26)
        .frame(width: Self.width, alignment: .leading)
        .frame(minHeight: 390)
        .background(look.background)
    }
}

#Preview("感悟：一张卡、今天重温、分享的卡片") {
    @Previewable @State var flipped = false
    ScrollView {
        VStack(spacing: Theme.Space.regular) {
            InsightRevisitCard(
                ago: "一个月前的今天你说", quote: "慢慢来，比较快。", meta: "10月1日 · 心态",
                said: "今天想通了一件事 慢慢来，比较快。以前总想一口气做完", related: 2, flipped: $flipped
            ) {}
            InsightCard(
                quote: "陪儿子的时候，就只陪儿子。", date: "10月29日", tags: ["家人", "专注"], starred: true, open: {}, star: {})
            InsightCard(
                quote: "先把一件事做完，再开始下一件。", date: "11月2日", tags: [], starred: true, status: "整理中", fresh: true,
                open: {}, star: nil)
            HStack(alignment: .top) {
                ForEach(InsightShareCard.Look.allCases) { look in
                    InsightShareCard(quote: "慢慢来，比较快。", signature: "—— 我，2026年10月11日", look: look)
                        .scaleEffect(0.3).frame(width: 90, height: 120)
                }
            }
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
