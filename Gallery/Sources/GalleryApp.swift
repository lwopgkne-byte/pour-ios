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
                    GalleryHeader("用网页版演示数据里那个人 \(Sample.shared.day) 真实的一天。亮色、暗色在系统设置里切换。")
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

/// 审计实验（只给界面测试用）：同一句话，只用系统自带的 Text，看系统审计会不会也报「截断」
struct AuditProbe: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.card) {
            Text("比上个月这时候少 ¥10,381：上个月这时候有装修尾款 ¥8,000、买沙发 ¥4,200。").font(.callout)
                .accessibilityIdentifier("probe.system")
            Text("比上个月这时候少 ¥10,381：上个月这时候有装修尾款 ¥8,000、买沙发 ¥4,200。").pourText(.callout)
                .accessibilityIdentifier("probe.pour")
            Text("This is a long English sentence that wraps onto a second line on an iPhone screen.").font(.callout)
                .accessibilityIdentifier("probe.english")
            Text("家人朋友").font(.callout).fontWeight(.semibold).accessibilityIdentifier("probe.cjkSingle")
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
