import PourDesign
import SwiftUI

/// 样张：用示例数据静态渲染的五屏，放在和正式 App 一样的外壳里（系统标签栏 + 倾倒栏）
struct SampleShell: View {
    enum Tab: Hashable { case today, review, about, money, search }

    @State var tab: Tab
    var showReceipt = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $tab) {
            SwiftUI.Tab("今天", systemImage: "sun.max", value: Tab.today) {
                NavigationStack { TodaySample(showReceipt: showReceipt).toolbar { close } }
            }
            SwiftUI.Tab("回顾", systemImage: "book.pages", value: Tab.review) {
                NavigationStack { ReviewSample().toolbar { close } }
            }
            SwiftUI.Tab("关于我", systemImage: "person.crop.circle", value: Tab.about) {
                NavigationStack { AboutSample().toolbar { close } }
            }
            SwiftUI.Tab("钱", systemImage: "yensign.circle", value: Tab.money) {
                NavigationStack { MoneySample().toolbar { close } }
            }
            SwiftUI.Tab(value: Tab.search, role: .search) {
                NavigationStack {
                    PourEmptyState(systemImage: "magnifyingglass", title: "搜你说过的话", example: "上次去爬山是什么时候")
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(PourColor.canvas.color)
                        .toolbar { close }
                }
            }
        }
        .tint(PourColor.action.color)
        .tabViewBottomAccessory { PourBarAccessory() }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var close: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("关闭样张", systemImage: "xmark") { dismiss() }
        }
    }
}

/// 倾倒栏放进标签栏的「底部附件」位置（规范 08；M3 实测和键盘、中文输入法的配合）
private struct PourBarAccessory: View {
    var body: some View {
        HStack {
            Text("今天做了什么？比如：8 点跑了 5 公里").pourText(.body).foregroundStyle(PourColor.inkSecondary.color).lineLimit(1)
            Spacer()
            Image(systemName: "mic").foregroundStyle(PourColor.inkSecondary.color).accessibilityLabel(Text("按住说话"))
        }
        .padding(.horizontal, PourSpace.card)
        .accessibilityIdentifier("pourbar")
    }
}

// MARK: - 今天

struct TodaySample: View {
    var showReceipt = false
    private let sample = Sample.shared.today
    private let receipt = Sample.shared.receipt

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PourDayHeader(title: sample.title, weekday: sample.weekday, summary: sample.summary)
                    VStack(spacing: PourSpace.element) {
                        ForEach(sample.goals) { goal in
                            PourGoalRow(
                                name: goal.name, fraction: goal.fraction, headline: goal.headline,
                                behind: goal.behind, domain: goal.domain.pourDomain)
                        }
                    }
                    .padding(.top, PourSpace.group)

                    if showReceipt, let receipt {
                        PourCard {
                            ReceiptView(
                                time: "21:10", quote: receipt.quote, state: .done,
                                lines: receipt.lines.map {
                                    ReceiptLine(
                                        domain: $0.domain.pourDomain, title: $0.title, person: $0.person,
                                        value: $0.value)
                                },
                                highlightNew: true)
                        }
                        .padding(.top, PourSpace.section)
                        UndoToast("已记下 \(receipt.lines.count) 件事").frame(maxWidth: .infinity).padding(
                            .top, PourSpace.element)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        let items = sample.timeline.filter { $0.kind != "todo" }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            PourTimelineRow(
                                time: item.time, domain: item.domain?.pourDomain, isLast: index == items.count - 1
                            ) {
                                timelineContent(item)
                            }
                        }
                    }
                    .padding(.top, PourSpace.section)
                }
                .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                .padding(.bottom, PourSpace.section)
            }
        }
        .background(PourColor.canvas.color)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { PourAvatar("我", size: PourSize.avatarInline + 6) }
        }
    }

    @ViewBuilder private func timelineContent(_ item: Sample.TimelineItem) -> some View {
        if item.kind == "mood", let level = item.level {
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                HStack(spacing: PourSpace.related) {
                    PourMoodCell(level: level)
                    Text(moodWord(level)).pourText(.body).foregroundStyle(PourColor.ink.color)
                    if let feeling = item.feeling {
                        Text(feeling).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                    }
                }
                if let moment = item.moment {
                    Text("「\(moment)」").pourText(.quote).foregroundStyle(PourColor.ink.color)
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: PourSpace.related) {
                (Text(item.title ?? "")
                    + (item.person.map { Text(" · 和") + Text($0).foregroundStyle(PourColor.qing.color) } ?? Text("")))
                    .pourText(.body).foregroundStyle(PourColor.ink.color)
                Spacer(minLength: PourSpace.related)
                if let value = item.value {
                    Text(value).pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                }
            }
        }
    }

    /// 心情五级的说法（规范 10；M2 起由 PourCore 统一产出）
    private func moodWord(_ level: Int) -> String { ["很差", "不太好", "一般", "挺好", "很好"][min(max(level, 1), 5) - 1] }
}

