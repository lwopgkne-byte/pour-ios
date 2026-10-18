import PourCore
import PourData
import PourDesign
import SwiftUI

/// 今天 ——「我今天过得怎么样」（规范 12 第 3 节）：日子头、时间轴，刚说的话就地出现收据。
/// 刚说的（还在整理、没整理成、整理好不到 10 分钟的）以收据出现在时间轴最后；过了 10 分钟，它的记录回到时间轴上自己的位置
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false

    /// 整理好以后，收据在时间轴最后留多久（界面测试用 -shortReceipts 缩成 3 秒）
    static let receiptStays: TimeInterval = ProcessInfo.processInfo.arguments.contains("-shortReceipts") ? 3 : 600
    /// 多久看一次收据该不该回到时间轴
    static let refresh: TimeInterval = ProcessInfo.processInfo.arguments.contains("-shortReceipts") ? 1 : 30

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView {
                    TimelineView(.periodic(from: .now, by: Self.refresh)) { context in
                        content(now: context.date)
                    }
                    .padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                    .padding(.bottom, PourSpace.pageEnd)
                }
                // 左右滑换日子：往左滑看后一天，往右滑看前一天（横着滑得够远、比竖着滑得多才算）
                .simultaneousGesture(
                    DragGesture(minimumDistance: PourSpace.group).onEnded { drag in
                        let across = drag.translation.width
                        guard abs(across) > PourSize.minTap * 2, abs(across) > abs(drag.translation.height) * 1.5
                        else { return }
                        model.show(PourDate.addDays(model.shownDay, across < 0 ? 1 : -1))
                    }
                )
                .onChange(of: model.lastSent) { _, id in
                    guard let id else { return }
                    withAnimation(PourMotion.smooth) { reader.scrollTo(id, anchor: .bottom) }
                }
                // 刚说的那段整理好了，收据变高：再滚一次，让凝结出来的每一行都露在倾倒栏上面
                .onChange(of: lastSentStatus) { _, _ in
                    guard let id = model.lastSent else { return }
                    withAnimation(PourMotion.smooth) { reader.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .background(PourColor.canvas.color)
        // 撤销条浮在底部、倾倒栏上面，5 秒后自己消失（规范 12）；放进底部的安全区，刚凝结的那几行不会被它挡住
        .safeAreaInset(edge: .bottom) {
            if let undo = model.undoable {
                UndoToast(undo.message) { model.undo() }
                    .padding(.bottom, PourSpace.element)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(undo.id)
            }
        }
        .animation(PourMotion.smooth, value: model.undoable)
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

    private var lastSentStatus: Note.Status? { model.day.notes.first { $0.id == model.lastSent }?.status }

    @ViewBuilder private func content(now: Date) -> some View {
        let day = model.day
        let receipts = day.notes.filter { Self.showsReceipt($0, now: now) }
        let receiptIds = Set(receipts.map(\.id))
        let timeline = day.entries.filter { !receiptIds.contains($0.noteId) }
        let said = Dictionary(day.notes.map { ($0.id, $0.localTime) }, uniquingKeysWith: { first, _ in first })

        VStack(alignment: .leading, spacing: 0) {
            header(day)
            if let problem = model.problem {
                Text(problem).pourText(.callout).foregroundStyle(PourColor.attention.color)
                    .padding(.top, PourSpace.element)
            }
            if timeline.isEmpty && receipts.isEmpty { emptyState(day.day) }
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
                    .contentShape(Rectangle())
                    .onTapGesture { model.detail = .init(id: entry.id) }
                    // 一行是一个元素：时刻和内容一起读，当按钮读
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(Text("看原话和改动"))
                    .accessibilityAction { model.detail = .init(id: entry.id) }
                    .transition(.opacity.combined(with: .offset(y: PourSpace.related)))
                }
            }
            .padding(.top, PourSpace.section)
            VStack(alignment: .leading, spacing: PourSpace.element) {
                ForEach(receipts) { note in
                    PourCard { NoteReceipt(note: note, day: day) }
                        .id(note.id)
                        .transition(.opacity.combined(with: .offset(y: PourSpace.related)))
                }
            }
            .padding(.top, timeline.isEmpty ? PourSpace.group : PourSpace.element)
        }
        .animation(PourMotion.smooth, value: receipts.map(\.id))
        .animation(PourMotion.smooth, value: timeline.map(\.id))
    }

    /// 日子头：大标题（今天 / 昨天 / 10月14日）、日期和一句话总结（AI 写的，带标识）；右边换到前一天、后一天
    private func header(_ snapshot: DaySnapshot) -> some View {
        let day = snapshot.day
        let date =
            PourDate.diffDays(day, model.today) >= -1
            ? "\(PourFormat.monthDay(day, today: model.today)) \(PourFormat.weekday(day))" : PourFormat.weekday(day)
        return HStack(alignment: .top, spacing: PourSpace.related) {
            VStack(alignment: .leading, spacing: PourSpace.related) {
                Text(PourFormat.dayTitle(day, today: model.today)).pourText(.titlePage)
                    .foregroundStyle(PourColor.ink.color)
                    .accessibilityAddTraits(.isHeader)
                if let summary = snapshot.summary {
                    PourAIText("\(date) · \(summary)", style: .meta, color: PourColor.inkSecondary)
                } else {
                    Text(date).pourText(.meta).foregroundStyle(PourColor.inkSecondary.color)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("today.header")
            Spacer(minLength: PourSpace.related)
            // 左右滑换日子的看得见的替代（规范 12：每个手势都有看得见的替代）
            HStack(spacing: 0) {
                PourIconButton("chevron.left", label: "前一天") { model.show(PourDate.addDays(day, -1)) }
                PourIconButton("chevron.right", label: "后一天") { model.show(PourDate.addDays(day, 1)) }
                    .disabled(day >= model.today)
                    .opacity(day >= model.today ? 0.3 : 1)
            }
        }
    }

    /// 空的一天：今天给一个能照着说的例子；以前的日子也能补，说的时候带上是哪天
    @ViewBuilder private func emptyState(_ day: DayString) -> some View {
        if day == model.today {
            PourEmptyState(systemImage: "sun.max", title: "今天还是空白", example: "中午吃了碗牛肉面 28")
                .accessibilityIdentifier("today.empty")
        } else {
            PourEmptyState(
                systemImage: "calendar", title: "这一天没有记录",
                example: "\(PourFormat.dayTitle(day, today: model.today))跑了五公里"
            )
            .accessibilityIdentifier("today.empty")
        }
    }

    /// 刚说的话以收据出现：还没整理好的、没整理成的，和整理好不到 10 分钟的
    static func showsReceipt(_ note: Note, now: Date) -> Bool {
        guard note.status == .done else { return true }
        return now.timeIntervalSince(note.finishedAt ?? .distantPast) < receiptStays
    }
}

/// 一段原话的收据：原话、整理到哪了、这段话做了什么（一行一件：记下、修改、删掉、之前已记过……）
private struct NoteReceipt: View {
    @Environment(AppModel.self) private var model
    let note: Note
    let day: DaySnapshot

    var body: some View {
        ReceiptView(
            time: PourFormat.clock(note.localTime), quote: note.text, state: state, lines: lines,
            question: question, waitingSince: note.createdAt, problem: note.problem, reply: note.reply,
            replyByProgram: note.replyByProgram,
            condenses: model.watching.contains(note.id), undone: note.undoneAt != nil,
            onAnswer: { model.answer($0) },
            onOpen: { line in if let key = line.key { model.detail = .init(id: key) } },
            onRetry: { model.retry(note.id) }
        )
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
        note.actions.compactMap { action in
            // 后来删掉了的不再列（这段话本身就是删它的除外）
            guard let entry = day.mentioned[action.entryId], action.kind == .deleted || !entry.deleted else {
                return nil
            }
            let line = RecordLine(entry.data, categories: day.categories, said: note.localTime, today: model.today)
            // 记在别的日子的（「昨天跑了五公里」）：说清是哪天
            let when = entry.day == note.day ? "" : " · \(PourFormat.dayTitle(entry.day, today: model.today))"
            let what: String
            switch entry.data {
            case .mood: what = "心情 \(line.title)" + (line.detail.map { " · \($0)" } ?? "")
            case .todo: what = "待办 \(line.title)" + (line.detail.map { " · \($0)" } ?? "")
            case .insight: what = "感悟 \(line.title)"
            case .event: what = line.title
            }
            let verb = action.kind == .created ? "" : "\(action.kind.word) "
            let alive = action.kind != .deleted
            return ReceiptLine(
                domain: PourDomain(line.color), title: verb + what + when, person: line.person, value: line.value,
                needsConfirmation: alive && entry.needsConfirmation, key: alive ? entry.id : nil)
        }
    }

    /// 一次只问一个（规范 12）：先问这段话问你的，再问它记下、改过、还没确认的那条。是不是的问题给「对 / 不对」
    private var question: QuestionPrompt? {
        let asking =
            note.questions.first
            ?? note.actions.lazy.compactMap { day.mentioned[$0.entryId] }.filter { !$0.deleted }.compactMap(\.question)
            .first
        guard let asking, note.undoneAt == nil else { return nil }
        return QuestionPrompt(asking, options: asking.hasSuffix("吗？") ? ["对", "不对"] : [])
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
