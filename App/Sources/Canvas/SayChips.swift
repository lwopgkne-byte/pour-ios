import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话开着、还没打字时，输入框上一排快捷（docs/3.0/01-需求文档.md 2.2）：记到哪天（补记以前的日子）、
/// 问一句、记一笔、定目标、改一下、找一找（就是 /问 /记 /目标 /改 /找）
struct SayChips: View {
    @Environment(AppModel.self) private var model
    let pick: (String) -> Void

    private static let commands = [
        ("问一句", "/问 ", "questionmark.bubble"), ("记一笔", "/记 ", "yensign.circle"),
        ("定目标", "/目标 ", "target"), ("改一下", "/改 ", "pencil"), ("找一找", "/找 ", "magnifyingglass"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.small) {
                Menu {
                    Button("今天") { recordTo(model.today) }
                    Button("昨天") { recordTo(PourDate.addDays(model.today, -1)) }
                    Button("前天") { recordTo(PourDate.addDays(model.today, -2)) }
                    Button("选一天…") { model.pickDay() }
                } label: {
                    chip("记到\(dayName)", symbol: "calendar", lit: backfilling)
                }
                .accessibilityIdentifier("say.day")
                ForEach(Self.commands, id: \.0) { name, prefix, symbol in
                    Button {
                        pick(prefix)
                    } label: {
                        chip(name, symbol: symbol, lit: false)
                    }
                    .buttonStyle(PressScale())
                    .accessibilityIdentifier("say.\(name)")
                }
            }
            .padding(.horizontal, Theme.Space.regular)
            .padding(.vertical, Theme.Space.tight)
        }
        // 两头渐隐：滑出去的半个胶囊看着是「还有」，不是被切掉
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Theme.Space.regular)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Theme.Space.section)
            }
        }
        .background(Theme.Palette.background)
    }

    /// 在画布上看以前的日子时，说的话补记到那天
    private var backfilling: Bool { model.stack.isEmpty && model.shownDay < model.today }

    private var dayName: String {
        guard backfilling else { return "今天" }
        return Show.relative(model.shownDay, today: model.today) ?? Show.monthDay(model.shownDay)
    }

    /// 记到哪天：回到画布看那天（补记就是在那天说）
    private func recordTo(_ day: String) {
        model.goHome()
        model.show(day)
    }

    private func chip(_ title: String, symbol: String?, lit: Bool) -> some View {
        HStack(spacing: Theme.Space.tight) {
            if let symbol { Image(systemName: symbol).font(Theme.Typeface.glyph) }
            Text(title).font(Theme.Typeface.footnoteSemibold).lineLimit(1)
        }
        .foregroundStyle(lit ? Theme.Palette.accent : Theme.Palette.label)
        .padding(.horizontal, Theme.Space.medium)
        .frame(minHeight: Theme.Size.capsule)
        .background(lit ? Theme.Palette.bubble : Theme.Palette.card, in: Capsule())
        .frame(minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
    }
}
