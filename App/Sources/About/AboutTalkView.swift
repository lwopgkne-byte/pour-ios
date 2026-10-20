import PourAPI
import PourDesign
import SwiftUI

/// 你说的话那一页（docs/prd-about-me-2.md 5.4、6.2、6.5）：说话的时钟、这几周你在说什么、
/// 主题的起落、小词里的你、连锁反应。用的是你说这句话的时间；小词只和你自己比，不做任何判断
struct AboutTalkView: View {
    @Environment(AppModel.self) private var model
    let navigate: (String) -> Void
    @State private var page: API.MeTalkPage?
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeTalkPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeHead(title: "你说的话") {
                navigate("/about")
            } sub: {
                EmptyView()
            }
            MePanel {
                TalkClock(clock: page.clock, span: page.span).frame(maxWidth: Web.space16 * 5.6).frame(
                    maxWidth: .infinity)
                if !page.clock.sentence.isEmpty {
                    Text(Show.spaced(page.clock.sentence)).font(Web.body).foregroundStyle(Web.fg)
                }
            }
            if !page.topics.isEmpty {
                ReviewSection(title: "这几周你在说什么") {
                    VStack(spacing: 0) {
                        ForEach(page.topics, id: \.key) { topic in
                            HStack(spacing: Web.space3) {
                                HStack(spacing: Web.space2) {
                                    Circle().fill(Web.tag(topic.color).solid).frame(
                                        width: Web.space2, height: Web.space2)
                                    Text(topic.name).font(Web.bodySemibold).foregroundStyle(Web.fg)
                                }
                                .frame(minWidth: Web.space16, alignment: .leading)
                                MeLine(points: topic.points, color: Web.tag(topic.color).solid).frame(
                                    height: Web.space8)
                                MeNote(topic.word)
                            }
                            .frame(minHeight: Web.space12)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    MeNote("每周说到它的段数 · 按你说的话算，不看花了多少时间")
                }
            }
            if !page.themes.isEmpty {
                ReviewSection(title: "主题的起落") {
                    VStack(spacing: 0) { ForEach(page.themes, id: \.key) { theme($0) } }
                    MeNote("把你说过的话按意思归成几堆（在你电脑上归的，没发出去）· 名字是 AI 起的，点开是那几段原话")
                }
            }
            if !page.words.isEmpty { ReviewSection(title: "小词里的你") { words(page.words) } }
            if !page.chains.isEmpty {
                ReviewSection(title: "连锁反应") {
                    VStack(spacing: Web.space3) { ForEach(page.chains, id: \.key) { ChainCard(chain: $0) } }
                }
            }
            MeFoot()
        }
    }

