public import SwiftUI

/// 按钮：primary 强调色底、secondary 白底细边、ghost 透明。
/// 手机上至少 44 点高；loading 时显示三个点、不能再点，宽度不跳
public struct WebButton: View {
    public enum Variant: Sendable {
        case primary, secondary, ghost
    }

    let title: String
    let variant: Variant
    let loading: Bool
    let disabled: Bool
    /// 占满一整行
    let block: Bool
    let action: () -> Void

    public init(
        _ title: String, variant: Variant = .secondary, loading: Bool = false, disabled: Bool = false,
        block: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.loading = loading
        self.disabled = disabled
        self.block = block
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // 三个点叠在字上、字变透明：宽度和有字时一样
            Text(title).font(Web.bodyMedium).opacity(loading ? 0 : 1)
                .overlay { if loading { Dots(label: "\(title)，正在处理") } }
                .padding(.horizontal, Web.space3)
                .frame(maxWidth: block ? .infinity : nil, minHeight: Web.touch)
        }
        .buttonStyle(WebButtonStyle(variant: variant))
        .disabled(disabled || loading)
    }
}

private struct WebButtonStyle: ButtonStyle {
    let variant: WebButton.Variant
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(foreground)
            .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(background(pressed: pressed)))
            .overlay {
                if variant == .secondary {
                    RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(Web.line, lineWidth: 1)
                }
            }
            .opacity(enabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: Web.radiusControl))
    }

    private var foreground: Color {
        switch variant {
        case .primary: Web.onAccent
        case .secondary: Web.fg
        case .ghost: Web.fgSecondary
        }
    }

    private func background(pressed: Bool) -> Color {
        switch variant {
        case .primary: pressed ? Web.accentPressed : Web.accent
        case .secondary: pressed ? Web.bgPressed : Web.bg
        case .ghost: pressed ? Web.bgPressed : .clear
        }
    }
}

/// 开关：点一下立即生效，没有「保存」。36×24 的胶囊，开是强调色；
/// 能点的范围撑到 44 点高
public struct WebSwitch: View {
    let label: String
    let isOn: Bool
    let disabled: Bool
    let onChange: (Bool) -> Void

    public init(_ label: String, isOn: Bool, disabled: Bool = false, onChange: @escaping (Bool) -> Void) {
        self.label = label
        self.isOn = isOn
        self.disabled = disabled
        self.onChange = onChange
    }

    public var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            Capsule().fill(isOn ? Web.accent : Web.lineStrong)
                .frame(width: Web.space8 + Web.space1, height: Web.space6)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(Web.bg)
                        .frame(width: Web.space6 - Web.space1, height: Web.space6 - Web.space1)
                        .shadow(color: Web.shadow, radius: Web.space1, y: Web.space1 / 2)
                        .padding(Web.space1 / 2)
                }
                .frame(minHeight: Web.touch)
                .contentShape(Rectangle())
                .animation(Web.fast, value: isOn)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(isOn ? "开" : "关"))
        .accessibilityAddTraits(.isToggle)
    }
}

/// 分段选择：浅灰底上几个选项，选中的白底细边、字重一点
public struct WebSegmented: View {
    let label: String
    let options: [(key: String, label: String)]
    let selected: String
    let onSelect: (String) -> Void

    public init(
        _ label: String, options: [(key: String, label: String)], selected: String,
        onSelect: @escaping (String) -> Void
    ) {
        self.label = label
        self.options = options
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: Web.space1) {
            ForEach(options, id: \.key) { option in
                let current = option.key == selected
                Button {
                    onSelect(option.key)
                } label: {
                    Text(option.label).font(current ? Web.bodyMedium : Web.body)
                        .foregroundStyle(current ? Web.fg : Web.fgSecondary)
                        .padding(.horizontal, Web.space3)
                        .frame(minHeight: Web.control)
                        .background {
                            if current {
                                RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                                            Web.line, lineWidth: 1))
                            }
                        }
                        .frame(minHeight: Web.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(current ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, Web.space1)
        // 浅灰底比选项高出上下各 4 点（选项看得见的是 32 点高，能点的是 44 点）
        .background(
            RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bgSubtle)
                .padding(.vertical, (Web.touch - Web.control) / 2 - Web.space1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }
}

/// 加载中的灰条：和最后的样子差不多大，慢慢明暗
public struct WebSkeleton: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var dim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(width: CGFloat? = nil, height: CGFloat = Web.space4) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bgHover)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(dim ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Web.pulse) { dim = true }
            }
            .accessibilityHidden(true)
    }
}

/// 出错了：说清楚发生了什么，能重试
public struct WebErrorState: View {
    let message: String
    let retry: (() -> Void)?

    public init(_ message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            Text(message).font(Web.body).foregroundStyle(Web.fgSecondary)
            if let retry { WebTextButton("重试", action: retry) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 小标签按钮（类别、筛选）：白底细边的胶囊，选中的边深一点、字深一点；手机上至少 32 点高、能点的 44 点
public struct WebChip<Label: View>: View {
    /// 系统的无障碍审计认它：类别小标签前面是彩色的表情（图，不是字），量对比度不准
    public static var identifier: String { "webChip" }
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    public init(selected: Bool, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.selected = selected
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(action: action) {
            // 读屏、审计都只当成一个按钮（里面的表情和字不再各算一个）
            HStack(spacing: Web.space1) { label() }
                .accessibilityElement(children: .combine)
                .font(Web.caption)
                .foregroundStyle(selected ? Web.fg : Web.fgSecondary)
                .padding(.horizontal, Web.space3)
                .frame(minHeight: Web.control)
                .background(Capsule().fill(Web.bg))
                .overlay(Capsule().strokeBorder(selected ? Web.fgTertiary : Web.line, lineWidth: 1))
                .padding(.vertical, (Web.touch - Web.control) / 2)
                .contentShape(Rectangle())
                .padding(.vertical, -(Web.touch - Web.control) / 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier(Self.identifier)
    }
}

/// 输入框：上面一行小标题，白底细边的框，下面一句说明或者出错的话
public struct WebTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    let keyboard: WebKeyboard
    let hint: String?
    let error: String?
    @FocusState private var focused: Bool

    public init(
        _ label: String? = nil, placeholder: String = "", text: Binding<String>, keyboard: WebKeyboard = .text,
        hint: String? = nil, error: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.keyboard = keyboard
        self.hint = hint
        self.error = error
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            if let label {
                Text(label).font(Web.captionMedium).foregroundStyle(Web.fgSecondary)
            }
            TextField(placeholder, text: $text)
                .font(Web.body).foregroundStyle(Web.fg)
                .webKeyboard(keyboard)
                .focused($focused)
                .padding(.horizontal, Web.space2)
                .frame(minHeight: Web.touch)
                .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bg))
                .overlay(
                    RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                        error != nil ? Web.danger : focused ? Web.accent : Web.line, lineWidth: 1)
                )
                .accessibilityLabel(Text(label ?? placeholder))
            if let message = error ?? hint {
                Text(message).font(Web.caption).foregroundStyle(error != nil ? Web.danger : Web.fgTertiary)
            }
        }
    }
}

/// 输入框用哪种键盘
public enum WebKeyboard: Sendable {
    case text, number, decimal
}

extension View {
    fileprivate func webKeyboard(_ keyboard: WebKeyboard) -> some View {
        #if os(iOS)
            keyboardType(keyboard == .number ? .numberPad : keyboard == .decimal ? .decimalPad : .default)
        #else
            self
        #endif
    }
}
