import PourAPI
import PourDesign
import SwiftUI

/// 心情从哪来（网页版 charts/MoodSources.tsx，docs/prd-mood.md 5.11）：好时刻多出现在什么时候、醒着的时间和好时刻在哪些领域、
/// 和谁在一起、常见的心情。数据不够的那一列不画，换成一行灰字；只说同时出现。
/// 「关于我」里点一行展开最多 3 条原话里的那一刻（interactive），月报里只看不点
struct MoodSourcesView: View {
    let data: API.MoodSources
    var interactive = false

    /// 一列：表头、每行一个数（nil 是「—」，没记过时长）、细条是好时刻（粉）还是别的（灰）
    struct Column {
        let head: String
        let good: Bool
        let values: [Double?]
        var percent = false
        var labels: [String?] = []
    }

    /// 一行：名字、名字下面的小字、点开后看到的例子（几组，每组可以有个小标题）
    struct Row {
        let key: String
        let label: String
        var sub: String?
        let examples: [(title: String?, items: [API.MomentExample])]
    }

    private static let whens = [("purpose", "做有目标的事时"), ("daily", "日常的事里"), ("glimpse", "不算一件事的一刻")]

    var body: some View {
        let enough = data.enough
        let short = [data.short.good, data.short.bad, data.short.time].compactMap { $0 }
        VStack(alignment: .leading, spacing: Web.space6) {
            if !short.isEmpty {
                VStack(alignment: .leading, spacing: Web.space1) { ForEach(short, id: \.self) { MeNote($0) } }
            }
            SourceBlock(title: "好时刻多出现在什么时候", columns: whenColumns, rows: whenRows, interactive: interactive)
            SourceBlock(title: "醒着的时间花在哪，好时刻在哪些领域", columns: mirrorColumns, rows: mirrorRows, interactive: interactive)
            SourceBlock(title: "和谁在一起", columns: peopleColumns, rows: peopleRows, interactive: interactive)
            let good = enough.good ? words(data.emotions.good) : ""
            let bad = enough.bad ? words(data.emotions.bad) : ""
            if !good.isEmpty || !bad.isEmpty {
                PourFlowLayout(spacing: Web.space4, lineSpacing: Web.space1) {
                    Text("常见的心情").font(Web.bodyMedium)
                    if !good.isEmpty { Text("好的：\(good)") }
                    if !bad.isEmpty { Text("不好的：\(bad)") }
                }
                .font(Web.body).foregroundStyle(Web.fg)
                .accessibilityElement(children: .combine)
            }
            let notes = footNotes
            if !notes.isEmpty { MeNote(notes) }
        }
    }

    private func words(_ list: [API.MoodSources.Word]) -> String {
        list.map { "\($0.word) \($0.count)" }.joined(separator: " · ")
    }

    private func examples(_ key: String) -> [API.MomentExample] { data.examples[key] ?? [] }

    private var whenColumns: [Column] {
        let order = Self.whens.map(\.0)
        return
            (data.enough.good
            ? [Column(head: "好时刻 \(data.goodTotal)", good: true, values: order.map { Double(data.when.good[$0] ?? 0) })]
            : [])
            + (data.enough.bad
                ? [
                    Column(
                        head: "不好的时刻 \(data.badTotal)", good: false,
                        values: order.map { Double(data.when.bad[$0] ?? 0) })
                ]
                : [])
    }

    private var whenRows: [Row] {
        Self.whens.map { key, name in
            Row(
                key: key, label: name, sub: key == "glimpse" ? "看到、听到、闻到的那一下" : nil,
                examples: (data.enough.good ? [("好时刻", examples("when:good:\(key)"))] : [])
                    + (data.enough.bad ? [("不好的时刻", examples("when:bad:\(key)"))] : []))
        }
    }

    /// 只有时间、没有好时刻可比时不画这一块
    private var mirrorColumns: [Column] {
        guard data.enough.good else { return [] }
        let time =
            data.enough.time
            ? [
                Column(
                    head: "醒着的时间", good: false, values: data.mirror.map(\.timeShare), percent: true,
                    labels: data.mirror.map { $0.timeUnder1 ? "不到 1%" : nil })
            ] : []
        return time + [Column(head: "好时刻", good: true, values: data.mirror.map { $0.goodShare }, percent: true)]
    }

    private var mirrorRows: [Row] {
        data.mirror.map { row in
            let label =
                row.key == "glimpse"
                ? row.domain : "\(row.emoji.isEmpty ? "" : "\(row.emoji) ")\(row.domain)\(row.hasGoal ? " 🎯" : "")"
            return Row(key: row.key, label: label, examples: [(nil, examples("domain:\(row.key)"))])
        }
    }

    private var peopleColumns: [Column] {
        (data.enough.good ? [Column(head: "好时刻", good: true, values: data.people.map { Double($0.good) })] : [])
            + (data.enough.bad ? [Column(head: "不好的时刻", good: false, values: data.people.map { Double($0.bad) })] : [])
    }

