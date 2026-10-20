import PourDesign
import SwiftUI

/// 设计画廊（不上架）：设计规范的全部，在真机或模拟器上能翻、能点、能摸到触感（02 C4）。
/// 也是以后每个新组件「先上画廊、再进页面」的地方。
@main
struct GalleryApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-auditProbe") {
                AuditProbe()
            } else if ProcessInfo.processInfo.arguments.contains("-auditProbe2") {
                AuditProbe2()
            } else if ProcessInfo.processInfo.arguments.contains("-auditProbe3") {
                AuditProbe3()

            } else if ProcessInfo.processInfo.arguments.contains("-auditScrollProbe") {
                AuditScrollProbe()
            } else {
                GalleryHome()
            }
        }
    }
}

struct GalleryHome: View {
    @State private var sample: SampleEntry?

    struct SampleEntry: Identifiable {
        let id: String
        let tab: SampleShell.Tab
        var receipt = false
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    sampleRow("今天", "我今天过得怎么样", SampleEntry(id: "today", tab: .today))
                    sampleRow("收据", "说完一段话，它就地凝结成了什么", SampleEntry(id: "receipt", tab: .today, receipt: true))
                    sampleRow("关于我", "我是个什么样的人", SampleEntry(id: "about", tab: .about))
                    sampleRow("钱", "我的钱去哪了", SampleEntry(id: "money", tab: .money))
                    sampleRow("回顾", "昨天、这周过得怎么样", SampleEntry(id: "review", tab: .review))
                } header: {
                    GalleryHeader("样张")
                } footer: {
                    GalleryHeader("用演示数据里那个人 \(Sample.shared.day) 真实的一天。亮色、暗色在系统设置里切换。")
                }

                Section(header: GalleryHeader("设计规范")) {
                    NavigationLink("颜色") { ColorsPage() }
                    NavigationLink("字") { TypePage() }
                    NavigationLink("组件") { ComponentsPage() }
                    NavigationLink("图表") { ChartsPage() }
                    NavigationLink("动效和触感") { MotionPage() }
                    NavigationLink("App 图标") { IconsPage() }
                }
            }
            .navigationTitle("Pour 画廊")
            .fullScreenCover(item: $sample) { entry in SampleShell(tab: entry.tab, showReceipt: entry.receipt) }
        }
        .tint(PourColor.action.color)
    }

    private func sampleRow(_ title: String, _ question: String, _ entry: SampleEntry) -> some View {
        Button {
            sample = entry
        } label: {
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                Text(title).pourText(.body).foregroundStyle(PourColor.ink.color)
                Text(question).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
            }
        }
        .accessibilityIdentifier("sample.\(entry.id)")
    }
}

/// 审计实验（只给界面测试用）：「截断」检查会不会自己滑动页面，去查屏幕外（上面、下面）的字
struct AuditScrollProbe: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PourSpace.card) {
                clipped("probe.clippedTop")
                Text("今天过得怎么样").font(.caption2).accessibilityIdentifier("probe.caption2Top")
                Color.clear.frame(height: 3000)
                clipped("probe.clippedBottom")
                Text("今天过得怎么样").font(.caption2).accessibilityIdentifier("probe.caption2Bottom")
            }
            .padding(PourSpace.page(forWidth: 402))
        }
    }

    /// 一行放不下、被截成省略号的字
    private func clipped(_ id: String) -> some View {
        Text("这一句话很长很长，一行放不下，会被截成省略号").pourText(.body).lineLimit(1)
            .frame(width: 120, alignment: .leading)
            .accessibilityIdentifier(id)
    }
}

/// 审计实验 3（只给界面测试用）：一行放得下、带全角括号的字（画廊的分节标题）——iPhone 15 · iOS 27.0 上报「截断」。
/// 实验页一页只放几个探针：放多了超出屏幕，上下被切掉，审计的结果就不准了（M1 自验收两次踩到）
struct AuditProbe3: View {
    static let paren = "心情五档（越好越深）"

    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.card) {
            Text(Self.paren).pourText(.caption).accessibilityIdentifier("probe.paren.pour")
            Text("心情五档，越好越深").pourText(.caption).accessibilityIdentifier("probe.paren.free")
            Text(Self.paren).font(.footnote).accessibilityIdentifier("probe.paren.footnote")
            Text(Self.paren).font(.footnote).lineSpacing(0).accessibilityIdentifier("probe.paren.footnoteSpacing")
            Text(Self.paren).font(.caption).accessibilityIdentifier("probe.paren.caption")
            Text(Self.paren).font(.body).accessibilityIdentifier("probe.paren.body")
            Text("Mood (5 levels)").font(.footnote).accessibilityIdentifier("probe.paren.latin")
        }
        .padding(PourSpace.page(forWidth: 393))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PourColor.canvas.color)
    }
}

/// 审计实验 2（只给界面测试用）：审计量对比度时的两个毛病
/// - 一个字一个字的小标签（图表的星期）：同色同号，「三」报不够、「一」和两个字的「三月」不报
/// - 带荧光的原话块报不够；一模一样的原话块去掉荧光就不报
struct AuditProbe2: View {
    static let quote = "在公司待了11个小时 有点累 太晚了打车回的 56 能报销"

    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.card) {
            PourCard {
                HStack(spacing: PourSpace.group) {
                    glyph("三", id: "probe.glyph.san")
                    glyph("一", id: "probe.glyph.yi")
                    glyph("三月", id: "probe.glyph.sanyue")
                    glyph("7", id: "probe.glyph.seven")
                }
            }
            PourCard { QuoteBlock(source: "10月16日 周五 21:10 · 语音", quote: Self.quote, highlight: "打车回的 56 能报销") }
            // 去掉荧光的对照：多一个句号，好和上面那个分开
            PourCard { QuoteBlock(source: "10月16日 周五 21:10 · 语音", quote: Self.quote + "。") }
        }
        .padding(PourSpace.page(forWidth: 402))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PourColor.canvas.color)
    }

    private func glyph(_ text: String, id: String) -> some View {
        Text(text).pourText(.caption).foregroundStyle(PourColor.chartLabel.color).accessibilityIdentifier(id)
    }
}