    /// 一堆话：名字 + 每周几段的小曲线 + 一个词；点开是离这一堆最近的那几段原话
    private func theme(_ theme: API.MeTheme) -> some View {
        MeExpand {
            HStack(spacing: Web.space3) {
                Text(Self.themeLabel(theme)).font(Web.bodySemibold).foregroundStyle(Web.fg).lineLimit(1)
                    .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in width * 0.4 }
                MeLine(points: theme.points, color: Web.fgTertiary).frame(height: Web.space8)
                MeNote("\(theme.notes) 段 · \(theme.word)").fixedSize()
            }
        } content: {
            VStack(alignment: .leading, spacing: Web.space3) {
                MeQuotes(quotes: theme.quotes)
                DayLinks(days: theme.days)
            }
        }
    }

    /// 小词里的你：两列小卡，一句话、一个数；点开看是哪几天
    private func words(_ words: [API.MeWord]) -> some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            ForEach(Array(stride(from: 0, to: words.count, by: 2)), id: \.self) { start in
                HStack(alignment: .top, spacing: Web.space3) {
                    WordCard(word: words[start])
                    if start + 1 < words.count {
                        WordCard(word: words[start + 1])
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            MeNote("只和你自己比，不做任何判断")
        }
    }

    /// 没名字的一堆：用第一段原话的头一句（shared themeLabel）
    static func themeLabel(_ theme: API.MeTheme) -> String {
        if let name = theme.name { return name }
        let first = theme.quotes.first?.text ?? ""
        let head = first.split(separator: /[。！？!?\n，,；;\s]/).first.map(String.init) ?? first
        return String(head.prefix(12))
    }

    private func load() async {
        do {
            page = try await model.client.meTalk()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 小词里的一张卡
private struct WordCard: View {
    let word: API.MeWord
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            Button {
                withAnimation(Web.fast) { open.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: Web.space1) {
                    MeNote(word.title)
                    Text(word.label).font(Web.body).foregroundStyle(Web.fg)
                    Text(word.value).font(Web.title).foregroundStyle(Web.fg)
                }
                .padding(Web.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(open ? "展开了" : "收着"))
            if open { DayLinks(days: word.days) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 说话的时钟：一天 24 个钟点绕成一圈（0 点在正上方，顺时针），说得越多越长；说得最多的那一段深一点
private struct TalkClock: View {
    let clock: API.MeClock
    let span: String

    var body: some View {
        Canvas { context, size in draw(context, scale: size.width / 400) }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("一天里每个钟点说了几段话：\(clock.sentence.isEmpty ? "还没说过话" : clock.sentence)"))
    }

    private func inPart(_ hour: Int) -> Bool {
        guard let part = clock.part else { return false }
        return part.to > 24 ? hour >= part.from || hour < part.to - 24 : hour >= part.from && hour < part.to
    }

    private func draw(_ context: GraphicsContext, scale: Double) {
        let at = { (radius: Double, angle: Double) in
            CGPoint(x: (200 + cos(angle) * radius) * scale, y: (200 + sin(angle) * radius) * scale)
        }
        let ring = CGRect(x: 48 * scale, y: 48 * scale, width: 304 * scale, height: 304 * scale)
        context.stroke(Path(ellipseIn: ring), with: .color(Web.line), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
        let most = Double(max(1, clock.hours.max() ?? 1))
        for (hour, count) in clock.hours.enumerated() where count > 0 {
            let angle = (Double(hour) + 0.5) / 24 * 2 * .pi - .pi / 2
            var line = Path()
            line.move(to: at(96, angle))
            line.addLine(to: at(96 + Double(count) / most * 56, angle))
            context.stroke(
                line, with: .color(inPart(hour) ? Web.fg : Web.lineStrong),
                style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
        }
        for hour in stride(from: 0, to: 24, by: 3) {
            context.draw(
                Text("\(hour)").font(Web.caption).foregroundStyle(Web.fgTertiary),
                at: at(182, Double(hour) / 24 * 2 * .pi - .pi / 2))
        }
        let middle = CGPoint(x: 200 * scale, y: 200 * scale)
        context.draw(
            Text("\(clock.total)").font(Web.title).foregroundStyle(Web.fg), at: middle, anchor: .bottom)
        context.draw(
            Text("段话 · \(span)").font(Web.caption).foregroundStyle(Web.fgTertiary),
            at: CGPoint(x: middle.x, y: middle.y + Web.space2), anchor: .top)
    }
}

/// 连锁反应：那天 → 第二天 → 第三天，一条时间线；每一步一根横条
private struct ChainCard: View {
    let chain: API.MeChain

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Show.spaced(chain.title)).font(Web.sectionSemibold).foregroundStyle(Web.fg)
                VStack(alignment: .leading, spacing: 0) {
                    step(label: "那天", dot: Web.fg, last: chain.steps.isEmpty) { MeNote(chain.first) }
                    ForEach(Array(chain.steps.enumerated()), id: \.offset) { index, item in
                        step(
                            label: item.label, dot: item.strong ? Web.status("warn") : Web.lineStrong,
                            last: index == chain.steps.count - 1
                        ) {
                            HStack(spacing: Web.space3) {
                                MeTrack(
                                    share: max(0.02, item.share),
                                    color: item.strong ? Web.status("warn") : Web.lineStrong)
                                Text("\(item.what) \(item.value)").font(Web.caption).foregroundStyle(Web.fgSecondary)
                            }
                        }
                    }
                }
                .padding(.top, Web.space4)
                MeNote(chain.sub).padding(.top, Web.space2)
            }
            .padding(.horizontal, Web.space4).padding(.top, Web.space4).padding(.bottom, Web.space1)
            DayLinks(days: chain.days).padding(.horizontal, Web.space4).padding(.bottom, Web.space4)
        }
        .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
    }

    private func step<Content: View>(label: String, dot: Color, last: Bool, @ViewBuilder content: () -> Content)
        -> some View
    {
        HStack(alignment: .top, spacing: Web.space3) {
            Circle().fill(dot).frame(width: Web.space2, height: Web.space2).padding(.top, Web.space2)
            VStack(alignment: .leading, spacing: Web.space1) {
                Text(label).font(Web.bodySemibold).foregroundStyle(Web.fg)
                content()
            }
            .padding(.bottom, last ? 0 : Web.space3)
        }
        .background(alignment: .leading) {
            if !last {
                Rectangle().fill(Web.line).frame(width: 1).padding(.leading, Web.space1 - 0.5).padding(.top, Web.space4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
