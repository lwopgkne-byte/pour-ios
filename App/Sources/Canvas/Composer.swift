import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 底部的输入框（docs/模块/生活画布2.0.md 第 6 节）。收着对话时是浮在页面上的玻璃条（离两边 12、离底 8，56 高）：
/// 左边「对话」、中间输入（最多长到 6 行）、右边发送；上面一条玻璃小条说刚才那段话整理到哪了（ComposerStatus）。
/// 发出去就向上展开对话面板，输入框贴在面板底下（第 5 步换成系统的半屏面板）
struct Composer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.visibleHeight) private var visibleHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var drag: CGFloat = 0
    /// 斜杠命令列表有多高：对话面板让出这么多（输入框这一块往上长，对话被顶上去），
    /// 不然键盘弹着时输入框会被挤到键盘后面
    @State private var menuHeight: CGFloat = 0

    var body: some View {
        @Bindable var model = model
        let open = model.chatOpen
        VStack(spacing: open ? 0 : Theme.Space.small) {
            let chatHeight = visibleHeight * 0.55 - menuHeight
            if open, chatHeight >= Theme.Size.touch {
                ChatPanel(drag: $drag)
                    .frame(height: chatHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !open { ComposerStatus() }
            let commands = Show.slashMenu(model.draft)
            if !commands.isEmpty {
                SlashMenu(commands: commands, open: open) { command in
                    model.draft = "\(command.cmd) "
                    focused = true
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    menuHeight = $0
                }
                .onDisappear { menuHeight = 0 }
            }
            ComposerBar(focused: $focused, open: open)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: open ? Theme.Corner.card : 0, topTrailingRadius: open ? Theme.Corner.card : 0,
                style: .continuous)
        )
        .offset(y: max(0, drag))
        .padding(.horizontal, open ? 0 : Theme.Space.medium)
        .padding(.bottom, open ? 0 : Theme.Space.small)
        .background {
            if open { Theme.Palette.card.ignoresSafeArea(edges: .bottom) }
        }
        // 收起对话是要看画布：键盘一起收起来
        .onChange(of: model.chatOpen) { _, open in
            if !open { focused = false }
        }
        .animation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion), value: open)
    }
}

/// 输入的那一行：左边「对话」，中间输入，右边圆的发送按钮（有字时强调色实心，没字时浅灰）
private struct ComposerBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var focused: FocusState<Bool>.Binding
    let open: Bool

    var body: some View {
        @Bindable var model = model
        let empty = model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        HStack(alignment: .bottom, spacing: Theme.Space.tight) {
            Button {
                withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                    model.chatOpen.toggle()
                }
            } label: {
                Image(systemName: open ? "chevron.down" : "bubble.left.and.bubble.right")
                    .font(Theme.Typeface.toolbarIcon).foregroundStyle(Theme.Palette.secondaryLabel)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(open ? "收起对话" : "展开对话"))
            .accessibilityIdentifier("pourbar.chat")
            TextField(Show.spaced(placeholder), text: $model.draft, axis: .vertical)
                .font(Theme.Typeface.body)
                .foregroundStyle(Theme.Palette.label)
                .lineLimit(1...6)
                .padding(.vertical, Theme.Space.medium)
                .focused(focused)
                .accessibilityLabel(Text("说说今天"))
                .accessibilityIdentifier("pourbar.input")
            Button {
                withAnimation(Theme.Motion.pick(Theme.Motion.emphasized, reduceMotion: reduceMotion)) { model.send() }
            } label: {
                Image(systemName: "arrow.up").font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(empty ? Theme.Palette.tertiaryLabel : Theme.Palette.onAccent)
                    .frame(width: Theme.Size.sendButton, height: Theme.Size.sendButton)
                    .background(empty ? Theme.Palette.fill : Theme.Palette.accentFill, in: Circle())
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScale())
            .disabled(empty)
            .sensoryFeedback(Theme.Haptics.send, trigger: model.outbox.count) { old, new in new > old }
            .accessibilityLabel(Text("发送"))
            .accessibilityIdentifier("pourbar.send")
        }
        .padding(.horizontal, Theme.Space.tight)
        .padding(.vertical, Theme.Space.hairline)
        .frame(minHeight: Theme.Size.composer)
        .background {
            if open {
                Theme.Palette.card.overlay(alignment: .top) { Theme.Palette.separator.frame(height: 0.5) }
            }
        }
        .modifier(GlassWhenFloating(floating: !open))
    }

    /// 早上问吃了什么；白天问做了什么；晚上（6 点到日界线）问哪一刻觉得挺好
    private var placeholder: String {
        let now = Date()
        if Show.isEvening(now, boundary: model.dayBoundary) { return "今天哪一刻觉得挺好？" }
        let hour = Calendar.current.component(.hour, from: now)
        return (5..<10).contains(hour) ? "早上吃了什么？" : "今天做了什么？比如：跑步1小时"
    }
}

/// 收着对话时，输入框是浮着的玻璃
private struct GlassWhenFloating: ViewModifier {
    let floating: Bool

    func body(content: Content) -> some View {
        if floating {
            content.themeGlass(radius: Theme.Corner.composer)
        } else {
            content
        }
    }
}

/// 斜杠命令：刚输入「/」时在输入框上方浮出一张卡，每个命令一行带例子，点一下填进输入框；第一个是选中的样子
private struct SlashMenu: View {
    let commands: [SlashCommand]
    let open: Bool
    let pick: (SlashCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(commands.enumerated()), id: \.element.cmd) { index, command in
                Button {
                    pick(command)
                } label: {
                    HStack(spacing: Theme.Space.medium) {
                        Text(command.cmd).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        Text(command.label).foregroundStyle(Theme.Palette.label)
                        Spacer(minLength: 0)
                        Text(command.example).foregroundStyle(Theme.Palette.secondaryLabel).lineLimit(1)
                    }
                    .font(Theme.Typeface.subheadline)
                    .padding(.horizontal, Theme.Space.medium)
                    .frame(minHeight: Theme.Size.touch)
                    .background(index == 0 ? Theme.Palette.fill : .clear, in: Theme.rounded(Theme.Corner.chip))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(command.cmd)，\(command.label)"))
                .accessibilityHint(Text("比如：\(command.example)"))
            }
        }
        .padding(Theme.Space.tight)
        .background {
            if open { Theme.Palette.card }
        }
        .modifier(GlassCardWhenFloating(floating: !open))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("斜杠命令"))
    }
}

/// 收着对话时，斜杠命令是一张浮着的玻璃卡
private struct GlassCardWhenFloating: ViewModifier {
    let floating: Bool

    func body(content: Content) -> some View {
        if floating {
            content.themeGlass(radius: Theme.Corner.card)
        } else {
            content
        }
    }
}