// MARK: - 回顾

struct ReviewSample: View {
    private let reviews = Sample.shared.review

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: PourSpace.element) {
                    ForEach(reviews) { review in
                        PourCard {
                            VStack(alignment: .leading, spacing: PourSpace.related) {
                                Text(review.title).pourText(.headline).foregroundStyle(PourColor.ink.color)
                                HStack(alignment: .firstTextBaseline, spacing: PourSpace.inline) {
                                    Text(review.summary).pourText(.body).foregroundStyle(PourColor.ink.color)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                .padding(.vertical, PourSpace.related)
            }
        }
        .background(PourColor.canvas.color)
        .navigationTitle("回顾")
    }
}

// MARK: - 关于我

struct AboutSample: View {
    private let about = Sample.shared.about

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(about.caption).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                    PourSectionHeader("你的生活由什么组成")
                    Text("面积是说到它的段数").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                        .padding(.bottom, PourSpace.related)
                    PourTreemap(
                        about.tiles.map { TreemapItem(domain: $0.domain.pourDomain, label: $0.name, count: $0.notes) })

                    if let finding = about.finding {
                        PourSectionHeader("这周的新发现")
                        DiscoveryCard(
                            sentence: finding.sentence, these: finding.these, others: finding.others,
                            basis: finding.basis)
                    }

                    if let money = about.moneyAngle {
                        PourSectionHeader("换个角度看你")
                        HStack(alignment: .top, spacing: PourSpace.element) {
                            StatCard(title: "钱", value: money.big, conclusion: money.sub) { PourWeekBars(money.week) }
                            StatCard(title: "人", value: "儿子", conclusion: "最常在一起 · 34 天") {
                                PourSparkline([3, 4, 3, 5, 6, 5, 7])
                            }
                        }
                    }
                }
                .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                .padding(.bottom, PourSpace.section)
            }
        }
        .background(PourColor.canvas.color)
        .navigationTitle("关于我")
    }
}

// MARK: - 钱

struct MoneySample: View {
    private let money = Sample.shared.money
    @State private var hidden = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(money.month)花了").pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                    Text(hidden ? "¥ ••••" : money.spent).pourText(.display).monospacedDigit()
                        .foregroundStyle(PourColor.ink.color).contentTransition(.numericText())
                    if let compare = money.compare {
                        Text(compare).pourText(.callout).foregroundStyle(PourColor.ink.color)
                            .padding(.top, PourSpace.tight)
                    }
                    PourMoneyCalendar(
                        firstWeekday: money.firstWeekday, amounts: money.calendar, today: money.today, hidden: hidden
                    )
                    .padding(.top, PourSpace.group)

                    PourSectionHeader("花在哪")
                    PourCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(money.domains) { row in
                                PourListRow(row.name, value: hidden ? "•••" : row.amount, domain: row.domain.pourDomain)
                                    .padding(.horizontal, PourSpace.card)
                                if row.id != money.domains.last?.id {
                                    Divider().padding(.leading, PourSize.listDividerInset)
                                }
                            }
                        }
                    }

                    PourSectionHeader("留意的")
                    PourCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(money.watch) { row in
                                PourListRow(row.name, subtitle: row.sub, value: hidden ? "•••" : row.amount)
                                    .padding(.horizontal, PourSpace.card)
                                if row.id != money.watch.last?.id { Divider().padding(.leading, PourSpace.card) }
                            }
                        }
                    }
                }
                .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                .padding(.bottom, PourSpace.section)
            }
        }
        .background(PourColor.canvas.color)
        .navigationTitle("钱")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(hidden ? "显示金额" : "遮住金额", systemImage: hidden ? "eye" : "eye.slash") {
                    withAnimation(PourMotion.snappy) { hidden.toggle() }
                }
            }
        }
    }
}
