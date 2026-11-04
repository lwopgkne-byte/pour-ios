import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话开着时，输入框上一排快捷（docs/3.0/01-需求文档.md 2.2；样子照原型「说一句」）：记到哪天（补记以前的日子，
/// 带个日历图标，补记时变蓝）、问一句、记一笔、定目标、改一下、找一找（就是 /问 /记 /目标 /改 /找）。
/// 胶囊 30 高、浅墨底；手指点的地方还是 44 高（上下各多出一截，压在旁边的空白上）
struct SayChips: View {
    @Environment(AppModel.self) private var model
    let pick: (String) -> Void

    private static let commands = [("问一句", "/问 "), ("记一笔", "/记 "), ("定目标", "/目标 "), ("改一下", "/改 "), ("找一找", "/找 ")]

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
                ForEach(Self.commands, id: \.0) { name, prefix in
                    Button {
                        pick(prefix)
                    } label: {
                        chip(name, symbol: nil, lit: false)
                    }
                    .buttonStyle(PressScale())
                    .accessibilityIdentifier("say.\(name)")
                }
            }
        }
        // 滑到边上：一直滑到屏幕边，停着时离两边和输入框一样远
        .contentMargins(.horizontal, Theme.Space.medium, for: .scrollContent)
        .padding(.horizontal, -Theme.Space.medium)
        // 排的时候只占胶囊那么高（30），点的地方 44
        .padding(.vertical, -(Theme.Size.touch - Theme.Size.smallChip) / 2)
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
            if let symbol { Image(systemName: symbol).font(Theme.Typeface.subheadline) }
            Text(title).font(lit ? Theme.Typeface.chipLit : Theme.Typeface.chip).lineLimit(1)
        }
        .foregroundStyle(lit ? Theme.Palette.accent : Theme.Palette.label)
        .padding(.horizontal, Theme.Space.medium)
        .frame(minHeight: Theme.Size.smallChip)
        .background(lit ? Theme.Palette.bubble : Theme.Palette.fill, in: Capsule())
        .frame(minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
    }
}
