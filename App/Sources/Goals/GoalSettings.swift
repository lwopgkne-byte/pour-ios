import PourAPI
import PourDesign
import SwiftUI

/// 目标详情里能原地改的（网页版 GoalPeek 的设置部分）：名称、目标值、类别、只算哪些、周期、从哪天算
struct GoalSettings: View {
    @Environment(AppModel.self) private var model
    let goal: API.Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PeekRow(label: "名称") {
                InlineEdit(label: "名称", value: goal.title) { save(["title": .string($0.trimmed)]) }
            }
            if goal.kind == "quantity" {
                PeekRow(label: "目标") {
                    InlineEdit(
                        label: "目标值（\(goal.unit ?? "")）", value: goal.target.map(Show.fmtNum) ?? "",
                        display: Show.describeTarget(goal), keyboard: .decimalPad, validate: Self.positive
                    ) { text in
                        if let number = Double(text) { save(["target": .number(number)]) }
                    }
                }
                PeekRow(label: "类别") {
                    CategoryPicker(value: goal.binding?.category ?? "", startOpen: goal.invalid != nil) { key in
                        save(["category": .string(key)])
                    }
                }
                if let keywords = goal.binding?.keywords, !keywords.isEmpty {
                    PeekRow(label: "只算") { Text("名称里带「\(keywords.joined(separator: "」「"))」的记录") }
                }
            }
            if goal.kind != "parent" {
                PeekRow(label: "周期") {
                    Text(
                        Show.spaced(
                            goal.repeats == true
                                ? "\(Show.periodName(goal.period, repeating: true))（现在是 \(goal.rangeLabel)）"
                                : goal.rangeLabel))
                }
                if goal.repeats != true {
                    PeekRow(label: "从哪天算") {
                        DateEdit(
                            label: "开始日期", value: goal.start, display: Show.dayTitle(goal.start, today: model.today)
                        ) {
                            save(["start": .string($0)])
                        }
                    }
                }
            }
        }
    }

    static func positive(_ text: String) -> String? {
        Double(text.trimmed).map { $0 > 0 } == true ? nil : "需要是大于 0 的数字"
    }

    private func save(_ fields: [String: JSONValue]) {
        let id = goal.id
        Task {
            do {
                try await model.updateGoal(id, fields)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 年目标的每个月：点数字改某个月的目标（改过的锁定，「恢复自动」重新按天数分配；规格 8.3）
struct GoalMonths: View {
    @Environment(AppModel.self) private var model
    let goal: API.Goal
    let months: [API.SubPeriod]

    var body: some View {
        let unit = goal.unit ?? ""
        PeekSection(title: "每个月") {
            if goal.overLocked == true {
                Text("调整过的月份加起来已经超过了全年目标。").font(Web.caption).foregroundStyle(Web.danger)
            }
            VStack(spacing: 0) {
                ForEach(months) { month in
                    HStack(spacing: Web.space3) {
                        Text(month.label).frame(minWidth: Web.space16, alignment: .leading)
                        GoalBar(pct: month.progress.pct, tone: month.progress.tone)
                        HStack(spacing: 0) {
                            Text("\(Show.fmtNum(month.progress.actual)) / ").monospacedDigit()
                            InlineEdit(
                                label: "\(month.label)的目标（\(unit)）", value: Show.fmtNum(month.target),
                                display: Show.fmtNum(month.target) + (month.locked ? " · 已调整" : ""),
                                keyboard: .decimalPad, validate: Self.nonNegative
                            ) { text in
                                if let number = Double(text) {
                                    model.adjustMonth(goal.id, month: month.key, target: number)
                                }
                            }
                        }
                        if month.locked {
                            WebTextButton("恢复自动", font: Web.captionMedium) {
                                model.adjustMonth(goal.id, month: month.key, target: nil)
                            }
                        }
                    }
                    .font(month.current ? Web.captionMedium : Web.caption)
                    .foregroundStyle(month.current ? Web.fg : Web.fgSecondary)
                    .padding(.horizontal, Web.space2)
                    .frame(minHeight: Web.control)
                }
            }
            Text("点数字可以改某个月的目标，其余月份会自动重新分配。").font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
    }

    static func nonNegative(_ text: String) -> String? {
        Double(text.trimmed).map { $0 >= 0 } == true ? nil : "需要是一个数字"
    }
}

/// 重新选类别：平时只显示现在的类别，点一下展开成一排小标签（子类别跟在上级后面）
struct CategoryPicker: View {
    @Environment(AppModel.self) private var model
    let value: String
    let pick: (String) -> Void
    @State private var open: Bool

    init(value: String, startOpen: Bool = false, pick: @escaping (String) -> Void) {
        self.value = value
        self.pick = pick
        _open = State(initialValue: startOpen)
    }

    var body: some View {
        let categories = model.categories
        if open {
            PourFlowLayout(spacing: Web.space1, lineSpacing: Web.space1) {
                ForEach(Self.ordered(categories), id: \.key) { category in
                    WebChip(selected: category.key == value) {
                        if category.key != value { pick(category.key) }
                    } label: {
                        Text(category.emoji).accessibilityHidden(true)
                        Text(category.name)
                    }
                }
            }
        } else {
            let current = categories.first { $0.key == value }
            Button {
                open = true
            } label: {
                Text(current.map { "\($0.emoji) \($0.name)" } ?? "选一个类别")
                    .foregroundStyle(current == nil ? Web.fgTertiary : Web.fgSecondary)
                    .frame(minHeight: Web.touch)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("修改类别"))
            .accessibilityValue(Text(current?.name ?? "没有选"))
        }
    }

    /// 上级类别，后面跟着它的子类别
    static func ordered(_ categories: [API.Category]) -> [API.Category] {
        categories.filter { $0.parent == nil }.flatMap { top in [top] + categories.filter { $0.parent == top.key } }
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