    private var peopleRows: [Row] {
        data.people.map { person in
            Row(
                key: person.name, label: person.name == "没提到别人" ? person.name : "👤 \(person.name)",
                examples: [(nil, examples("person:\(person.name)"))])
        }
    }

    private var footNotes: String {
        let drawn = !whenColumns.isEmpty
        let goal = !mirrorColumns.isEmpty && data.mirror.contains { $0.hasGoal }
        let dash = mirrorColumns.contains { $0.head == "醒着的时间" }
        return (drawn ? "只是同时出现，不一定和它有关。" : "") + (goal ? "🎯 是你定了目标的领域。" : "")
            + (dash ? "— 是没记过时长。" : "")
            + (data.noMoment > 0 ? "还有 \(data.noMoment) 条心情没说是哪一刻，没算进来。" : "")
    }
}

/// 一块「几行 × 一两列」的小表：每格一个数加一根细条，细条按这一列的最大值算长短
private struct SourceBlock: View {
    @Environment(AppModel.self) private var model
    let title: String
    let columns: [MoodSourcesView.Column]
    let rows: [MoodSourcesView.Row]
    let interactive: Bool
    @State private var open: String?

    var body: some View {
        if !columns.isEmpty && !rows.isEmpty {
            let most = columns.map { column in column.values.compactMap { $0 }.max() ?? 0 }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: Web.space3) {
                    Text(title).font(Web.bodyMedium).foregroundStyle(Web.fg)
                        .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                            width * (columns.count == 1 ? 0.55 : 0.4)
                        }
                    ForEach(columns, id: \.head) { column in
                        Text(column.head).font(Web.caption).foregroundStyle(Web.fgSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, Web.space2)
                ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                    line(row, index: index, most: most)
                    if open == row.key { examples(row) }
                }
            }
        }
    }

    private func line(_ row: MoodSourcesView.Row, index: Int, most: [Double]) -> some View {
        let canOpen = interactive && row.examples.contains { !$0.items.isEmpty }
        let name = VStack(alignment: .leading, spacing: 0) {
            Text(row.label).font(open == row.key ? Web.bodyMedium : Web.body).foregroundStyle(Web.fg)
            if let sub = row.sub { Text(sub).font(Web.caption).foregroundStyle(Web.fgTertiary) }
        }
        return HStack(spacing: Web.space3) {
            Group {
                if canOpen {
                    Button {
                        withAnimation(Web.fast) { open = open == row.key ? nil : row.key }
                    } label: {
                        name.frame(maxWidth: .infinity, minHeight: Web.touch, alignment: .leading).contentShape(
                            Rectangle())
                    }
                    .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                    .accessibilityValue(Text(open == row.key ? "展开了" : "收着"))
                } else {
                    name.frame(maxWidth: .infinity, minHeight: Web.control, alignment: .leading)
                }
            }
            .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                width * (columns.count == 1 ? 0.55 : 0.4)
            }
            ForEach(Array(columns.enumerated()), id: \.offset) { column, item in
                cell(item, index: index, most: most[column])
            }
        }
    }

    @ViewBuilder private func cell(_ column: MoodSourcesView.Column, index: Int, most: Double) -> some View {
        let value = index < column.values.count ? column.values[index] : nil
        if let value {
            let label = index < column.labels.count ? column.labels[index] : nil
            HStack(spacing: Web.space2) {
                Text(label ?? "\(Show.fmtNum(value))\(column.percent ? "%" : "")").font(Web.body)
                    .foregroundStyle(Web.fgSecondary).monospacedDigit().frame(minWidth: Web.space8, alignment: .leading)
                MeTrack(
                    share: most > 0 ? value / most : 0,
                    color: column.good ? Web.tag("pink").solid : Web.tag("gray").solid)
            }
            .frame(maxWidth: .infinity)
        } else {
            Text("—").font(Web.body).foregroundStyle(Web.fgTertiary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 点开一行看到的那几刻：有原话的点一下到笔记库看原话
    private func examples(_ row: MoodSourcesView.Row) -> some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            ForEach(Array(row.examples.enumerated()), id: \.offset) { _, group in
                if !group.items.isEmpty {
                    VStack(alignment: .leading, spacing: Web.space2) {
                        if let title = group.title { MeNote(title) }
                        ForEach(group.items, id: \.entryId) { item in
                            Button {
                                if let note = item.noteId { model.open("/library?note=\(note)") }
                            } label: {
                                VStack(alignment: .leading, spacing: Web.space1) {
                                    QuoteText(text: item.moment)
                                    MeNote("\(Show.monthDay(item.day))\(item.noteId == nil ? "" : " · 看原话")")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(item.noteId == nil)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .padding(.top, Web.space2).padding(.bottom, Web.space3)
    }
}
