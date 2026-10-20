public import SwiftUI

// 卡片类的分子组件（docs/归档/设计规范/08-组件.md「分子」）：记录卡、原话块、发现卡、统计卡、列表行、
// 分节标题，以及空状态、骨架、出错。

// MARK: - 记录卡

/// 记录卡的种类和内容
public enum RecordContent: Sendable {
    case event(domain: PourDomain, title: String, value: String?, detail: String, person: String?)
    case money(title: String, amount: String, detail: String, tag: String?, worthQuote: String?)
    case mood(level: Int, saying: String, feeling: String?, moment: String?)
    case insight(title: String, quote: String)
    case todo(title: String, due: String?, done: Bool)
}

public enum RecordCardState: String, CaseIterable, Sendable {
    case normal, needsConfirmation, justCondensed, justChanged
}

/// 记录卡：一条记录在列表、详情里的样子
public struct RecordCard: View {
    let content: RecordContent
    let state: RecordCardState

    public init(_ content: RecordContent, state: RecordCardState = .normal) {
        self.content = content
        self.state = state
    }

    public var body: some View {
        PourCard(background: highlight ?? PourColor.surface) {
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                // 「待确认」在右上角（规范 03），排在版面里、不盖在内容上：字调大时也不会压住标题和数
                if state == .needsConfirmation {
                    Text("待确认").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                rows
            }
        }
        .overlay {
            if state == .needsConfirmation {
                RoundedRectangle.pour(PourRadius.lg)
                    .strokeBorder(PourColor.lineStrong.color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var highlight: ColorToken? {
        switch state {
        case .justCondensed: PourColor.qingSoft
        case .justChanged: PourColor.fillSelected
        default: nil
        }
    }

    @ViewBuilder private var rows: some View {
        switch content {
        case let .event(domain, title, value, detail, person):
            PourTitleValueRow {
                HStack(spacing: PourSpace.related) {
                    PourDomainDot(domain)
                    Text(title).pourText(.headline).foregroundStyle(PourColor.ink.color)
                }
            } value: {
                if let value {
                    Text(value).pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                }
            }
            Text(detail, person: person).foregroundStyle(PourColor.inkSecondary.color)
                .pourText(.meta)
        case let .money(title, amount, detail, tag, worthQuote):
            PourTitleValueRow {
                // 名字和标签放得下就一行，放不下（大字号）就上下两行：标签不被挤成一个字一行
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PourSpace.related) {
                        Text(title).pourText(.headline).foregroundStyle(PourColor.ink.color)
                        if let tag { PourInfoChip(tag) }
                    }
                    VStack(alignment: .leading, spacing: PourSpace.tight) {
                        Text(title).pourText(.headline).foregroundStyle(PourColor.ink.color)
                        if let tag { PourInfoChip(tag) }
                    }
                }
            } value: {
                Text(amount).pourText(.headline).monospacedDigit().foregroundStyle(PourColor.ink.color)
            }
            Text(detail).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
            if let worthQuote {
                Text("「\(worthQuote)」").pourText(.quote).foregroundStyle(PourColor.ink.color).lineLimit(1)
            }
        case let .mood(level, saying, feeling, moment):
            HStack(spacing: PourSpace.related) {
                PourMoodCell(level: level)
                Text(saying).pourText(.headline).foregroundStyle(PourColor.ink.color)
                if let feeling { Text(feeling).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color) }
            }
            if let moment { Text(moment).pourText(.quote).foregroundStyle(PourColor.ink.color) }
        case let .insight(title, quote):
            Label {
                Text(title).pourText(.headline).foregroundStyle(PourColor.ink.color)
            } icon: {
                Image(systemName: "lightbulb").foregroundStyle(PourColor.inkSecondary.color)
            }
            Text(quote).pourText(.quote).foregroundStyle(PourColor.ink.color).lineLimit(3)
        case let .todo(title, due, done):
            HStack(spacing: PourSpace.related) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle((done ? PourColor.inkSecondary : PourColor.ink).color)
                Text(title).pourText(.body).strikethrough(done)
                    .foregroundStyle((done ? PourColor.inkSecondary : PourColor.ink).color)
            }
            if let due { Text(due).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color) }
        }
    }
}

// MARK: - 原话块

/// 原话块：原话之声、左侧 2 点细线、上方一行来源；对应这条记录的那一段用荧光
public struct QuoteBlock: View {
    let source: String
    let quote: String
    /// 要荧光高亮的那一段（必须是原话里的原文）
    let highlight: String?

    public init(source: String, quote: String, highlight: String? = nil) {
        self.source = source
        self.quote = quote
        self.highlight = highlight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            Text(source).pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            Text(attributedQuote).pourText(.quote).foregroundStyle(PourColor.ink.color)
                // 荧光只是颜色，看不见的人也要知道标的是哪一段
                .accessibilityValue(highlight.map { Text("标出的是：\($0)") } ?? Text(verbatim: ""))
        }
        .padding(.leading, PourSpace.element)
        .overlay(alignment: .leading) { Rectangle().fill(PourColor.line.color).frame(width: 2) }
    }

    private var attributedQuote: AttributedString {
        var text = AttributedString(quote)
        if let highlight, let range = text.range(of: highlight) {
            text[range].backgroundColor = PourColor.marker.color
        }
        return text
    }
}

// MARK: - 发现卡、统计卡

/// 发现卡：青浅底；那一句 → 两根对比横条 → 根据 → 反馈
public struct DiscoveryCard: View {
    let sentence: String
    let these: Double
    let others: Double
    let basis: String
    @State private var feedback: String?

    public init(sentence: String, these: Double, others: Double, basis: String) {
        self.sentence = sentence
        self.these = these
        self.others = others
        self.basis = basis
    }

