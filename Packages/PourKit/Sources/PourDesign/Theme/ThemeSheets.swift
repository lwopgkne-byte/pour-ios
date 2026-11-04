public import SwiftUI

// 弹层的头和按钮（照可交互原型 1:1：.shead、.closex、头上右边的胶囊主按钮）

/// 照原型 .shead 的弹层头（记一笔、记心情、记一句、加待办）：左边大一号的粗体名字，右边灰圆的关闭或一个胶囊按钮；
/// 拖动条用系统的。和「说一句」的头一样（ChatPanel）
public struct LeadingSheetHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Theme.Space.small) {
            Text(title).font(Theme.Typeface.sheetTitle).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.top, Theme.Space.small)
    }
}

/// 弹层右上角灰圆的关闭（原型 .closex：一个小圆，点的范围 44）
public struct SheetCloseButton: View {
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.label)
                .frame(width: Theme.Size.smallRing, height: Theme.Size.smallRing)
                .background(Theme.Palette.fillStrong, in: Circle())
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("关闭"))
        .accessibilityIdentifier("sheet.close")
    }
}

/// 弹层头上右边的胶囊主按钮（记一句的「记下」、加待办的「加上」）：那一块的颜色、白字；还不能点时是灰的
public struct SheetPillButton: View {
    let title: String
    let color: Color
    let enabled: Bool
    let action: () -> Void

    public init(_ title: String, color: Color, enabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).font(Theme.Typeface.bodySemibold)
                .foregroundStyle(enabled ? Theme.Palette.onAccent : Theme.Palette.tertiaryLabel)
                .padding(.horizontal, Theme.Space.regular)
                .frame(minHeight: Theme.Size.capsule)
                .background(enabled ? color : Theme.Palette.fill, in: Capsule())
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
    }
}
