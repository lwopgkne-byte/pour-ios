import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 心情从哪来（docs/prd-mood.md 5.11、06 交互细节 10.1）：30 天 / 90 天 / 今年；四块都写数——好时刻多出现在什么时候、
/// 醒着的时间花在哪 · 好时刻在哪些领域（🎯 定了目标的、— 没记过时长）、和谁在一起、常见的心情。
/// 数据不够的那一列不画，换成一行灰字；点一行展开最多 3 条那一刻（点了看原话）。只说同时出现。
/// 月报整页里给的是那个月的（fixed）：不选时间段、不自己去拿
struct MoodSourcesCard: View {
    @Environment(AppModel.self) private var model
    @State private var range = "30d"
    @State private var data: API.MoodSources?
    @State private var problem: String?
    let fixed: API.MoodSources?

    init(fixed: API.MoodSources? = nil) {
        self.fixed = fixed
    }

    private static let ranges = [("30d", "30 天"), ("90d", "90 天"), ("year", "今年")]
    private static let whens = [("purpose", "做有目标的事时"), ("daily", "日常的事里"), ("glimpse", "不算一件事的一刻")]

    /// 照原型：标题、30 天 / 90 天 / 今年在卡片外面，下面每一小块各是一张白卡，说明在最下面
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            PageSectionHeader(title: "心情从哪来")
            if fixed == nil {
                Picker("多长时间", selection: $range) {
                    ForEach(Self.ranges, id: \.0) { key, name in Text(name).tag(key) }
                }
                .pickerStyle(.segmented)
            }
            if let data = fixed ?? data {
                content(data)
            } else if let problem {
                Text(problem).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
            }
        }
        .padding(.top, Theme.Space.medium)
        .task(id: "\(range)-\(model.dataVersion)") {
            if fixed == nil { await load() }
        }
    }

    @ViewBuilder private func content(_ data: API.MoodSources) -> some View {
        let short = [data.short.good, data.short.bad, data.short.time].compactMap { $0 }
        ForEach(short, id: \.self) { line in
            Text(line).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.horizontal, Theme.Space.tight)
        }
        MoodSourceBlock(title: "好时刻多出现在什么时候", columns: whenColumns(data), rows: whenRows(data))
        MoodSourceBlock(title: "醒着的时间花在哪，好时刻在哪些领域", columns: mirrorColumns(data), rows: mirrorRows(data))
        MoodSourceBlock(title: "和谁在一起", columns: peopleColumns(data), rows: peopleRows(data))
        let good = data.enough.good ? words(data.emotions.good) : ""
        let bad = data.enough.bad ? words(data.emotions.bad) : ""
        if !good.isEmpty || !bad.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("常见的心情").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                if !good.isEmpty { Text("好的：\(good)").font(Theme.Typeface.subheadline) }
                if !bad.isEmpty { Text("不好的：\(bad)").font(Theme.Typeface.subheadline) }
            }
            .foregroundStyle(Theme.Palette.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard(radius: Theme.Corner.smallCard)
            .accessibilityElement(children: .combine)
        }
        let notes = footNotes(data)
        if !notes.isEmpty {
            Text(notes).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.horizontal, Theme.Space.tight)
        }
    }

    private func words(_ list: [API.MoodSources.Word]) -> String {
        list.map { "\($0.word) \($0.count)" }.joined(separator: " · ")
    }

    private func examples(_ data: API.MoodSources, _ key: String) -> [API.MomentExample] { data.examples[key] ?? [] }

    private func whenColumns(_ data: API.MoodSources) -> [MoodSourceBlock.Column] {
        let order = Self.whens.map(\.0)
        let good = MoodSourceBlock.Column(
            head: "好时刻 \(data.goodTotal)", good: true, values: order.map { Double(data.when.good[$0] ?? 0) })
        let bad = MoodSourceBlock.Column(
            head: "不好的时刻 \(data.badTotal)", good: false, values: order.map { Double(data.when.bad[$0] ?? 0) })
        return (data.enough.good ? [good] : []) + (data.enough.bad ? [bad] : [])
    }

    private func whenRows(_ data: API.MoodSources) -> [MoodSourceBlock.Row] {
        Self.whens.map { key, name in
            MoodSourceBlock.Row(
                key: key, label: name, sub: key == "glimpse" ? "看到、听到、闻到的那一下" : nil,
                examples: (data.enough.good ? [("好时刻", examples(data, "when:good:\(key)"))] : [])
                    + (data.enough.bad ? [("不好的时刻", examples(data, "when:bad:\(key)"))] : []))
        }
    }

    /// 只有时间、没有好时刻可比时不画这一块
    private func mirrorColumns(_ data: API.MoodSources) -> [MoodSourceBlock.Column] {
        guard data.enough.good else { return [] }
        let time = MoodSourceBlock.Column(
            head: "醒着的时间", good: false, values: data.mirror.map(\.timeShare), percent: true,
            labels: data.mirror.map { $0.timeUnder1 ? "不到 1%" : nil })
        let good = MoodSourceBlock.Column(
            head: "好时刻", good: true, values: data.mirror.map { $0.goodShare }, percent: true)
        return (data.enough.time ? [time] : []) + [good]
    }

    private func mirrorRows(_ data: API.MoodSources) -> [MoodSourceBlock.Row] {
        data.mirror.map { row in
            let label = row.key == "glimpse" ? row.domain : "\(row.domain)\(row.hasGoal ? " 🎯" : "")"
            let said = examples(data, "domain:\(row.key)")
            return MoodSourceBlock.Row(key: row.key, label: label, examples: [(nil, said)])
        }
    }

    private func peopleColumns(_ data: API.MoodSources) -> [MoodSourceBlock.Column] {
        let good = MoodSourceBlock.Column(head: "好时刻", good: true, values: data.people.map { Double($0.good) })
        let bad = MoodSourceBlock.Column(head: "不好的时刻", good: false, values: data.people.map { Double($0.bad) })
        return (data.enough.good ? [good] : []) + (data.enough.bad ? [bad] : [])
    }

    private func peopleRows(_ data: API.MoodSources) -> [MoodSourceBlock.Row] {
        data.people.map { person in
            MoodSourceBlock.Row(
                key: person.name, label: person.name, examples: [(nil, examples(data, "person:\(person.name)"))])
        }
    }

    private func footNotes(_ data: API.MoodSources) -> String {
        let goal = data.enough.good && data.mirror.contains { $0.hasGoal }
        let dash = data.enough.good && data.enough.time
        return (data.enough.good || data.enough.bad ? "只是同时出现，不一定和它有关。" : "") + (goal ? "🎯 是你定了目标的领域。" : "")
            + (dash ? "— 是没记过时长。" : "")
            + (data.noMoment > 0 ? "还有 \(data.noMoment) 条心情没说是哪一刻，没算进来。" : "")
    }

    private func load() async {
        do throws(APIError) {
            data = try await model.client.moodSources(range)
            problem = nil
        } catch {
            problem = error.message
        }
    }
}

