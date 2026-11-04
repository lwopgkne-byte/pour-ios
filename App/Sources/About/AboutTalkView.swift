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
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
            }
        }
        .aboutPage()
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeTalkPage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
            MeHead(title: "你说的话") {
                navigate("/about")
            } sub: {
                EmptyView()
            }
            MePanel {
                TalkClock(clock: page.clock, span: page.span).frame(maxWidth: (Theme.Space.section * 2) * 5.6).frame(
                    maxWidth: .infinity)
                if !page.clock.sentence.isEmpty {
                    Text(Show.spaced(page.clock.sentence)).font(Theme.Typeface.body).foregroundStyle(
                        Theme.Palette.label)
                }
            }
            if !page.topics.isEmpty { topics(page.topics) }
            if !page.themes.isEmpty {
                AboutCardSection(title: "主题的起落", info: "把你说过的话按意思归成几堆（在你电脑上归的，没发出去）；名字是 AI 起的，点开是那几段原话。") {
                    VStack(spacing: 0) { ForEach(page.themes, id: \.key) { theme($0) } }
                }
            }
            // 照原型：小词是一张张白卡（两列），外面不再套一张卡
            if !page.words.isEmpty { AboutCardSection(title: "小词里的你", card: false) { words(page.words) } }
            if !page.chains.isEmpty {
                AboutCardSection(title: "连锁反应") {
                    VStack(spacing: Theme.Space.medium) { ForEach(page.chains, id: \.key) { ChainCard(chain: $0) } }
                }
            }
            MeFoot()
        }
    }

    /// 这几周你在说什么：一个领域一行小曲线 + 一个词（越说越多 / 一直都在）
    private func topics(_ topics: [API.MeTopic]) -> some View {
        AboutCardSection(title: "这几周你在说什么", info: "每周说到它的段数：按你说的话算，不看花了多少时间。") {
            VStack(spacing: 0) {
                ForEach(topics, id: \.key) { topic in
                    HStack(spacing: Theme.Space.medium) {
                        HStack(spacing: Theme.Space.small) {
                            Circle().fill(Theme.tag(topic.color).solid).frame(
                                width: Theme.Space.small, height: Theme.Space.small)
                            Text(topic.name).font(Theme.Typeface.bodySemibold).foregroundStyle(
                                Theme.Palette.label)
                        }
                        .frame(minWidth: (Theme.Space.section * 2), alignment: .leading)
                        MeLine(points: topic.points, color: Theme.tag(topic.color).solid).frame(
                            height: Theme.Space.section)
                        MeNote(topic.word)
                    }
                    .frame(minHeight: (Theme.Size.touch + Theme.Space.tight))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// 一堆话：名字 + 每周几段的小曲线 + 一个词；点开是离这一堆最近的那几段原话
    private func theme(_ theme: API.MeTheme) -> some View {
        MeExpand {
            HStack(spacing: Theme.Space.medium) {
                Text(Self.themeLabel(theme)).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .lineLimit(1)
                    .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in width * 0.4 }
                MeLine(points: theme.points, color: Theme.Palette.secondaryLabel).frame(height: Theme.Space.section)
                MeNote("\(theme.notes) 段 · \(theme.word)").fixedSize()
            }
        } content: {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                MeQuotes(quotes: theme.quotes)
                DayLinks(days: theme.days)
            }
        }
    }

    /// 小词里的你：两列小卡，一句话、一个数；点开看是哪几天
    private func words(_ words: [API.MeWord]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            ForEach(Array(stride(from: 0, to: words.count, by: 2)), id: \.self) { start in
                HStack(alignment: .top, spacing: Theme.Space.medium) {
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
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Button {
                withAnimation(Theme.Motion.standard) { open.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    MeNote(word.title)
                    Text(word.label).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                    Text(word.value).font(Theme.Typeface.largeTitle).foregroundStyle(Theme.Palette.label)
                }
                .padding(Theme.Space.inset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
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
        context.stroke(
            Path(ellipseIn: ring), with: .color(Theme.Palette.separator),
            style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
        let most = Double(max(1, clock.hours.max() ?? 1))
        for (hour, count) in clock.hours.enumerated() where count > 0 {
            let angle = (Double(hour) + 0.5) / 24 * 2 * .pi - .pi / 2
            var line = Path()
            line.move(to: at(96, angle))
            line.addLine(to: at(96 + Double(count) / most * 56, angle))
            context.stroke(
                line, with: .color(inPart(hour) ? Theme.Palette.label : Theme.Palette.separator),
                style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
        }
        for hour in stride(from: 0, to: 24, by: 3) {
            context.draw(
                Text("\(hour)").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel),
                at: at(182, Double(hour) / 24 * 2 * .pi - .pi / 2))
        }
        let middle = CGPoint(x: 200 * scale, y: 200 * scale)
        context.draw(
            Text("\(clock.total)").font(Theme.Typeface.largeTitle).foregroundStyle(Theme.Palette.label), at: middle,
            anchor: .bottom)
        context.draw(
            Text("段话 · \(span)").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel),
            at: CGPoint(x: middle.x, y: middle.y + Theme.Space.small), anchor: .top)
    }
}

/// 连锁反应：那天 → 第二天 → 第三天，一条时间线；每一步一根横条
private struct ChainCard: View {
    let chain: API.MeChain

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Show.spaced(chain.title)).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                VStack(alignment: .leading, spacing: 0) {
                    step(label: "那天", dot: Theme.Palette.label, last: chain.steps.isEmpty) { MeNote(chain.first) }
                    ForEach(Array(chain.steps.enumerated()), id: \.offset) { index, item in
                        step(
                            label: item.label,
                            dot: item.strong ? Theme.Palette.status("warn") : Theme.Palette.separator,
                            last: index == chain.steps.count - 1
                        ) {
                            HStack(spacing: Theme.Space.medium) {
                                MeTrack(
                                    share: max(0.02, item.share),
                                    color: item.strong ? Theme.Palette.status("warn") : Theme.Palette.separator)
                                Text("\(item.what) \(item.value)").font(Theme.Typeface.footnote).foregroundStyle(
                                    Theme.Palette.secondaryLabel)
                            }
                        }
                    }
                }
                .padding(.top, Theme.Space.regular)
                MeNote(chain.sub).padding(.top, Theme.Space.small)
            }
            .padding(.horizontal, Theme.Space.regular).padding(.top, Theme.Space.regular).padding(
                .bottom, Theme.Space.tight)
            DayLinks(days: chain.days).padding(.horizontal, Theme.Space.regular).padding(.bottom, Theme.Space.regular)
        }
        .background(RoundedRectangle(cornerRadius: Theme.Corner.chip).fill(Theme.Palette.fill))
    }

    private func step<Content: View>(label: String, dot: Color, last: Bool, @ViewBuilder content: () -> Content)
        -> some View
    {
        HStack(alignment: .top, spacing: Theme.Space.medium) {
            Circle().fill(dot).frame(width: Theme.Space.small, height: Theme.Space.small).padding(
                .top, Theme.Space.small)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(label).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                content()
            }
            .padding(.bottom, last ? 0 : Theme.Space.medium)
        }
        .background(alignment: .leading) {
            if !last {
                Rectangle().fill(Theme.Palette.separator).frame(width: 1).padding(.leading, Theme.Space.tight - 0.5)
                    .padding(.top, Theme.Space.regular)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
