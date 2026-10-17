public import SwiftUI

// 分子组件（docs/设计规范/08-组件.md「分子」）。只认识显示用的值，不认识业务。

// MARK: - 倾倒栏（全 App 最重要的组件）

/// 倾倒栏的状态。M1 只做样子和状态；输入、录音的逻辑在 M2、M3。
public enum PourBarState: String, CaseIterable, Sendable {
    case idle, typing, recording, sending
}

/// 倾倒栏：Liquid Glass 胶囊，常驻在标签栏上方。左边输入，右边没字是话筒、有字是发送。
public struct PourBar: View {
    let state: PourBarState
    let text: String
    let placeholder: String
    let recordingSeconds: Int
    var onSend: () -> Void = {}
    @Namespace private var glass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        state: PourBarState, text: String = "", placeholder: String = "今天做了什么？比如：8 点跑了 5 公里",
        recordingSeconds: Int = 0, onSend: @escaping () -> Void = {}
    ) {
        self.state = state
        self.text = text
        self.placeholder = placeholder
        self.recordingSeconds = recordingSeconds
        self.onSend = onSend
    }

    public var body: some View {
        GlassEffectContainer(spacing: PourSpace.related) {
            HStack(spacing: PourSpace.related) {
                if state == .recording {
                    recordingContent
                } else {
                    Group {
                        if text.isEmpty {
                            PourBarPlaceholder(placeholder)
                        } else {
                            Text(text).foregroundStyle(PourColor.ink.color)
                                .lineLimit(state == .typing ? 6 : 1)
                        }
                    }
                    .pourText(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    trailingButton
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .frame(minHeight: PourSize.pourBarCollapsed)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: state == .typing ? PourRadius.lg : 26))
            .glassEffectID("bar", in: glass)
        }
        .padding(.horizontal, PourSpace.element)
    }

    @ViewBuilder private var trailingButton: some View {
        if state == .sending {
            ProgressView().frame(width: PourSize.sendButton, height: PourSize.sendButton)
                .frame(minWidth: PourSize.minTap, minHeight: PourSize.minTap)
        } else if text.isEmpty {
            Image(systemName: "mic")
                .font(.system(PourIconSize.large))
                .foregroundStyle(PourColor.inkSecondary.color)
                .frame(minWidth: PourSize.minTap, minHeight: PourSize.minTap)
                .accessibilityLabel(Text("按住说话，或轻点两下开始录音"))
        } else {
            Button {
                PourHaptic.send.play()
                onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PourColor.onAction.color)
                    .frame(width: PourSize.sendButton, height: PourSize.sendButton)
                    .background(Circle().fill(PourColor.action.color))
                    .frame(minWidth: PourSize.minTap, minHeight: PourSize.minTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("发送"))
        }
    }

    /// 录音中：波形和计时永远一行（计时不许折成「0:0 / 3」）；大字号时提示换到下一行，不挤成一个字一行
    private var recordingContent: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PourSpace.tight))
            : AnyLayout(HStackLayout(spacing: PourSpace.related))
        return layout {
            HStack(spacing: PourSpace.related) {
                Image(systemName: "waveform").symbolEffect(.variableColor.iterative)
                    .foregroundStyle(PourColor.ink.color)
                Text(verbatim: String(format: "0:%02d", recordingSeconds)).pourText(.body).monospacedDigit()
                    .foregroundStyle(PourColor.ink.color)
                    .fixedSize()
            }
            if !stacked { Spacer(minLength: PourSpace.related) }
            Text("松开发送 · 上滑取消").pourText(.callout).foregroundStyle(PourColor.inkSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: PourSize.minTap, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("正在录音，\(recordingSeconds) 秒"))
    }
}

/// 倾倒栏的占位：放得下就给完整的例子，放不下（窄屏、大字号、收起的小栏）就只说「说点什么」——永远不截断
public struct PourBarPlaceholder: View {
    let example: String

    public init(_ example: String = "今天做了什么？比如：8 点跑了 5 公里") { self.example = example }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(example).lineLimit(1)
            Text("说点什么").lineLimit(1)
        }
        .pourText(.body)
        .foregroundStyle(PourColor.inkSecondary.color)
    }
}

// MARK: - 收据

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

    public init(
        domain: PourDomain, title: String, person: String? = nil, value: String? = nil, needsConfirmation: Bool = false
    ) {
        self.domain = domain
        self.title = title
        self.person = person
        self.value = value
        self.needsConfirmation = needsConfirmation
    }
}

public enum ReceiptState: String, CaseIterable, Sendable {
    case organizing, waitingForNetwork, done, failed
}

/// 收据：一段话整理完，就地显示它被整理成了什么
public struct ReceiptView: View {
    let time: String
    let quote: String
    let state: ReceiptState
    let lines: [ReceiptLine]
    let question: QuestionPrompt?
    var highlightNew: Bool

    public init(
        time: String, quote: String, state: ReceiptState, lines: [ReceiptLine] = [],
        question: QuestionPrompt? = nil, highlightNew: Bool = false
    ) {
        self.time = time
        self.quote = quote
        self.state = state
        self.lines = lines
        self.question = question
        self.highlightNew = highlightNew
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
                Text("整理中").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            case .waitingForNetwork:
                Label("等网络，联网后自动整理", systemImage: "wifi.slash")
                    .pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            case .failed:
                PourFlowLayout {
                    Text("没整理成").pourText(.callout).foregroundStyle(PourColor.inkSecondary.color)
                    Button("再试一次") {}.buttonStyle(PourButtonStyle(.text))
                }
            case .done:
                VStack(alignment: .leading, spacing: PourSpace.tight) {
                    ForEach(lines) { line in receiptLine(line) }
                }
                if let question { QuestionBar(prompt: question) }
            }
        }
        .accessibilityElement(children: .contain)
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
                .fill(highlightNew ? PourColor.qingSoft.color : Color.clear)
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

/// 追问条：凹底、左侧琥珀细条；一次只问一个
public struct QuestionBar: View {
    let prompt: QuestionPrompt

    public init(prompt: QuestionPrompt) { self.prompt = prompt }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            Text(prompt.question).pourText(.callout).foregroundStyle(PourColor.ink.color)
            PourFlowLayout {
                ForEach(prompt.options, id: \.self) { option in
                    Button(option) { PourHaptic.selection.play() }.buttonStyle(PourButtonStyle(.secondary))
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

// MARK: - 撤销条、轻提示

/// 撤销条：玻璃胶囊，5 秒后自己消失（由页面控制）；旁白自动播报
public struct UndoToast: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    public init(_ message: String, actionTitle: String = "撤销", action: @escaping () -> Void = {}) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: PourSpace.element) {
            Text(message).pourText(.callout).foregroundStyle(PourColor.ink.color)
            Button(actionTitle, action: action).buttonStyle(PourButtonStyle(.text))
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(minHeight: PourSize.minTap)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
