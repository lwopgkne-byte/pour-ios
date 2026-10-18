import PourCore
import PourData
import PourDesign
import SwiftUI

/// 今天 ——「我今天过得怎么样」（规范 12 第 3 节）：日子头、时间轴，刚说的话就地出现收据。
/// 刚说的（还在整理、没整理成、整理好不到 10 分钟的）以收据出现在时间轴最后；过了 10 分钟，它的记录回到时间轴上自己的位置
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false

    /// 整理好以后，收据在时间轴最后留多久
    static let receiptStays: TimeInterval = 600

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        content(now: context.date)
                    }
                    .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                    .padding(.bottom, PourSpace.pageEnd)
                }
                .onChange(of: model.lastSent) { _, id in
                    guard let id else { return }
                    withAnimation(PourMotion.smooth) { reader.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .background(PourColor.canvas.color)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showsSettings = true
                } label: {
                    PourAvatar("我", size: PourSize.avatarInline + PourSpace.inline)
                }
                .accessibilityLabel(Text("设置"))
                .accessibilityIdentifier("today.settings")
            }
        }
        .sheet(isPresented: $showsSettings) { SettingsSheet() }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let day = model.day
        let receipts = day.notes.filter { Self.showsReceipt($0, now: now) }
        let receiptIds = Set(receipts.map(\.id))
        let timeline = day.entries.filter { !receiptIds.contains($0.noteId) }
        let said = Dictionary(day.notes.map { ($0.id, $0.localTime) }, uniquingKeysWith: { first, _ in first })

        VStack(alignment: .leading, spacing: 0) {
            header(day.day)
            if let problem = model.problem {
                Text(problem).pourText(.callout).foregroundStyle(PourColor.attention.color)
                    .padding(.top, PourSpace.element)
            }
            if timeline.isEmpty && receipts.isEmpty {
                PourEmptyState(systemImage: "sun.max", title: "今天还是空白", example: "中午吃了碗牛肉面 28")
                    .accessibilityIdentifier("today.empty")
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(timeline.enumerated()), id: \.element.id) { index, entry in
                    let line = RecordLine(
                        entry.data, categories: day.categories, said: said[entry.noteId] ?? day.day,
                        today: model.today)
                    PourTimelineRow(
                        time: line.time, domain: line.moodLevel == nil ? PourDomain(line.color) : nil,
                        isLast: index == timeline.count - 1 && receipts.isEmpty
                    ) {
                        TimelineLine(line: line, needsConfirmation: entry.needsConfirmation)
                    }
                    .transition(.opacity.combined(with: .offset(y: PourSpace.related)))
                }
            }
            .padding(.top, PourSpace.section)
            VStack(alignment: .leading, spacing: PourSpace.element) {
                ForEach(receipts) { note in
                    PourCard {
                        NoteReceipt(note: note, entries: day.noteEntries.filter { $0.noteId == note.id }, day: day)
                    }
                    .id(note.id)
                    .transition(.opacity.combined(with: .offset(y: PourSpace.related)))
                }
            }
            .padding(.top, timeline.isEmpty ? PourSpace.group : PourSpace.element)
        }
        .animation(PourMotion.smooth, value: receipts.map(\.id))
        .animation(PourMotion.smooth, value: timeline.map(\.id))
    }

    private func header(_ day: DayString) -> some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            Text(PourFormat.dayTitle(day, today: model.today)).pourText(.titlePage)
                .foregroundStyle(PourColor.ink.color)
                .accessibilityAddTraits(.isHeader)
            Text("\(PourFormat.monthDay(day, today: model.today)) \(PourFormat.weekday(day))")
                .pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.header")
    }

    /// 刚说的话以收据出现：还没整理好的、没整理成的，和整理好不到 10 分钟的
    static func showsReceipt(_ note: Note, now: Date) -> Bool {
        guard note.status == .done else { return true }
        return now.timeIntervalSince(note.finishedAt ?? .distantPast) < receiptStays
    }
}

/// 一段原话的收据：原话、整理到哪了、整理成了什么
private struct NoteReceipt: View {
    @Environment(AppModel.self) private var model
    let note: Note
    let entries: [Entry]
    let day: DaySnapshot

    var body: some View {
        ReceiptView(
            time: PourFormat.clock(note.localTime), quote: note.text, state: state, lines: lines,
            question: question, waitingSince: note.createdAt, problem: note.problem, reply: note.reply,
            condenses: model.watching.contains(note.id)
        ) {
            model.retry(note.id)
        }
        .accessibilityIdentifier("receipt.\(note.id)")
    }

    private var state: ReceiptState {
        switch note.status {
        case .queued, .organizing: .organizing
        case .waitingForNetwork: .waitingForNetwork
        case .failed: .failed
        case .done: .done
        }
    }

    private var lines: [ReceiptLine] {
        entries.map { entry in
            let line = RecordLine(entry.data, categories: day.categories, said: note.localTime, today: model.today)
            // 记在别的日子的（「昨天跑了五公里」）：说清是哪天
            let when = entry.day == note.day ? "" : " · \(PourFormat.dayTitle(entry.day, today: model.today))"
            let title: String
            switch entry.data {
            case .mood: title = "心情 \(line.title)" + (line.detail.map { " · \($0)" } ?? "")
            case .todo: title = "待办 \(line.title)" + (line.detail.map { " · \($0)" } ?? "")
            case .insight: title = "感悟 \(line.title)"
            case .event: title = line.title
            }
            return ReceiptLine(
                domain: PourDomain(line.color), title: title + when, person: line.person, value: line.value,
                needsConfirmation: entry.needsConfirmation)
        }
    }

    /// 一次只问一个（规范 12）：先问第一条要确认的。回答在 M2b 接上，现在只说 AI 拿不准什么
    private var question: QuestionPrompt? {
        entries.compactMap(\.question).first.map { QuestionPrompt($0, options: []) }
    }
}

/// 时间轴上的一行：领域色点 + 一行字，右边是数；心情画心情格子；要确认的标「待确认」
private struct TimelineLine: View {
    let line: RecordLine
    let needsConfirmation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.tight) {
            if let level = line.moodLevel {
                HStack(spacing: PourSpace.related) {
                    PourMoodCell(level: level)
                    Text(line.title).pourText(.body).foregroundStyle(PourColor.ink.color)
                    if let detail = line.detail {
                        Text(detail).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                    }
                }
            } else {
                PourTitleValueRow {
                    Text(line.title, person: line.person).pourText(.body).foregroundStyle(PourColor.ink.color)
                } value: {
                    if let value = line.value {
                        Text(value).pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                    }
                }
                if let detail = line.detail {
                    Text(detail).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                }
            }
            if needsConfirmation {
                Text("待确认").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension PourDomain {
    /// 类别表里的颜色名（stone、moss……）→ 领域色；对不上是「石」
    init(_ name: String) { self = PourDomain(rawValue: name) ?? .stone }
}