    public var body: some View {
        PourCard(background: PourColor.qingSoft) {
            VStack(alignment: .leading, spacing: PourSpace.element) {
                Text(sentence).pourText(.quoteLead).foregroundStyle(PourColor.ink.color)
                PourCompareBars(theseLabel: "这些日子", these: these, othersLabel: "别的日子", others: others)
                Text(basis).pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                // 一行放不下就换行：大字号时每个按钮按自己的宽度，不挤成一个字一行
                PourFlowLayout(spacing: PourSpace.tight, lineSpacing: PourSpace.tight) {
                    ForEach(["说中了", "早知道", "没意思", "不对"], id: \.self) { option in
                        Button(option) {
                            PourHaptic.selection.play()
                            feedback = option
                        }
                        .buttonStyle(PourButtonStyle(.text))
                        .fontWeight(feedback == option ? .semibold : .regular)
                        .padding(.horizontal, PourSpace.tight)
                    }
                }
            }
        }
    }
}

/// 统计卡（「换个角度」的两列小卡）：标题 → 主数字 → 一句结论 → 迷你图
public struct StatCard<Chart: View>: View {
    let title: String
    let value: String
    let conclusion: String
    let chart: Chart

    public init(title: String, value: String, conclusion: String, @ViewBuilder chart: () -> Chart) {
        self.title = title
        self.value = value
        self.conclusion = conclusion
        self.chart = chart()
    }

    public var body: some View {
        PourCard {
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                Text(title).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                Text(value).pourText(.display).monospacedDigit().foregroundStyle(PourColor.ink.color)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(conclusion).pourText(.callout).foregroundStyle(PourColor.ink.color)
                chart.frame(minHeight: PourSize.miniChartHeight).padding(.top, PourSpace.tight)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 列表行、分节标题

public struct PourListRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let subtitle: String?
    let value: String?
    let domain: PourDomain?
    let showsChevron: Bool

    public init(
        _ title: String, subtitle: String? = nil, value: String? = nil, domain: PourDomain? = nil,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.domain = domain
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(spacing: PourSpace.element) {
            if let domain { PourDomainDot(domain).frame(width: 28) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).pourText(.body).foregroundStyle(PourColor.ink.color)
                if let subtitle { Text(subtitle).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color) }
                // 大字号：数值放到名字下面（规范 11 第 2 节）
                if dynamicTypeSize.isAccessibilitySize, let value {
                    Text(value).pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                }
            }
            Spacer(minLength: PourSpace.related)
            if !dynamicTypeSize.isAccessibilitySize, let value {
                Text(value).pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.system(PourIconSize.small)).foregroundStyle(
                    PourColor.inkTertiary.color)
            }
        }
        .frame(minHeight: subtitle == nil ? PourSize.rowSingle : PourSize.rowDouble)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

public struct PourSectionHeader: View {
    let title: String
    let actionTitle: String?

    public init(_ title: String, actionTitle: String? = nil) {
        self.title = title
        self.actionTitle = actionTitle
    }

    public var body: some View {
        HStack {
            Text(title).pourText(.titleSection).foregroundStyle(PourColor.ink.color).accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle { Button(actionTitle) {}.buttonStyle(PourButtonStyle(.text)) }
        }
        .padding(.top, PourSpace.section)
        .padding(.bottom, PourSpace.element)
    }
}

// MARK: - 空状态、骨架、出错

/// 空状态：符号 → 一句话 → 一个能照着说的例子 → 可选的文字按钮。放在内容区上三分之一
public struct PourEmptyState: View {
    let systemImage: String
    let title: String
    let example: String
    let actionTitle: String?

    public init(systemImage: String, title: String, example: String, actionTitle: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.example = example
        self.actionTitle = actionTitle
    }

    public var body: some View {
        VStack(spacing: PourSpace.element) {
            Image(systemName: systemImage).font(.system(size: PourIconSize.display)).foregroundStyle(
                PourColor.inkTertiary.color
            )
            .accessibilityHidden(true)
            Text(title).pourText(.headline).foregroundStyle(PourColor.ink.color)
            Text("比如说「\(example)」").pourText(.quote).foregroundStyle(PourColor.inkSecondary.color)
            if let actionTitle { Button(actionTitle) {}.buttonStyle(PourButtonStyle(.text)) }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, PourSpace.section * 2)
    }
}

/// 骨架占位：和真实内容同样的形状，微光从左往右扫过；减少动态效果时静止
public struct PourSkeleton: View {
    let lines: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public init(lines: Int = 2) { self.lines = lines }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            ForEach(0..<lines, id: \.self) { index in
                RoundedRectangle.pour(PourRadius.sm)
                    .fill(PourColor.surfaceSunken.color)
                    .frame(height: 14)
                    .frame(maxWidth: index == lines - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .overlay {
            if !reduceMotion {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, PourColor.surface.color.opacity(0.6), .clear], startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width / 2)
                    .offset(x: phase * proxy.size.width)
                }
                .mask {
                    VStack(alignment: .leading, spacing: PourSpace.related) {
                        ForEach(0..<lines, id: \.self) { _ in Rectangle().frame(height: 14) }
                    }
                }
                .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1.5 } }
            }
        }
        .accessibilityLabel(Text("正在加载"))
    }
}

/// 出错：一句话说清发生了什么 + 你能做什么 + 「再试一次」。不用红色、不用感叹号、不写错误码
public struct PourErrorView: View {
    let message: String
    let retry: () -> Void

    public init(_ message: String, retry: @escaping () -> Void = {}) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            Text(message).pourText(.callout).foregroundStyle(PourColor.ink.color)
            Button("再试一次", action: retry).buttonStyle(PourButtonStyle(.text))
        }
    }
}
