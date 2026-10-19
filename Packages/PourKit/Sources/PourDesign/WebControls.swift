public import SwiftUI

/// 网页版的按钮（components/ui/Button.tsx）：primary 强调色底、secondary 白底细边、ghost 透明。
/// 手机上至少 44 点高；loading 时显示三个点、不能再点，宽度不跳
public struct WebButton: View {
    public enum Variant: Sendable {
        case primary, secondary, ghost
    }

    let title: String
    let variant: Variant
    let loading: Bool
    let disabled: Bool
    /// 占满一整行（网页版 btn-block）
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

/// 网页版的开关（components/ui/Switch.tsx）：点一下立即生效，没有「保存」。36×24 的胶囊，开是强调色；
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

/// 网页版的分段选择（.segmented）：浅灰底上几个选项，选中的白底细边、字重一点
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

/// 加载中的灰条（网页版 Skeleton）：和最后的样子差不多大，慢慢明暗
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

/// 出错了（网页版 ErrorState）：说清楚发生了什么，能重试
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
