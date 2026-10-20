public import SwiftUI

// 分子组件（docs/归档/设计规范/08-组件.md「分子」）。只认识显示用的值，不认识业务。

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

/// 倾倒栏（打字时）：真的能输入，和 PourBar 的「输入中」同一个样子——玻璃、圆角变大、最多长到 6 行。
/// 没字时发送是灰的（录音在 M3 接上）。占位只说「说点什么」：空闲的栏上已经给过完整的例子
public struct PourInputBar: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding, onSend: @escaping () -> Void) {
        _text = text
        self.isFocused = isFocused
        self.onSend = onSend
    }

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var body: some View {
        HStack(alignment: .bottom, spacing: PourSpace.related) {
            TextField(
                text: $text, prompt: Text("说点什么").foregroundStyle(PourColor.inkSecondary.color), axis: .vertical
            ) { Text("说点什么") }
            .pourText(.body)
            .foregroundStyle(PourColor.ink.color)
            .lineLimit(1...6)
            .focused(isFocused)
            .frame(minHeight: PourSize.minTap)
            .accessibilityIdentifier("pourbar.input")
            Button {
                PourHaptic.send.play()
                onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PourColor.onAction.color)
                    .frame(width: PourSize.sendButton, height: PourSize.sendButton)
                    .background(Circle().fill((canSend ? PourColor.action : PourColor.inkDisabled).color))
                    .frame(minWidth: PourSize.minTap, minHeight: PourSize.minTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(Text("发送"))
            .accessibilityIdentifier("pourbar.send")
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .frame(minHeight: PourSize.pourBarCollapsed)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: PourRadius.lg))
        .padding(.horizontal, PourSpace.element)
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
        // 界面测试按它找浮在底部的玻璃（和倾倒栏一样算底部的栏）
        .accessibilityIdentifier("undoToast")
    }
}
