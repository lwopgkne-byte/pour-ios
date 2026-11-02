import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 自动检查（docs/prd-auto-improve.md 第 ① 步）：「还没收尾的」里的一行「自动检查发现 2 处可能整理错了」，点开看每一处：
/// 原话（有问题的那一段加粗加下划线）、当时整理成什么、应该是什么、为什么。「确实错了」按审核员的改法改好、
/// 记进「你改过的地方」；「没错」算审核员看错了。都能撤销（AppModel+Review）。没查出来就不出现
struct AuditFindingsView: View {
    @Environment(AppModel.self) private var model
    let findings: [API.AuditFinding]
    let reload: @MainActor () async -> Void
    @State private var open = false

    var body: some View {
        if !findings.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(Theme.Motion.standard) { open.toggle() }
                } label: {
                    HStack(spacing: Theme.Space.medium) {
                        // 虚线的圈：是「可能」整理错了
                        OpenDot(pending: true)
                        Text("自动检查发现 \(findings.count) 处可能整理错了").font(Theme.Typeface.body)
                            .foregroundStyle(Theme.Palette.label).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down").font(Theme.Typeface.glyph)
                            .foregroundStyle(Theme.Palette.tertiaryLabel).rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityValue(Text(open ? "展开了" : "收着"))
                if open {
                    VStack(alignment: .leading, spacing: Theme.Space.large) { ForEach(findings) { item($0) } }
                        .padding(.top, Theme.Space.small)
                }
            }
        }
    }

    private func item(_ finding: API.AuditFinding) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(StoryOpen.marked(finding)).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            Grid(
                alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Space.medium,
                verticalSpacing: Theme.Space.tight
            ) {
                line("整理成", finding.before.joined(separator: " · "), Theme.Palette.secondaryLabel)
                if let after = finding.after { line("应该是", after.joined(separator: " · "), Theme.Palette.label) }
                line("为什么", finding.reason, Theme.Palette.secondaryLabel)
            }
            HStack(spacing: Theme.Space.large) {
                ThemeTextButton("确实错了") { model.confirmFinding(finding, after: reload) }
                ThemeTextButton("没错") { model.dismissFinding(finding, after: reload) }
            }
        }
    }

    private func line(_ name: String, _ value: String, _ color: Color) -> some View {
        GridRow {
            Text(name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            Text(Show.spaced(value)).font(Theme.Typeface.body).foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
        }
    }
}
