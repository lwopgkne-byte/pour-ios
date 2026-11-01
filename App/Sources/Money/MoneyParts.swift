import PourAPI
import PourDesign
import SwiftUI

/*
 * 「关于我」那几页（第 8 步重做以前）还在用的几样：能点的一行、一列（上面一条细线、每行下面一条细线）、
 * 名字和一句小字、灰色小标签、几段拼成一句；钱办完一件事（带撤销）
 */

/// 一列：上面一条细线，每一行自己在下面画线
struct MoneyList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
    }
}

extension View {
    /// 一行下面的细线
    func moneyRule() -> some View {
        overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
    }
}

/// 能点的一行：内容在左，右边一个小箭头，下面一条细线；按下去底色变深
struct MoneyLinkRow<Label: View>: View {
    var minHeight = Web.space16
    var chevron = true
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: Web.space2) {
                label().frame(maxWidth: .infinity, alignment: .leading)
                if chevron {
                    Image(systemName: "chevron.right").font(Web.caption).foregroundStyle(Web.fgTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Web.space2)
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: 0))
        .moneyRule()
    }
}

/// 名字和钱一行、下面一句灰色小字（留意的一行、人情的一行）
struct MoneyMainSub: View {
    let main: Text
    let sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            main.font(Web.body).foregroundStyle(Web.fg)
            if let sub, !sub.isEmpty {
                Text(sub).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 灰色的小标签（「固定的」「等报销」「人情」）
struct MoneyTag: View {
    let text: String

    var body: some View {
        Text(text).font(Web.caption).foregroundStyle(Web.tag("gray").fg).fixedSize()
            .padding(.horizontal, Web.space2)
            .background(Capsule().fill(Web.tag("gray").bg))
    }
}

/// 一句话里的一段：字体、颜色（「一共送出 **¥4,066**」这种半粗的钱）
struct Segment {
    let text: String
    var font: Font = Web.body
    var color: Color = Web.fg

    init(_ text: String, font: Font = Web.body, color: Color = Web.fg) {
        self.text = text
        self.font = font
        self.color = color
    }

    /// 半粗的一段
    static func bold(_ text: String, color: Color = Web.fg) -> Segment {
        .init(text, font: Web.bodySemibold, color: color)
    }
}

/// 几段拼成一句
func rich(_ parts: [Segment]) -> AttributedString {
    parts.reduce(into: AttributedString()) { text, part in
        var piece = AttributedString(part.text)
        piece.font = part.font
        piece.foregroundColor = part.color
        text += piece
    }
}

extension AppModel {
    /// 「都报销了」「已经还了」：办完那几笔就不在「留意」里了，弹一句带「撤销」。不算「你改过的地方」
    func settle(_ refs: [API.MoneyRef], settled: Bool, said: String?) {
        moneyAct(said) { client in
            try await client.settle(refs, settled: settled)
        } undo: { [weak self] in
            self?.settle(refs, settled: !settled, said: nil)
        }
    }

    /// 「不再算固定的」（再点一次改回来）
    func endFixed(_ ref: API.MoneyRef, ended: Bool, said: String?) {
        moneyAct(said) { client in
            try await client.endFixed(ref, ended: ended)
        } undo: { [weak self] in
            self?.endFixed(ref, ended: !ended, said: nil)
        }
    }

    private func moneyAct(
        _ said: String?, _ work: @escaping @Sendable (APIClient) async throws -> Void, undo: @escaping () -> Void
    ) {
        let client = client
        Task {
            do {
                try await work(client)
                dataChanged()
                if let said { toast(said, action: "撤销", perform: undo) }
            } catch {
                toast(error.readable)
            }
        }
    }
}
