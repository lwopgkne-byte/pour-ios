import PourAPI
import PourDesign
import SwiftUI

/*
 * 「钱」几页共用的几样：一页的开头、能点的一行、一笔钱的一行、
 * 一列（上面一条细线、每行下面一条细线）、办完一件事（带撤销）
 */

/// 子页面的开头：「‹ 钱」（点了回去）、大标题、下面一句小字
struct MoneyHead<Sub: View>: View {
    var back = "‹ 钱"
    let title: String
    let backTo: () -> Void
    @ViewBuilder var sub: () -> Sub

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            Button(back, action: backTo).buttonStyle(.plain).font(Web.caption).foregroundStyle(Web.fgTertiary)
                .tracking(Web.kickerTracking)
                .padding(.horizontal, Web.space3).frame(minHeight: Web.touch).contentShape(Rectangle())
                .padding(.leading, -Web.space3)
            Text(Show.spaced(title)).font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
            sub()
        }
    }
}

extension MoneyHead where Sub == EmptyView {
    init(back: String = "‹ 钱", title: String, backTo: @escaping () -> Void) {
        self.init(back: back, title: title, backTo: backTo) { EmptyView() }
    }
}

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

/// 一笔钱的一行：时间、名目、给谁、标签、你说的值不值（原话）、多少钱。点开是那条记录的详情
struct MoneyRow: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let item: API.MoneyItem
    let open: () -> Void

    var body: some View {
        let muted = item.kind == "reimburse" || item.kind == "lend"
        let plus = ["income", "back", "gift"].contains(item.kind)
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                Text(item.time ?? "").font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                    .fixedSize().frame(minWidth: Web.space12, alignment: .leading)
                VStack(alignment: .leading, spacing: Web.space1) {
                    PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space1) {
                        Text(Show.spaced(item.name)).font(Web.body).foregroundStyle(Web.fg)
                        if let tag = Show.kindTag(item) { MoneyTag(text: tag) }
                        if let returned = item.returned {
                            MoneyTag(text: Show.maskYuan(Show.returnedNote(returned), hide: hide))
                        }
                    }
                    // 给谁在名目下面一行
                    if !Show.whoLabel(item).isEmpty {
                        Text(Show.whoLabel(item)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                            .padding(.top, -Web.space1)
                    }
                    if let verdict = item.verdict { VerdictLine(verdict: verdict) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Show.yuan(item.amount, hide: hide, plus: plus))
                    .font(muted ? Web.body : Web.bodySemibold).foregroundStyle(muted ? Web.fgTertiary : Web.fg)
                    .monospacedDigit().fixedSize()
            }
            .padding(.vertical, Web.space3)
            .frame(minHeight: Web.space12)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: 0))
        .moneyRule()
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

/// 你说的值不值：原话用宋体，后面「你说值」（绿）、「你说后悔」（黄）
struct VerdictLine: View {
    let verdict: API.Verdict

    var body: some View {
        let good = verdict.tone == "good"
        Text(
            rich([
                .init("「\(verdict.quote)」", font: Web.quote),
                .init("  \(good ? "你说值" : "你说后悔")", font: Web.caption, color: Web.tag(good ? "green" : "yellow").fg),
            ]))
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
