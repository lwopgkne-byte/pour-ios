import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 底部的输入框：浅底色的圆角框贴着屏幕底部；
/// 发出去就向上展开成半屏的对话面板，右边的按钮收起、展开；键盘的换行键换行，右边的蓝按钮发送
struct Composer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.visibleHeight) private var visibleHeight
    @FocusState private var focused: Bool
    @State private var drag: CGFloat = 0
    /// 斜杠命令列表有多高：对话面板让出这么多（输入框这一块往上长，对话被顶上去），
    /// 不然键盘弹着时输入框会被挤到键盘后面
    @State private var menuHeight: CGFloat = 0

    var body: some View {
        @Bindable var model = model
        let open = model.chatOpen
        VStack(spacing: 0) {
            let chatHeight = visibleHeight * 0.55 - menuHeight
            if open, chatHeight >= Web.touch {
                ChatPanel(drag: $drag)
                    .frame(height: chatHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            let commands = Show.slashMenu(model.draft)
            if !commands.isEmpty {
                SlashMenu(commands: commands) { command in
                    model.draft = "\(command.cmd) "
                    focused = true
                }
                .background(open ? Web.bg : Web.bgSubtle)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    menuHeight = $0
                }
                .onDisappear { menuHeight = 0 }
            }
            HStack(alignment: .bottom, spacing: Web.space2) {
                TextField(Show.spaced(placeholder), text: $model.draft, axis: .vertical)
                    .font(Web.body)
                    .foregroundStyle(Web.fg)
                    .lineLimit(1...6)
                    .padding(.vertical, Web.space2)
                    .focused($focused)
                    .accessibilityLabel(Text("说说今天"))
                    .accessibilityIdentifier("pourbar.input")
                Button {
                    withAnimation(Web.panel) { model.chatOpen.toggle() }
                } label: {
                    Image(systemName: open ? "chevron.down" : "bubble.left")
                        .font(Web.section).foregroundStyle(Web.fgSecondary)
                        .frame(width: Web.touch, height: Web.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(open ? "收起对话" : "展开对话"))
                .accessibilityIdentifier("pourbar.chat")
                let empty = model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    withAnimation(Web.panel) { model.send() }
                } label: {
                    Image(systemName: "arrow.up").font(Web.section.weight(.semibold)).foregroundStyle(Web.onAccent)
                        .frame(width: Web.touch, height: Web.touch)
                        .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.accent))
                        .contentShape(Rectangle())
                        .opacity(empty ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(empty)
                .accessibilityLabel(Text("发送"))
                .accessibilityIdentifier("pourbar.send")
            }
            .padding(.leading, open ? Web.space4 : Web.space3)
            .padding([.trailing, .vertical], open ? Web.space2 : Web.space1)
            .background(open ? Web.bg : Web.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: open ? 0 : Web.radiusPanel))
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Web.radiusPanel, topTrailingRadius: Web.radiusPanel))
        .offset(y: max(0, drag))
        .padding(.horizontal, open ? 0 : Web.space3)
        .padding(.top, open ? 0 : Web.space2)
        .padding(.bottom, open ? 0 : Web.space2)
        // 收起对话是要看画布：键盘一起收起来
        .onChange(of: model.chatOpen) { _, open in
            if !open { focused = false }
        }
        .background {
            Web.bg.ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { if !open { Rectangle().fill(Web.line).frame(height: 1) } }
        }
    }

    /// 白天问做了什么；晚上（6 点到日界线）换成「今天哪一刻觉得挺好？」
    private var placeholder: String {
        Show.isEvening(Date(), boundary: model.dayBoundary) ? "今天哪一刻觉得挺好？" : "今天做了什么？比如：跑步1小时"
    }
}

/// 斜杠命令：刚输入「/」时在输入框上方列出可以用的命令，点一下填进输入框；
/// 第一个是选中的样子（电脑上按回车选它）
private struct SlashMenu: View {
    let commands: [SlashCommand]
    let pick: (SlashCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(commands.enumerated()), id: \.element.cmd) { index, command in
                Button {
                    pick(command)
                } label: {
                    HStack(spacing: Web.space3) {
                        Text(command.cmd).font(Web.bodyMedium)
                        Text(command.label)
                        Spacer(minLength: 0)
                        Text(command.example).foregroundStyle(Web.fgTertiary).lineLimit(1)
                    }
                    .font(Web.body)
                    .foregroundStyle(index == 0 ? Web.fg : Web.fgSecondary)
                    .padding(.horizontal, Web.space3)
                    .frame(minHeight: Web.touch)
                    .background(
                        RoundedRectangle(cornerRadius: Web.radiusControl).fill(index == 0 ? Web.bgHover : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(command.cmd)，\(command.label)"))
                .accessibilityHint(Text("比如：\(command.example)"))
            }
        }
        .padding(Web.space1)
        .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("斜杠命令"))
    }
}
