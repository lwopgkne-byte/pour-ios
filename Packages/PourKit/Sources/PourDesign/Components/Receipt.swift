public import SwiftUI

// 收据和追问（docs/归档/设计规范/08-组件.md「分子」）：一段话整理成了什么、AI 拿不准时问的一句

/// 收据里的一行记录
public struct ReceiptLine: Identifiable, Sendable {
    public let id = UUID()
    public let domain: PourDomain
    public let title: String
    /// 认出的人或地方（青色）
    public let person: String?
    /// 右侧的数（等宽）
    public let value: String?
    public let needsConfirmation: Bool
    /// 是哪条记录（点这一行打开它的详情）
    public let key: String?

    public init(
        domain: PourDomain, title: String, person: String? = nil, value: String? = nil, needsConfirmation: Bool = false,
        key: String? = nil
    ) {
        self.domain = domain
        self.title = title
        self.person = person
        self.value = value
        self.needsConfirmation = needsConfirmation
        self.key = key
    }
}

public enum ReceiptState: String, CaseIterable, Sendable {
    case organizing, waitingForNetwork, done, failed
}

/// 收据：一段话整理完，就地显示它被整理成了什么。
/// 等 AI 时说在等什么（超过 2 秒「还在整理」、超过 15 秒「网络慢……」）；没整理成说清原因、能再试一次；
/// 整理好的那一刻记录行逐张凝结（07 第 3 节：每张间隔 40 毫秒，最后一张轻轻落定，青色浅底 1.5 秒内淡出）
public struct ReceiptView: View {
    let time: String
    let quote: String
    let state: ReceiptState
    let lines: [ReceiptLine]
    let question: QuestionPrompt?
    var highlightNew: Bool
    /// 从什么时候开始等（整理中时按它换说法）
    var waitingSince: Date?
    /// 没整理成：发生了什么 + 你能做什么
    var problem: String?
    /// 整理时顺口回你的一句话（只是聊天、没有要记的时候）
    var reply: String?
    /// 这句话是程序写的（不是 AI）：不标「AI」
    var replyByProgram: Bool
    var onRetry: (() -> Void)?
    /// 刚刚整理好（看着它整理完的）：逐张凝结；打开页面时已经整理好的直接显示
    var condenses: Bool
    /// 撤销了：整理出的改动都退回去了，原话还在
    var undone: Bool
    /// 点追问的选项：当作你说了这一句
    var onAnswer: ((String) -> Void)?
    /// 点一行：打开那条记录的详情
    var onOpen: ((ReceiptLine) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Int?
    @State private var glowing = false

    public init(
        time: String, quote: String, state: ReceiptState, lines: [ReceiptLine] = [],
        question: QuestionPrompt? = nil, highlightNew: Bool = false, waitingSince: Date? = nil,
        problem: String? = nil, reply: String? = nil, replyByProgram: Bool = false, condenses: Bool = false,
        undone: Bool = false,
        onAnswer: ((String) -> Void)? = nil, onOpen: ((ReceiptLine) -> Void)? = nil, onRetry: (() -> Void)? = nil
    ) {
        self.time = time
        self.quote = quote
        self.state = state
        self.lines = lines
        self.question = question
        self.highlightNew = highlightNew
        self.waitingSince = waitingSince
        self.problem = problem
        self.reply = reply
        self.replyByProgram = replyByProgram
        self.condenses = condenses
        self.undone = undone
        self.onAnswer = onAnswer
        self.onOpen = onOpen
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                Text(time).pourText(.caption).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                Text(quote).pourText(.quote).foregroundStyle(PourColor.ink.color)
            }
            switch state {
            case .organizing:
                PourSkeleton(lines: 2)
                waitingCaption
            case .waitingForNetwork:
                Label("等网络，联网后自动整理", systemImage: "wifi.slash")
                    .pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            case .failed:
                VStack(alignment: .leading, spacing: PourSpace.tight) {
                    Text(problem ?? "没整理成").pourText(.callout).foregroundStyle(PourColor.inkSecondary.color)
                    Button("再试一次") { onRetry?() }.buttonStyle(PourButtonStyle(.text))
                        .accessibilityIdentifier("receipt.retry")
                }
            case .done where undone:
                Text("已撤销 · 原话还在").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            case .done:
                VStack(alignment: .leading, spacing: PourSpace.tight) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let visible = index < (shown ?? lines.count)
                        openable(line)
                            .opacity(visible ? 1 : 0)
                            .scaleEffect(visible || reduceMotion ? 1 : 0.96, anchor: .topLeading)
                            .offset(y: visible || reduceMotion ? 0 : 6)
                    }
                }
                if lines.isEmpty, let reply, !reply.isEmpty, replyByProgram {
                    Text(reply).pourText(.callout).foregroundStyle(PourColor.ink.color)
                } else if lines.isEmpty, let reply, !reply.isEmpty {
                    PourAIText(reply, style: .callout, color: PourColor.ink)
                } else if lines.isEmpty {
                    Text("这段话没有要记的事").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                }
                if let question { QuestionBar(prompt: question, onAnswer: onAnswer) }
            }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: state) { old, new in
            if new == .done, old != .done, condenses { condense() }
            if new == .failed, old != .failed { PourHaptic.error.play() }
        }
    }

    /// 「整理中」→ 超过 2 秒「还在整理」→ 超过 15 秒「网络慢，整理好了会自己出现」
    private var waitingCaption: some View {
        TimelineView(.periodic(from: waitingSince ?? .now, by: 1)) { context in
            let waited = waitingSince.map { context.date.timeIntervalSince($0) } ?? 0
            Text(waited > 15 ? "网络慢，整理好了会自己出现" : waited > 2 ? "还在整理" : "整理中")
                .pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
        }
    }

    /// 逐张凝结：透明 → 不透明、0.96 → 1 倍、下移 6 点归位，每张间隔 40 毫秒，最后一张用 lively 落定；
    /// 青色浅底 300 毫秒后开始淡出、1.5 秒淡完。减少动态效果时一起出现，浅底静止 2 秒后消失
    private func condense() {
        PourHaptic.success.play()
        glowing = true
        guard !reduceMotion else {
            shown = nil
            Task {
                try? await Task.sleep(for: .seconds(2))
                glowing = false
            }
            return
        }
        shown = 0
        Task {
            for index in 1...max(lines.count, 1) {
                try? await Task.sleep(for: .milliseconds(40))
                withAnimation(index == lines.count ? PourMotion.lively : PourMotion.smooth) { shown = index }
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 1.2)) { glowing = false }
            shown = nil
        }
    }

    /// 能点开详情的一行（有记录编号、给了 onOpen 时）：整行一点就开，旁白当按钮读。
    /// 不包进 Button：包进去以后系统审计说里面的字在大字号下会被截断、又指不出是哪段（M2b 实测）
    @ViewBuilder private func openable(_ line: ReceiptLine) -> some View {
        if let onOpen, line.key != nil {
            receiptLine(line)
                .contentShape(Rectangle())
                .onTapGesture { onOpen(line) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("看原话和改动"))
                .accessibilityAction { onOpen(line) }
        } else {
            receiptLine(line)
        }
    }

    private func receiptLine(_ line: ReceiptLine) -> some View {
        PourTitleValueRow {
            HStack(spacing: PourSpace.related) {
                PourDomainDot(line.domain)
                Text(line.title, person: line.person, joiner: " · ").foregroundStyle(PourColor.ink.color)
                    .pourText(.body)
            }
        } value: {
            // 「待确认」跟在数后面，排在版面里（原来用固定偏移盖在右上角，字调大时压住内容——M1 自验收）
            HStack(alignment: .firstTextBaseline, spacing: PourSpace.related) {
                if let value = line.value {
                    Text(value).pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                }
                if line.needsConfirmation {
                    Text("待确认").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, PourSpace.related)
        .background {
            RoundedRectangle.pour(PourRadius.sm)
                .fill(highlightNew || glowing ? PourColor.qingSoft.color : Color.clear)
        }
        .overlay {
            if line.needsConfirmation {
                RoundedRectangle.pour(PourRadius.sm)
                    .strokeBorder(PourColor.lineStrong.color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 一个追问：问题 + 最多 3 个选项
public struct QuestionPrompt: Sendable {
    public let question: String
    public let options: [String]

    public init(_ question: String, options: [String]) {
        self.question = question
        // 选项是按字认的（ForEach 用字当编号）：去掉重复的，不然 SwiftUI 会少显示、多显示
        var seen = Set<String>()
        self.options = Array(options.filter { seen.insert($0).inserted }.prefix(3))
    }
}

/// 追问条：凹底、左侧琥珀细条；一次只问一个。点选项就当作你说了这一句（也可以直接再说一句）
public struct QuestionBar: View {
    let prompt: QuestionPrompt
    let onAnswer: ((String) -> Void)?

    public init(prompt: QuestionPrompt, onAnswer: ((String) -> Void)? = nil) {
        self.prompt = prompt
        self.onAnswer = onAnswer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            Text(prompt.question).pourText(.callout).foregroundStyle(PourColor.ink.color)
            PourFlowLayout {
                ForEach(prompt.options, id: \.self) { option in
                    Button(option) {
                        PourHaptic.selection.play()
                        onAnswer?(option)
                    }
                    .buttonStyle(PourButtonStyle(.secondary))
                }
            }
        }
        .padding(PourSpace.element)
        .padding(.leading, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle.pour(PourRadius.md).fill(PourColor.surfaceSunken.color))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: PourRadius.md, bottomLeadingRadius: PourRadius.md, style: .continuous
            )
            .fill(PourColor.attention.color).frame(width: 3)
        }
    }
}
