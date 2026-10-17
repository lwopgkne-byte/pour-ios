import PourDesign
import SwiftUI

// MARK: - 颜色

struct ColorsPage: View {
    private struct Swatch {
        let name: String
        let meaning: String
        let token: ColorToken
    }

    private let semantic: [Swatch] = [
        Swatch(name: "canvas", meaning: "纸 · 页面底色", token: PourColor.canvas),
        Swatch(name: "surface", meaning: "卡", token: PourColor.surface),
        Swatch(name: "surfaceSunken", meaning: "凹", token: PourColor.surfaceSunken),
        Swatch(name: "ink", meaning: "墨 · 正文", token: PourColor.ink),
        Swatch(name: "inkSecondary", meaning: "淡墨 · 次要信息", token: PourColor.inkSecondary),
        Swatch(name: "inkTertiary", meaning: "浅墨 · 只做装饰", token: PourColor.inkTertiary),
        Swatch(name: "action", meaning: "操作 · 按钮、链接、选中", token: PourColor.action),
        Swatch(name: "qing", meaning: "青 · 只表示「它懂你」", token: PourColor.qing),
        Swatch(name: "qingSoft", meaning: "青浅底 · 新发现、刚凝结", token: PourColor.qingSoft),
        Swatch(name: "marker", meaning: "荧光 · 就在这里", token: PourColor.marker),
        Swatch(name: "attention", meaning: "琥珀 · 需要你", token: PourColor.attention),
        Swatch(name: "line", meaning: "线", token: PourColor.line),
    ]