/// 审计实验（只给界面测试用）：同一句话，只用系统自带的 Text，看系统审计会不会也报「截断」
struct AuditProbe: View {
    static let long = "比上个月这时候少 ¥10,381：上个月这时候有装修尾款 ¥8,000、买沙发 ¥4,200。"

    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.card) {
            Text("比上个月这时候少 ¥10,381：上个月这时候有装修尾款 ¥8,000、买沙发 ¥4,200。").font(.callout)
                .accessibilityIdentifier("probe.system")
            Text("比上个月这时候少 ¥10,381：上个月这时候有装修尾款 ¥8,000、买沙发 ¥4,200。").pourText(.callout)
                .accessibilityIdentifier("probe.pour")
            Text("This is a long English sentence that wraps onto a second line on an iPhone screen.").font(.callout)
                .accessibilityIdentifier("probe.english")
            Text("家人朋友").font(.callout).fontWeight(.semibold).accessibilityIdentifier("probe.cjkSingle")
            // 对照：系统最小的文字样式（caption2）本身，审计报不报「动态字体只支持一部分」
            Text("今天过得怎么样").font(.caption2).accessibilityIdentifier("probe.caption2")
            // 同一句会换行的话，换几种写法：看哪种写法审计不误报（找得到就全 App 都用它，删掉豁免）
            Text(Self.long).font(.callout).lineLimit(nil).accessibilityIdentifier("probe.v.lineLimitNil")
            Text(Self.long).font(.callout).lineLimit(6).accessibilityIdentifier("probe.v.lineLimit6")
            Text(Self.long).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("probe.v.fixedSize")
            Text(Self.long).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("probe.v.fullWidth")
            Text(Self.long).font(.callout).lineLimit(2...6).accessibilityIdentifier("probe.v.lineRange")
            // 和方块图里一模一样的块（宽 104、高 72、内边距 8、上面一行名字下面一行百分比）
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                Text("家人朋友").pourText(.callout).fontWeight(.semibold).accessibilityIdentifier("probe.tileLabel")
                Text(verbatim: "9%").pourText(.caption)
            }
            .padding(PourSpace.related)
            .frame(width: 104, alignment: .topLeading)
            .frame(maxHeight: 72, alignment: .topLeading)
            .background(RoundedRectangle.pour(PourRadius.md).fill(PourDomain.sakura.soft.color))

            HStack(spacing: PourSpace.related) {
                tile("noBackground", width: 104, maxHeight: 72, padded: true, background: false)
                tile("noWidth", width: nil, maxHeight: 72, padded: true, background: true)
            }
            HStack(spacing: PourSpace.related) {
                tile("noMaxHeight", width: 104, maxHeight: nil, padded: true, background: true)
                tile("noPadding", width: 104, maxHeight: 72, padded: false, background: true)
            }
            Text("家人朋友").pourText(.callout).fontWeight(.semibold).accessibilityIdentifier("probe.pourSingle")
            // 一行放得下的字，有没有空格：看审计是不是把带空格的一行字也报成截断
            Text("最常在一起 · 34 天").font(.callout).accessibilityIdentifier("probe.single.spaceMixed")
            Text("最常在一起·34天").font(.callout).accessibilityIdentifier("probe.single.noSpace")
            Text("家人 朋友").font(.callout).accessibilityIdentifier("probe.single.cjkSpace")
            Text("Hello world").font(.callout).accessibilityIdentifier("probe.single.latin")
        }
        .padding(PourSpace.page(forWidth: 402))
    }

    /// 方块图的块，每次去掉一样东西，看是哪一样让审计报截断
    @ViewBuilder
    private func tile(_ name: String, width: CGFloat?, maxHeight: CGFloat?, padded: Bool, background: Bool) -> some View
    {
        VStack(alignment: .leading, spacing: PourSpace.tight) {
            Text("家人朋友").pourText(.callout).fontWeight(.semibold).accessibilityIdentifier("probe.tile.\(name)")
            Text(verbatim: "9%").pourText(.caption)
        }
        .padding(padded ? PourSpace.related : 0)
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: maxHeight, alignment: .topLeading)
        .background(RoundedRectangle.pour(PourRadius.md).fill(background ? PourDomain.sakura.soft.color : .clear))
    }
}

/// 画廊的分节标题和脚注：用淡墨（系统默认的灰在无障碍审计里只是「差一点」，M1 自验收）
struct GalleryHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).pourText(.caption).foregroundStyle(PourColor.inkSecondary.color) }
}

/// 画廊的一页：和正式 App 一样的页面（纸底、滚动、卡片），不用系统列表——审计量的就是用户看到的样子
struct GalleryPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: PourSpace.group) { content }
                    .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                    .padding(.vertical, PourSpace.card)
            }
        }
        .background(PourColor.canvas.color)
    }
}

/// 画廊的一节：标题 + 一张卡片
struct GallerySection<Content: View>: View {
    let title: String?
    let footer: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content, footer: () -> String? = { nil }) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            if let title { GalleryHeader(title).accessibilityAddTraits(.isHeader) }
            PourCard { VStack(alignment: .leading, spacing: PourSpace.element) { content } }
            if let footer { GalleryHeader(footer) }
        }
    }
}