/// 一块「几行 × 一两列」的小表：每格一个数加一根细条（按这一列最大的算长短）；点一行展开那几刻
struct MoodSourceBlock: View {
    struct Column {
        let head: String
        let good: Bool
        let values: [Double?]
        var percent = false
        var labels: [String?] = []
    }

    struct Row {
        let key: String
        let label: String
        var sub: String?
        let examples: [(title: String?, items: [API.MomentExample])]
    }

    @Environment(AppModel.self) private var model
    let title: String
    let columns: [Column]
    let rows: [Row]
    @State private var open: String?

    var body: some View {
        if !columns.isEmpty && !rows.isEmpty {
            let most = columns.map { column in column.values.compactMap { $0 }.max() ?? 0 }
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                HStack {
                    Spacer()
                    ForEach(columns, id: \.head) { column in
                        Text(column.head).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                            .frame(width: Theme.Size.touch * 2.2, alignment: .leading)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                    line(row, index: index, most: most)
                    if open == row.key { examples(row) }
                }
            }
            // 照原型：一小块一张白卡
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard(radius: Theme.Corner.smallCard)
        }
    }

    private func line(_ row: Row, index: Int, most: [Double]) -> some View {
        let canOpen = row.examples.contains { !$0.items.isEmpty }
        return Button {
            withAnimation(Theme.Motion.standard) { open = open == row.key ? nil : row.key }
        } label: {
            HStack(spacing: Theme.Space.small) {
                VStack(alignment: .leading, spacing: 0) {
                    // 没有行数上限，放不下就换行（canWrap：审计在大字号下量不准，见 AppAudit）
                    Text(row.label).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("canWrap")
                    if let sub = row.sub {
                        Text(sub).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(columns.enumerated()), id: \.offset) { column, item in
                    cell(item, index: index, most: most[column])
                }
            }
            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(canOpen ? (open == row.key ? "展开了" : "收着") : ""))
    }

    @ViewBuilder private func cell(_ column: Column, index: Int, most: Double) -> some View {
        let value = index < column.values.count ? column.values[index] : nil
        HStack(spacing: Theme.Space.tight) {
            if let value {
                let label = index < column.labels.count ? column.labels[index] : nil
                Text(label ?? "\(Show.fmtNum(value))\(column.percent ? "%" : "")").font(Theme.Typeface.footnote)
                    .monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minWidth: Theme.Size.touch * 0.8, alignment: .leading)
                Capsule().fill(column.good ? Theme.Mood.fill(4) : Theme.Palette.tertiaryLabel)
                    .frame(width: max(Theme.Space.hairline, Theme.Size.touch * CGFloat(most > 0 ? value / most : 0)))
                    .frame(height: Theme.Space.snug)
            } else {
                Text("—").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .frame(width: Theme.Size.touch * 2.2, alignment: .leading)
    }

    /// 点开一行看到的那几刻：有原话的点一下到笔记库看原话
    private func examples(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ForEach(Array(row.examples.enumerated()), id: \.offset) { _, group in
                if !group.items.isEmpty {
                    if let title = group.title {
                        Text(title).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    ForEach(group.items, id: \.entryId) { item in
                        Button {
                            if let note = item.noteId { model.open("/library?note=\(note)") }
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                                Text(item.moment).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(Show.monthDay(item.day))\(item.noteId == nil ? "" : " · 看原话 ›")")
                                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(item.noteId == nil)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(.leading, Theme.Space.regular)
        .padding(.bottom, Theme.Space.small)
    }
}
