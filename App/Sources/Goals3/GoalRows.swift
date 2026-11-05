import PourAPI
import PourDesign
import SwiftUI

/// 目标的一行（首页、坚持、预算、领域页、子目标都用它）：进度环（中间百分比 / 2/4 / 1/2；刚定的空心、暂停浅灰）、
/// 名字、一句人话（落后用黄）、第二行（落后两周了，聊聊怎么调？/ 在等你回答一句 ›）。点了推进那个目标
struct GoalRow: View {
    @Environment(AppModel.self) private var model
    let card: API.GoalCard

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.medium) {
            GoalRing(
                state: card.ringState, progress: card.pct, label: card.ring ?? "", size: Theme.Size.rowRing,
                spinIn: model.goals.fresh == card.id)
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(card.title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.line).font(Theme.Typeface.subheadline).monospacedDigit()
                    .foregroundStyle(card.state == "behind" ? Theme.Palette.warn : Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                if let second = card.second { secondLine(second) }
            }
            Spacer(minLength: 0)
        }
        .opacity(card.paused ? 0.62 : 1)
        .contentShape(Rectangle())
        .onTapGesture { model.openGoal(card.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.openGoal(card.id) }
        .accessibilityIdentifier("goal.row.\(card.id)")
    }

    /// 落后两周的那一行点了进 GROW；在等回答的点了进这个目标
    private func secondLine(_ text: String) -> some View {
        Button {
            if card.lagging { model.goals.sheet = .grow(card.id) } else { model.openGoal(card.id) }
        } label: {
            Text(text).font(Theme.Typeface.footnoteMedium).foregroundStyle(Theme.Palette.accent)
                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(card.lagging ? "goal.grow.\(card.id)" : "goal.ask.\(card.id)")
    }
}

/// 坚持的一行：名字（成习惯了的带标签）和「30 天做到 26 天 · 这周用了 1 次补假」，右边最近 14 天的格子
struct StreakRowView: View {
    @Environment(AppModel.self) private var model
    let card: API.GoalCard

    var body: some View {
        // 名字（和「成习惯了」）单独一行；下面一句话，右边最近 14 天的格子
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.small) {
                Text(card.title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true)
                if card.streak?.habit == true && !card.paused { HabitTag() }
            }
            HStack(alignment: .center, spacing: Theme.Space.small) {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(card.line).font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                    if let second = card.second {
                        Text(second).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Theme.Space.small)
                if let marks = card.streak?.marks { DayCells(marks: marks) }
            }
        }
        .opacity(card.paused ? 0.62 : 1)
        .contentShape(Rectangle())
        .onTapGesture { model.openGoal(card.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.openGoal(card.id) }
        .accessibilityIdentifier("goal.row.\(card.id)")
    }
}

/// 「成习惯了」浅绿的小标签
struct HabitTag: View {
    var body: some View {
        Text("成习惯了").font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.good).fixedSize()
            .padding(.horizontal, Theme.Space.small).padding(.vertical, Theme.Space.hairline)
            .background(Theme.Palette.goodFill, in: Capsule())
    }
}

/// 按住一个目标（06 交互细节 12.1）：改 · 暂停（继续）· 标记完成 · 删除；系统的 contextMenu，松手那一下不算点
struct GoalMenu: View {
    @Environment(AppModel.self) private var model
    let card: API.GoalCard

    var body: some View {
        Button {
            model.goals.editing = card.id
            model.openGoal(card.id)
        } label: {
            Label("改", systemImage: "pencil")
        }
        Button {
            model.goalAct(card.id, card.paused ? "resume" : "pause")
        } label: {
            Label(card.paused ? "继续" : "暂停", systemImage: card.paused ? "play" : "pause")
        }
        Button {
            model.goalAct(card.id, "done")
        } label: {
            Label("标记完成", systemImage: "checkmark")
        }
        Button(role: .destructive) {
            model.deleteGoal(card.id, title: card.title)
        } label: {
            Label("删除", systemImage: Theme.Symbol.delete)
        }
    }
}

extension View {
    /// 一个目标的一行在 List 里：按住出菜单、左滑暂停 / 继续（系统的 swipeActions，竖着划是滚动）
    func goalActions(_ card: API.GoalCard, model: AppModel) -> some View {
        contextMenu { GoalMenu(card: card) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    model.goalAct(card.id, card.paused ? "resume" : "pause")
                } label: {
                    Label(card.paused ? "继续" : "暂停", systemImage: card.paused ? "play.fill" : "pause.fill")
                }
                .tint(Theme.Palette.tertiaryLabel)
            }
    }
}

extension API.GoalCard {
    /// 环的样子：正轨绿、落后黄、刚定的空心、暂停浅灰、做到了满环
    var ringState: GoalRing.State {
        switch state {
        case "track": .onTrack
        case "behind": .behind
        case "paused", "letgo": .paused
        case "done": .done
        default: .notYet
        }
    }
}

/// 「我在乎的」图标：服务器的名字 → SF Symbol（照原型：健康心电图、钱 ¥、成长学士帽、关系几个人）；颜色是 Theme.careColor
enum CareIcon {
    static func symbol(_ name: String) -> String {
        [
            "heart": "waveform.path.ecg.rectangle.fill", "yen": "yensign", "book": "graduationcap.fill",
            "people": "person.3.fill", "star": "star.fill",
        ][name] ?? "circle.fill"
    }
}
