public import SwiftUI

/// 记一笔的数字键盘（06 交互细节 3.4）：自己画——大按键、按下变灰、每一下轻轻一震；删除键在右下
public struct NumberKeypad: View {
    public enum Key: Hashable, Sendable {
        case digit(Int)
        case dot
        case delete
    }

    let press: (Key) -> Void
    @State private var taps = 0

    public init(press: @escaping (Key) -> Void) {
        self.press = press
    }

    private static let rows: [[Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.dot, .digit(0), .delete],
    ]

    public var body: some View {
        Grid(horizontalSpacing: Theme.Space.small, verticalSpacing: Theme.Space.small) {
            ForEach(Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            taps += 1
                            press(key)
                        } label: {
                            label(key)
                                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(KeyStyle())
                        .accessibilityLabel(Text(spoken(key)))
                        .accessibilityIdentifier("keypad.\(spoken(key))")
                    }
                }
            }
        }
        .keypadFeedback(taps)
    }

    @ViewBuilder private func label(_ key: Key) -> some View {
        switch key {
        case .digit(let number):
            Text("\(number)").font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.label)
        case .dot:
            Text(".").font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.label)
        case .delete:
            Image(systemName: "delete.left").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
        }
    }

    private func spoken(_ key: Key) -> String {
        switch key {
        case .digit(let number): "\(number)"
        case .dot: "点"
        case .delete: "删掉一位"
        }
    }
}

/// 按键：白底圆角，按下变灰
private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Theme.Palette.fill : Theme.Palette.card,
                in: Theme.rounded(Theme.Corner.hubTile))
    }
}

extension View {
    /// 每按一下轻轻一震（数字键盘）
    fileprivate func keypadFeedback(_ taps: Int) -> some View {
        #if os(iOS)
            sensoryFeedback(Theme.Haptics.keypad, trigger: taps)
        #else
            self
        #endif
    }
}

/// 键盘按下去以后的金额（「25」「12.5」）：最多两位小数、整数最多 7 位，只能有一个点，开头的 0 不重复
public enum KeypadAmount {
    public static func apply(_ key: NumberKeypad.Key, to text: String) -> String {
        switch key {
        case .delete:
            return String(text.dropLast())
        case .dot:
            if text.contains(".") { return text }
            return text.isEmpty ? "0." : text + "."
        case .digit(let number):
            if let dot = text.firstIndex(of: ".") {
                return text[text.index(after: dot)...].count >= 2 ? text : text + "\(number)"
            }
            if text == "0" { return "\(number)" }
            return text.count >= 7 ? text : text + "\(number)"
        }
    }
}

#Preview("数字键盘") {
    @Previewable @State var amount = ""
    VStack(spacing: Theme.Space.regular) {
        Text("¥\(amount.isEmpty ? "0" : amount)").font(Theme.Typeface.bigNumber).monospacedDigit()
        NumberKeypad { amount = KeypadAmount.apply($0, to: amount) }
    }
    .padding()
    .background(Theme.Palette.background)
}
