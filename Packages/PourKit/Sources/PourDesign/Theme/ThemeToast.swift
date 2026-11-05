public import SwiftUI

/// 轻提示（照原型 .toast）：一条深色的圆角条，左右和底下的输入框一样宽；白字一句话，右边可以有一个半透明白底的
/// 「撤销」小胶囊；4 秒后自己消失（AppModel 管时间）。以前是玻璃的，后面的字透上来看不清
public struct ThemeToast: View {
    let message: String
    let action: String?
    let perform: () -> Void

    public init(_ message: String, action: String? = nil, perform: @escaping () -> Void = {}) {
        self.message = message
        self.action = action
        self.perform = perform
    }

    public var body: some View {
        HStack(spacing: Theme.Space.small) {
            Text(message).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.onAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                // 看得见的胶囊 32 高；点的地方撑在按钮里面 44（撑在外面读屏和审计还是按字的大小算）
                Button(action: perform) {
                    Text(action).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.onAccent)
                        .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                        .background(Theme.Palette.onAccent.opacity(0.14), in: Capsule())
                        .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("undoToast")
            }
        }
        .padding(.leading, Theme.Space.regular).padding(.trailing, Theme.Space.tight)
        .padding(.vertical, Theme.Space.hairline)
        .frame(minHeight: Theme.Size.touch + Theme.Space.small)
        .background(Theme.Palette.toast, in: Theme.rounded(Theme.Corner.stat))
        .shadow(color: Color.black.opacity(0.25), radius: Theme.Space.regular, y: Theme.Space.small)
        .padding(.horizontal, Theme.Space.regular)
    }
}