    var body: some View {
        GalleryPage {
            GallerySection("语义令牌（亮暗、增强对比度自动切换）") {
                ForEach(semantic, id: \.name) { swatch in
                    HStack(spacing: PourSpace.element) {
                        RoundedRectangle.pour(PourRadius.sm).fill(swatch.token.color).frame(width: 44, height: 44)
                            .overlay(RoundedRectangle.pour(PourRadius.sm).strokeBorder(PourColor.line.color))
                        VStack(alignment: .leading, spacing: PourSpace.tight) {
                            Text(verbatim: swatch.name).pourText(.body).monospaced()
                            Text(swatch.meaning).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            GallerySection("九个生活领域（只出现在数据里）") {
                ForEach(PourDomain.allCases, id: \.self) { domain in
                    HStack(spacing: PourSpace.element) {
                        PourDomainDot(domain, size: 14)
                        Text(domain.displayName).pourText(.body)
                        Spacer()
                        Text(verbatim: "示例").pourText(.callout).foregroundStyle(domain.text.color)
                            .padding(.horizontal, PourSpace.related).padding(.vertical, PourSpace.tight)
                            .background(Capsule().fill(domain.soft.color))
                    }
                }
            }
            GallerySection("心情五档（越好越深）") {
                HStack(spacing: PourSpace.related) {
                    ForEach(1...5, id: \.self) { PourMoodCell(level: $0, size: PourSize.moodCellCalendar) }
                    PourMoodCell(level: nil, size: PourSize.moodCellCalendar)
                    Text("最后一格：没记").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                }
            }
        }
        .navigationTitle("颜色")
    }
}

// MARK: - 字

struct TypePage: View {
    var body: some View {
        GalleryPage {
            GallerySection("全部用苹果的默认字体；原话靠行距和左侧细线区分") {
                ForEach(PourTextStyle.allCases, id: \.self) { style in
                    VStack(alignment: .leading, spacing: PourSpace.tight) {
                        Text(
                            style.isQuoteVoice
                                ? "早上跑了五公里，路上的桂花全开了" : (style == .display || style == .displayXL ? "¥784" : "今天过得怎么样")
                        )
                        .pourText(style)
                        Text(verbatim: "\(style.rawValue) · \(Int(style.size))/\(Int(style.lineHeight))")
                            .pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                    }
                }
            }
            GallerySection("原话块") {
                QuoteBlock(
                    source: "10月16日 周五 21:10 · 语音", quote: "在公司待了11个小时 有点累 太晚了打车回的 56 能报销", highlight: "打车回的 56 能报销")
            }
        }
        .navigationTitle("字")
    }
}

// MARK: - 组件（每个组件的全部状态）

struct ComponentsPage: View {
    @State private var chip = true
    @State private var undo = false
    var body: some View {
        GalleryPage {
            GallerySection("按钮") {
                Button("说第一句话") {}.buttonStyle(PourButtonStyle(.primary, large: true))
                Button("保存") {}.buttonStyle(PourButtonStyle(.primary, isLoading: true))
                Button("保存") {}.buttonStyle(PourButtonStyle(.primary)).disabled(true)
                Text("不能点时说明为什么：还没写内容").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                HStack {
                    Button("是这周六") {}.buttonStyle(PourButtonStyle(.secondary))
                    Button("看全部") {}.buttonStyle(PourButtonStyle(.text))
                    PourIconButton("ellipsis", label: "更多") {}
                }
                Button {
                } label: {
                    PourDestructiveLabel("删除所有数据")
                }.buttonStyle(PourButtonStyle(.destructive))
            }
            GallerySection("胶囊标签、头像、进度") {
                HStack {
                    PourInfoChip("能报销", domain: .lake)
                    PourFilterChip("这周", isSelected: chip) { chip.toggle() }
                    PourFilterChip("这个月", isSelected: !chip) { chip.toggle() }
                    PourAIBadge()
                }
                HStack(spacing: PourSpace.element) {
                    PourAvatar("小王", size: PourSize.avatarInline)
                    PourAvatar("老李")
                    PourAvatar("儿子", size: PourSize.avatarDetail)
                }
                PourGoalRow(name: "平均睡眠 7.5 小时", fraction: 0.92, headline: "落后 8%", behind: true, domain: .wisteria)
                PourGoalRow(name: "今年跑 500 公里", fraction: 0.2, headline: "101 公里", behind: false, domain: .moss)
            }
            GallerySection("倾倒栏（空闲 · 输入中 · 录音 · 发送中）") {
                ForEach(PourBarState.allCases, id: \.self) { state in
                    PourBar(
                        state: state, text: state == .typing || state == .sending ? "中午和小王吃面 三十二" : "",
                        recordingSeconds: 3
                    )
                }
            }
            GallerySection("收据（整理中 · 等网络 · 没整理成 · 整理好 + 追问）") {
                ReceiptView(time: "12:30", quote: "中午和小王吃面 三十二", state: .organizing)
                ReceiptView(time: "12:31", quote: "下午去爬山", state: .waitingForNetwork)
                ReceiptView(time: "12:32", quote: "早上跑了五公里", state: .failed)
                ReceiptView(
                    time: "21:10", quote: "周末可能去爬山", state: .done,
                    lines: [ReceiptLine(domain: .moss, title: "去爬山", needsConfirmation: true)],
                    question: QuestionPrompt("是这周六去爬山吗？要记成待办吗？", options: ["是这周六", "不用记"]))
            }
            GallerySection("记录卡（普通 · 待确认 · 刚凝结 · 刚改过）") {
                RecordCard(
                    .event(domain: .moss, title: "跑步", value: "5 公里", detail: "07:10–07:42 · 小区", person: nil))
                RecordCard(
                    .money(title: "打车回家", amount: "¥56", detail: "21:40", tag: "能报销", worthQuote: nil),
                    state: .needsConfirmation)
                RecordCard(
                    .mood(level: 4, saying: "挺好", feeling: "放松", moment: "晚上楼下飘上来烤红薯的香味"), state: .justCondensed)
                RecordCard(.insight(title: "运动真的很重要", quote: "只睡了 2 个小时、头痛，健康真的很重要"), state: .justChanged)
                RecordCard(.todo(title: "给客户回电话", due: "明天 10:00", done: false))
                RecordCard(.todo(title: "买猫粮", due: nil, done: true))
            }
            GallerySection("发现卡") {
                DiscoveryCard(
                    sentence: "加班到很晚的日子，几乎都说累；别的日子一成多。", these: 1, others: 0.19, basis: "10 天里 10 天 · 52 天里 10 天")
            }
            GallerySection("撤销条、空状态、加载、出错") {
                Button(undo ? "撤销条出现了" : "点一下出撤销条") { withAnimation(PourMotion.smooth) { undo.toggle() } }
                if undo {
                    UndoToast("已记下 3 件事") { undo = false }.transition(.move(edge: .bottom).combined(with: .opacity))
                }
                PourEmptyState(systemImage: "sun.max", title: "今天还是空白", example: "中午吃了碗牛肉面 28")
                PourSkeleton(lines: 3)
                PourErrorView("没整理成：网络断了。联网后会自动再试")
            }
        }
        .navigationTitle("组件")
    }
}

// MARK: - 图表

struct ChartsPage: View {
    private let sample = Sample.shared

    var body: some View {
        GalleryPage {
            GallerySection("方块图：你的生活由什么组成") {
                PourTreemap(
                    sample.about.tiles.map {
                        TreemapItem(domain: $0.domain.pourDomain, label: $0.name, count: $0.notes)
                    })
            }
            GallerySection("时间去向") {
                PourTimeShare([
                    TimeShareItem(domain: .wisteria, label: "睡眠", minutes: 2900),
                    TimeShareItem(domain: .lake, label: "工作", minutes: 2400),
                    TimeShareItem(domain: .straw, label: "学习", minutes: 620),
                    TimeShareItem(domain: .moss, label: "运动", minutes: 300),
                ])
            }
            GallerySection("对比横条、迷你曲线、一周七天") {
                PourCompareBars(theseLabel: "这些日子", these: 0.92, othersLabel: "别的日子", others: 0.14)
                PourSparkline([5, 6, 6, 7, 6, 8, 9, 9]).frame(height: PourSize.miniChartHeight)
                PourWeekBars([57, 38, 95, 44, 237, 279, 308], highlightIndex: 6, highlightLabel: "最多").frame(
                    height: 120)
            }
            GallerySection("心情像素墙（9 周）") {
                PourMoodWall((0..<63).map { $0 % 9 == 4 ? nil : ($0 * 7 + 3) % 5 + 1 })
            }
            GallerySection("钱的月历") {
                PourMoneyCalendar(
                    firstWeekday: sample.money.firstWeekday, amounts: sample.money.calendar, today: sample.money.today)
            }
        }
        .navigationTitle("图表")
    }
}

// MARK: - 动效和触感

struct MotionPage: View {
    @State private var condensed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GalleryPage {
            GallerySection("触感（点一下就感觉到；一次操作最多一下）") {
                ForEach(PourHaptic.allCases, id: \.self) { haptic in
                    Button(haptic.title) { haptic.play() }
                }
            }
            GallerySection("招牌动效：倾倒 → 凝结") {
                Button(condensed ? "再来一次" : "发送一句") {
                    condensed = false
                    PourHaptic.send.play()
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(PourMotion.respecting(PourMotion.lively, reduceMotion: reduceMotion)) {
                            condensed = true
                        }
                        PourHaptic.success.play()
                    }
                }
                ReceiptView(
                    time: "12:30", quote: "早上跑了五公里 中午和小王吃面三十二", state: condensed ? .done : .organizing,
                    lines: [
                        ReceiptLine(domain: .moss, title: "跑步", value: "5 公里"),
                        ReceiptLine(domain: .apricot, title: "午饭 吃面", person: "小王", value: "¥32"),
                    ],
                    highlightNew: condensed)
                Text(reduceMotion ? "已打开「减少动态效果」：只有淡入淡出" : "时长令牌：0.1 / 0.2 / 0.3 / 0.45 / 0.7 秒")
                    .pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            }
        }
        .navigationTitle("动效和触感")
    }
}

// MARK: - App 图标

struct IconsPage: View {
    private struct IconOption {
        /// 可切换图标的名字；nil 是默认图标
        let icon: String?
        let title: String
        let note: String
    }

    private let options: [IconOption] = [
        IconOption(icon: nil, title: "方案一 · 倾", note: "纸底墨色「倾」字，下面一条青线：直接、好认"),
        IconOption(icon: "IconPour", title: "方案二 · 倾倒", note: "倾斜的杯子从杯沿流下一笔青，落成一条平稳的线：「倾倒 → 结构」"),
        IconOption(icon: "IconLine", title: "方案三 · 一条线", note: "只有一笔青：从高处顺势落下，收成平稳——最安静、最抽象"),
    ]
    @State private var current = UIApplication.shared.alternateIconName

    var body: some View {
        GalleryPage {
            GallerySection {
                ForEach(options, id: \.title) { option in
                    let name = option.icon
                    Button {
                        UIApplication.shared.setAlternateIconName(name)
                        current = name
                    } label: {
                        HStack(spacing: PourSpace.card) {
                            Image(name.map { "\($0)-preview" } ?? "IconChar-preview")
                                .resizable().frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle.pour(PourRadius.md))
                            VStack(alignment: .leading, spacing: PourSpace.tight) {
                                Text(option.title).pourText(.headline).foregroundStyle(PourColor.ink.color)
                                Text(option.note).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                            }
                            Spacer()
                            if current == name { Image(systemName: "checkmark").foregroundStyle(PourColor.ink.color) }
                        }
                    }
                }
            } footer: {
                "点一个，主屏上这个画廊的图标就换成它，回主屏看实际效果。"
            }
        }
        .navigationTitle("App 图标")
    }
}
