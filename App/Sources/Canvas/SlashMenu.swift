import PourAPI
import PourDesign
import SwiftUI

/// 斜杠命令：刚输入「/」时在输入框上方浮出一张卡，每个命令一行带例子，点一下填进输入框；第一个是选中的样子
struct SlashMenu: View {
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
            if open { Theme.rounded(Theme.Corner.chip).fill(Theme.Palette.sheet) }
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
