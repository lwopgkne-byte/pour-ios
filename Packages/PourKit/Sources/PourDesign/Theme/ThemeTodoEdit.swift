public import SwiftUI

// 待办 2.0 编辑弹框（docs/todo-2.0 design/after-06-edit）里的两样：「放进哪一格」的一块、日期和时间的芯片

/// 「放进哪一格」的一块（待办 2.0 编辑弹框 2×2）：高 64、圆角 14；小方块里的图标 + 名字（象限色）+ 副标题。
/// 选中：象限底色 + 2pt 象限色描边 + 右上角对勾；没选：白底、细边
public struct QuadrantChoice: View {
    let quadrant: Int
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    public init(quadrant: Int, title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) {
        self.quadrant = quadrant
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.small + Theme.Space.hairline) {
                if let symbol = Theme.Quadrant.symbol(quadrant) {
                    Image(systemName: symbol.replacingOccurrences(of: ".fill", with: ""))
                        .font(Theme.Typeface.bodySemibold)
                        .foregroundStyle(Theme.Quadrant.ring(quadrant))
                        .frame(
                            width: Theme.Size.smallRing - Theme.Space.tight,
                            height: Theme.Size.smallRing - Theme.Space.tight
                        )
                        .background(
                            selected ? Theme.Palette.card : Theme.Quadrant.tint(quadrant),
                            in: Theme.rounded(Theme.Corner.tile + Theme.Space.hairline))
                }
                // 字大了折行、块跟着变高（不缩字、不截：审计 2026-11-05）
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Quadrant.text(quadrant))
                    Text(subtitle).font(Theme.Typeface.caption).fontWeight(.regular)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Space.small)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.medium)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.choiceBlock)
            .background(
                selected ? Theme.Quadrant.tint(quadrant) : Theme.Palette.card, in: Theme.rounded(Theme.Corner.choice)
            )
            .overlay {
                Theme.rounded(Theme.Corner.choice)
                    .strokeBorder(
                        selected ? Theme.Quadrant.ring(quadrant) : Theme.Palette.separator, lineWidth: selected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark").font(Theme.Typeface.caption).foregroundStyle(
                        Theme.Quadrant.ring(quadrant)
                    )
                    .padding(Theme.Space.small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text("\(title)，\(subtitle)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 编辑弹框的芯片（日期、时间、重复）：高 36、圆角 18，选中黑底白字；可以带一个小图标（🔔 几点）
public struct EditChip: View {
    let title: String
    let symbol: String?
    let selected: Bool
    let action: () -> Void

    public init(_ title: String, symbol: String? = nil, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight) {
                if let symbol { Image(systemName: symbol).font(Theme.Typeface.footnoteSemibold) }
                Text(title).font(Theme.Typeface.subheadline).monospacedDigit()
            }
            .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.label)
            .padding(.horizontal, Theme.Space.small + Theme.Space.hairline)
            .frame(minHeight: Theme.Size.editChip)
            .background(selected ? Theme.Palette.label : Theme.Palette.fill, in: Capsule())
            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 按住一行的菜单最上面一排四个格子里的一个（待办 2.0 第 6 步，design/after-05-menu）：线条图标（象限色）+ 名字；
/// 现在在这一格：象限底色 + 2pt 象限色描边、圆角 14
public struct QuadrantPick: View {
    let quadrant: Int
    let title: String
    let selected: Bool
    let action: () -> Void

    public init(quadrant: Int, title: String, selected: Bool, action: @escaping () -> Void) {
        self.quadrant = quadrant
        self.title = title
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.tight) {
                if let symbol = Theme.Quadrant.symbol(quadrant) {
                    Image(systemName: symbol.replacingOccurrences(of: ".fill", with: ""))
                        .font(Theme.Typeface.quadrantIcon).foregroundStyle(Theme.Quadrant.ring(quadrant))
                }
                Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Quadrant.text(quadrant))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Theme.Space.small)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.choiceBlock)
            .background(selected ? Theme.Quadrant.tint(quadrant) : .clear, in: Theme.rounded(Theme.Corner.choice))
            .overlay {
                if selected {
                    Theme.rounded(Theme.Corner.choice).strokeBorder(Theme.Quadrant.ring(quadrant), lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(selected ? "\(title)，现在在这一格" : "放进\(title)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 菜单里的一行（按住一行的菜单）：图标 + 字，右边可以有一个 ›；删除是红的。按下去底色变灰
public struct MenuLine: View {
    let title: String
    let symbol: String
    let destructive: Bool
    let more: Bool
    let action: () -> Void

    public init(
        _ title: String, symbol: String, destructive: Bool = false, more: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.destructive = destructive
        self.more = more
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: symbol).font(Theme.Typeface.body)
                    .frame(width: Theme.Size.check + Theme.Space.tight)
                Text(title).font(Theme.Typeface.body)
                Spacer(minLength: 0)
                if more {
                    Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                }
            }
            .foregroundStyle(destructive ? Theme.Palette.bad : Theme.Palette.label)
            .padding(.horizontal, Theme.Space.regular + Theme.Space.tight)
            .frame(minHeight: TodoLine<EmptyView, EmptyView>.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuLineStyle())
    }
}

/// 按下去：一层浅灰
private struct MenuLineStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Theme.Palette.fill : .clear)
    }
}
