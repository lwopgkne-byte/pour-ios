public import SwiftUI

// 设置、开机密码、填表定目标用的几样控件（3.0 收尾：换掉从网页照搬的 Web 那一套）。
// 能用系统的就用系统的：按钮是系统的按钮样式，开关是系统开关，分段是系统分段

/// 按钮：primary 强调色底（系统的突出样式）、secondary 浅底、ghost 只有字。
/// loading 时字换成转圈、不能再点，宽度不跳
public struct ThemeButton: View {
    public enum Variant: Sendable {
        case primary, secondary, ghost
    }

    let title: String
    let variant: Variant
    let loading: Bool
    let disabled: Bool
    /// 占满一整行（开机的「进入」）
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
        styled(
            Button(action: action) {
                // 转圈叠在字上、字变透明：宽度和有字时一样
                Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(ink).opacity(loading ? 0 : 1)
                    .overlay { if loading { ProgressView() } }
                    .frame(maxWidth: block ? .infinity : nil)
                    // 只有字的按钮没有底，点的地方撑到 44 点高（撑在按钮里面才算数）
                    .frame(minHeight: variant == .ghost ? Theme.Size.touch : nil)
                    .contentShape(Rectangle())
            }
        )
        .controlSize(block ? .large : .regular)
        .disabled(disabled || loading)
        .accessibilityValue(Text(loading ? "正在处理" : ""))
    }

    /// 字的颜色写死：按钮放在设置的一行里时，那一行给右边的值统一了灰字，不写死会盖过系统按钮的字色
    /// （蓝底上灰字看不清，2026-11-05 走一遍时看到的「接上」「回到真实数据」）
    private var ink: Color {
        if disabled || loading { return Theme.Palette.secondaryLabel }
        return variant == .primary ? Theme.Palette.onAccent : Theme.Palette.accent
    }

    @ViewBuilder private func styled<Label: View>(_ button: Button<Label>) -> some View {
        switch variant {
        case .primary: button.buttonStyle(.borderedProminent)
        case .secondary: button.buttonStyle(.bordered)
        case .ghost: button.buttonStyle(.borderless)
        }
    }
}

/// 开关：系统开关，点一下立即生效，没有「保存」。字写在这一行别的地方，这里只给读屏
public struct ThemeSwitch: View {
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
        Toggle(label, isOn: Binding(get: { isOn }, set: { onChange($0) }))
            .labelsHidden()
            // 照原型：开关是系统那种亮绿（App 的强调色是蓝，不用在开关上）
            .tint(Theme.Palette.switchOn)
            .disabled(disabled)
    }
}

/// 分段选择：系统分段，几个选项一排
public struct ThemeSegmented: View {
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
        Picker(label, selection: Binding(get: { selected }, set: { onSelect($0) })) {
            ForEach(options, id: \.key) { option in Text(option.label).tag(option.key) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // 字写在上面一行；读屏还是要知道这一排选的是什么（「周期」）
        .accessibilityLabel(Text(label))
    }
}

/// 输入框用哪种键盘
public enum ThemeKeyboard: Sendable {
    case text, number, decimal
}

/// 输入框：上面一行小字写是什么，下面一行写提示或者哪里不对（不对时框是红的）
public struct ThemeTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    let keyboard: ThemeKeyboard
    let hint: String?
    let error: String?
    @FocusState private var focused: Bool

    public init(
        _ label: String? = nil, placeholder: String = "", text: Binding<String>, keyboard: ThemeKeyboard = .text,
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
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            if let label {
                Text(label).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            TextField(placeholder, text: $text)
                .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .themeKeyboard(keyboard)
                .focused($focused)
                .padding(.horizontal, Theme.Space.medium)
                .frame(minHeight: Theme.Size.touch)
                .background(Theme.Palette.fill, in: RoundedRectangle(cornerRadius: Theme.Corner.tile))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Corner.tile).strokeBorder(
                        error != nil ? Theme.Palette.bad : focused ? Theme.Palette.accent : .clear,
                        lineWidth: Theme.Space.hairline / 2)
                )
                .accessibilityLabel(Text(label ?? placeholder))
            if let message = error ?? hint {
                Text(message).font(Theme.Typeface.footnote)
                    .foregroundStyle(error != nil ? Theme.Palette.bad : Theme.Palette.secondaryLabel)
            }
        }
    }
}

extension View {
    fileprivate func themeKeyboard(_ keyboard: ThemeKeyboard) -> some View {
        #if os(iOS)
            keyboardType(keyboard == .number ? .numberPad : keyboard == .decimal ? .decimalPad : .default)
        #else
            self
        #endif
    }
}
