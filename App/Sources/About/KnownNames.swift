import PourAPI
import PourDesign
import SwiftUI

/// 改过的名字（docs/模块/产品优化.md R2）：画布「说到的」里长按改了名字、不再显示的，都列在这里，点「恢复」回到原样。
/// 原话没改；画布、关于我、笔记库照这张表算
struct KnownNames: View {
    @Environment(AppModel.self) private var model
    @State private var rules: [API.NameRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !rules.isEmpty {
                LegacySection(title: "改过的名字") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rules) { rule in row(rule) }
                        Text("原话没有改；画布上的「说到的」、关于我、笔记库都照这里算")
                            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).padding(
                                .top, Theme.Space.small)
                    }
                }
            }
        }
        .task(id: model.dataVersion) {
            if let fresh = try? await model.client.names() { rules = fresh }
        }
    }

    private func row(_ rule: API.NameRule) -> some View {
        HStack(spacing: Theme.Space.medium) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(Self.title(rule)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Text("\(Self.kindWord[rule.kind] ?? "") · \(KnownStore.isoDay(rule.updatedAt))")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            LinkButton("恢复") { restore(rule) }
                .accessibilityLabel(Text("恢复\(rule.name)"))
        }
        .frame(minHeight: Theme.Size.touch)
    }

    static let kindWord = ["person": "人", "thing": "东西", "place": "地方", "tag": "话题"]

    /// 「小丽 → 小李」「医院 · 不再显示」
    static func title(_ rule: API.NameRule) -> String {
        guard let canonical = rule.canonical else { return "\(rule.name) · 不再显示" }
        return "\(rule.name) → \(canonical)\(rule.hidden ? " · 不再显示" : "")"
    }

    private func restore(_ rule: API.NameRule) {
        let client = model.client
        Task {
            do {
                rules = try await client.forgetName(kind: rule.kind, name: rule.name)
                model.dataChanged()
            } catch {
                model.toast(error.readable)
            }
        }
    }
}
