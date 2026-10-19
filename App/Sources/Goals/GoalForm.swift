import PourAPI
import PourDesign
import SwiftUI

/// 在目标页手动添加目标（网页版 goals/GoalForm.tsx，规格 8.1 的备用方式）：平时在输入框里说一句就行。
/// 名称可以不填，按选择自动生成
struct GoalForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind = "quantity"
    @State private var title = ""
    @State private var scope = "year"
    @State private var category = ""
    @State private var calc = "sum"
    @State private var metric = "duration"
    @State private var hours = true
    @State private var metricUnit = ""
    @State private var direction = "gte"
    @State private var target = ""
    @State private var fromStart = false
    @State private var problem: String?
    @State private var saving = false

    private static let scopes = [
        (key: "year", label: "今年"), (key: "month", label: "本月"), (key: "week", label: "本周"),
        (key: "every-week", label: "每周"), (key: "every-month", label: "每月"),
    ]
    private static let calcs = [
        (key: "sum", label: "累计"), (key: "avg", label: "平均"), (key: "count", label: "次数"),
        (key: "streak", label: "连续天数"),
    ]

    var body: some View {
        WebPeek(title: "添加目标") {
            VStack(alignment: .leading, spacing: Web.space4) {
                Text("也可以直接在输入框里说，例如「我今年想跑 1000 公里」「每周运动 3 次」。").font(Web.caption)
                    .foregroundStyle(Web.fgTertiary)
                field("种类") {
                    WebSegmented(
                        "种类", options: [(key: "quantity", label: "有数字的"), (key: "completion", label: "做完就算")],
                        selected: kind
                    ) { kind = $0 }
                }
                WebTextField(
                    "名称",
                    placeholder: kind == "completion" ? "例如：读完《三体》" : autoTitle.isEmpty ? "按下面的选择自动生成" : autoTitle,
                    text: $title)
                if kind == "quantity" { quantityFields }
                if let problem { Text(problem).font(Web.caption).foregroundStyle(Web.danger) }
                HStack(spacing: Web.space3) {
                    WebButton("添加", variant: .primary, loading: saving) { submit() }
                    WebTextButton("取消") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder private var quantityFields: some View {
        field("周期") { WebSegmented("周期", options: Self.scopes, selected: scope) { scope = $0 } }
        field("类别（子类别的记录也算进上级）") {
            PourFlowLayout(spacing: Web.space1, lineSpacing: Web.space1) {
                ForEach(CategoryPicker.ordered(model.categories), id: \.key) { item in
                    WebChip(selected: item.key == category) {
                        pick(item)
                    } label: {
                        Text(item.emoji).accessibilityHidden(true)
                        Text(item.name)
                    }
                }
            }
        }
        field("怎么算") { WebSegmented("怎么算", options: Self.calcs, selected: calc) { calc = $0 } }
        if byMetric {
            field("看什么") {
                WebSegmented(
                    "看什么", options: [(key: "duration", label: "时长"), (key: "value", label: "数量")], selected: metric
                ) { metric = $0 }
            }
            if metric == "duration" {
                field("时长的单位") {
                    WebSegmented(
                        "时长的单位", options: [(key: "h", label: "小时"), (key: "m", label: "分钟")],
                        selected: hours ? "h" : "m"
                    ) {
                        hours = $0 == "h"
                    }
                }
            } else {
                WebTextField("数量的单位", placeholder: "例如：公里、页、毫升", text: $metricUnit)
            }
        }
        if calc != "streak" {
            field("方向") {
                WebSegmented(
                    "方向", options: [(key: "gte", label: "至少"), (key: "lte", label: "不超过")], selected: direction
                ) {
                    direction = $0
                }
            }
        }
        WebTextField(unit.isEmpty ? "目标值" : "目标值（\(unit)）", text: $target, keyboard: .decimal)
        if scope == "year" || scope == "month" {
            field("从哪天开始算") {
                WebSegmented(
                    "从哪天开始算",
                    options: [
                        (key: "today", label: "今天"), (key: "start", label: scope == "year" ? "1 月 1 日" : "这个月 1 日"),
                    ],
                    selected: fromStart ? "start" : "today"
                ) { fromStart = $0 == "start" }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text(label).font(Web.captionMedium).foregroundStyle(Web.fgSecondary)
            content()
        }
    }

    private var repeats: Bool { scope.hasPrefix("every-") }
    private var period: String { scope == "every-week" ? "week" : scope == "every-month" ? "month" : scope }
    private var byMetric: Bool { calc == "sum" || calc == "avg" }

    private var unit: String {
        if calc == "count" { return "次" }
        if calc == "streak" { return "天" }
        return metric == "duration" ? (hours ? "小时" : "分钟") : metricUnit.trimmingCharacters(in: .whitespaces)
    }

    /// 没写名称时按选择自动生成：「今年跑步 500 公里」
    private var autoTitle: String {
        guard kind == "quantity" else { return "" }
        let scopeName = Self.scopes.first { $0.key == scope }?.label ?? ""
        let how = calc == "avg" ? "平均" : calc == "streak" ? "连续" : ""
        let name = model.categories.first { $0.key == category }?.name ?? ""
        let limit = direction == "lte" && calc != "streak" ? "不超过" : ""
        let number = Double(target).flatMap { $0 > 0 ? Show.fmtNum($0) : nil } ?? "…"
        return "\(scopeName)\(how)\(name)\(limit) \(number) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    /// 选了类别：按类别的计量方式给出默认的「看什么」
    private func pick(_ item: API.Category) {
        category = item.key
        if item.measure != "duration" && item.measure != "count" {
            metric = "value"
            metricUnit = item.measure
        } else {
            metric = "duration"
        }
    }

    private func submit() {
        problem = nil
        let name =
            title.trimmingCharacters(in: .whitespaces).isEmpty ? autoTitle : title.trimmingCharacters(in: .whitespaces)
        let number = Double(target) ?? 0
        if kind == "completion" {
            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return problem = "写一下要完成什么，例如「读完《三体》」" }
        } else {
            guard !category.isEmpty else { return problem = "选一个类别" }
            guard number > 0 else { return problem = "目标值需要是大于 0 的数字" }
            if byMetric, metric == "value", unit.isEmpty { return problem = "写一下数量的单位，例如「公里」「页」" }
        }
        saving = true
        let body = kind == "completion" ? completionBody(name) : quantityBody(name, number)
        Task {
            defer { saving = false }
            do {
                try await model.createGoal(body)
                dismiss()
            } catch {
                problem = error.readable
            }
        }
    }

    private func completionBody(_ name: String) -> [String: JSONValue] {
        ["kind": .string(kind), "title": .string(name), "period": .string("year"), "start": .string("today")]
    }

    private func quantityBody(_ name: String, _ number: Double) -> [String: JSONValue] {
        var body: [String: JSONValue] = [
            "kind": .string(kind), "title": .string(name), "period": .string(period), "repeat": .bool(repeats),
            "start": .string(!repeats && fromStart ? "period_start" : "today"), "calc": .string(calc),
            "direction": .string(calc == "streak" ? "gte" : direction), "target": .number(number),
            "unit": .string(unit), "category": .string(category), "metric": .string(byMetric ? metric : "count"),
        ]
        if byMetric, metric == "value" {
            body["metric_unit"] = .string(metricUnit.trimmingCharacters(in: .whitespaces))
        }
        return body
    }
}
