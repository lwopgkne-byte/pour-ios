import PourAPI
import PourDesign
import SwiftUI

/// 自动检查（网页版 review/AuditFindings.tsx，docs/prd-auto-improve.md 第 ① 步）：「还没收尾的」里的一行
/// 「自动检查发现 2 处可能整理错了」，点开看每一处：原话（有问题的那一段标出来）、当时整理成什么、应该是什么、为什么。
/// 「确实错了」按审核员的改法改好、记进「你改过的地方」；「没错」算审核员看错了。都能撤销。没查出来就不出现
struct AuditFindingsView: View {
    @Environment(AppModel.self) private var model
    let findings: [API.AuditFinding]
    let reload: () async -> Void
    @State private var open = false
    @State private var busy: Int?

    var body: some View {
        if !findings.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(Web.fast) { open.toggle() }
                } label: {
                    HStack(spacing: Web.space3) {
                        // 虚线的点：是「可能」整理错了
                        OpenDot(pending: true)
                        Text("自动检查发现 \(findings.count) 处可能整理错了").font(Web.body).foregroundStyle(Web.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down").font(Web.caption).foregroundStyle(Web.fgTertiary)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .frame(minHeight: Web.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                .accessibilityValue(Text(open ? "展开了" : "收着"))
                if open {
                    VStack(alignment: .leading, spacing: Web.space6) { ForEach(findings) { item($0) } }
                        .padding(.top, Web.space2).padding(.bottom, Web.space4)
                }
            }
        }
    }

    private func item(_ finding: API.AuditFinding) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(quote(finding)).font(Web.body).foregroundStyle(Web.fg)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Web.space3, verticalSpacing: Web.space1) {
                line("整理成", finding.before.joined(separator: " · "), Web.fgSecondary)
                if let after = finding.after { line("应该是", after.joined(separator: " · "), Web.fg) }
                line("为什么", finding.reason, Web.fgSecondary)
            }
            .padding(.top, Web.space2)
            HStack(spacing: Web.space4) {
                if busy == finding.id {
                    Dots(label: "正在处理").foregroundStyle(Web.accent).frame(minHeight: Web.touch)
                } else {
                    WebTextButton("确实错了") { confirm(finding) }
                    WebTextButton("没错") { dismiss(finding) }
                }
            }
            .padding(.top, Web.space3)
        }
    }

    private func line(_ name: String, _ value: String, _ color: Color) -> some View {
        GridRow {
            Text(name).font(Web.caption).foregroundStyle(Web.fgTertiary)
            Text(Show.spaced(value)).font(Web.body).foregroundStyle(color).frame(
                maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 原话里有问题的那一段只加粗、加一条浅下划线，不用颜色（对不上就原样）
    private func quote(_ finding: API.AuditFinding) -> AttributedString {
        var text = AttributedString("「\(finding.text)」")
        if let range = text.range(of: finding.quote) {
            text[range].font = Web.bodySemibold
            text[range].underlineStyle = .single
            text[range].underlineColor = UIColor(Web.lineStrong)
        }
        return text
    }

    private func confirm(_ finding: API.AuditFinding) {
        act(finding) { client in
            let result = try await client.confirmFinding(finding.id)
            await finish()
            switch result.kind {
            case "fixed": model.toast("改好了，也记进了「你改过的地方」", action: "撤销") { undo(finding.id) }
            case "candidate": model.toast("记进了「你改过的地方」", action: "撤销") { undo(finding.id) }
            default:
                // 审核员说不清怎么改、或者这条记录后来又改过：打开记录，你自己看一眼
                model.toast(result.why == "changed" ? "这条记录后来改过了，你看看现在对不对" : "记下了，这一处要你自己改一下")
                if let entry = result.entryIds?.first { model.openEntry(entry, day: finding.day) }
            }
        }
    }

    private func dismiss(_ finding: API.AuditFinding) {
        act(finding) { client in
            try await client.dismissFinding(finding.id)
            await finish()
            model.toast("好，这一处不算错", action: "撤销") { undo(finding.id) }
        }
    }

    private func undo(_ id: Int) {
        let client = model.client
        Task {
            do {
                try await client.undoFinding(id)
                await finish()
                model.toast("撤销了")
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func finish() async {
        model.dataChanged()
        await reload()
    }

    private func act(_ finding: API.AuditFinding, _ work: @escaping (APIClient) async throws -> Void) {
        busy = finding.id
        let client = model.client
        Task {
            defer { busy = nil }
            do {
                try await work(client)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}
