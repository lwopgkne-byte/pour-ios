import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一件待办的详情（01 需求文档 4.3、06 交互细节 2.4）：标题直接点着改；原话；哪天、几点提醒、重复都点选，不打字
/// （常用的几个一点就选，别的用系统的月历、时间滚轮）；和谁、东西、地方；底部「完成」、红字「删除这件待办」。
/// 改了马上生效（先改界面再发）
struct TodoDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let row: API.TodoRow
    @State private var title: String
    @State private var pickingDay = false
    @State private var pickingTime = false
    @State private var pickingWeekdays = false
    @FocusState private var editingTitle: Bool

    init(row: API.TodoRow) {
        self.row = row
        _title = State(initialValue: row.content)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    titleRow
                    if let source = row.source { quote(source) }
                    VStack(alignment: .leading, spacing: 0) {
                        dayRow
                        Divider().padding(.leading, Theme.Space.regular)
                        timeRow
                        Divider().padding(.leading, Theme.Space.regular)
                        repeatRow
                    }
                    .themeCard(padding: 0)
                    TodoRelatedRows(row: row)
                    actions
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.xLarge)
            }
        }
        .background(Theme.Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: editingTitle) { _, now in if !now { saveTitle() } }
    }

    // MARK: - 标题、原话

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 0) {
            TodoCircle(done: row.done, label: row.content) { model.setDone(row.id, !row.done) }
                .padding(.leading, -Theme.Space.medium + Theme.Space.hairline)
            TextField("要做的事", text: $title, axis: .vertical)
                .font(Theme.Typeface.summary.weight(.semibold))
                .lineLimit(1...4)
                .focused($editingTitle)
                .submitLabel(.done)
                .onSubmit(saveTitle)
                .padding(.top, Theme.Space.small)
                .accessibilityIdentifier("todoDetail.title")
        }
    }

    private func quote(_ source: API.TodoRow.Source) -> some View {
        Button {
            dismiss()
            model.openLink("/library?note=\(source.noteId)")
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                QuoteBlock(source.text, highlight: row.content, lineLimit: 4)
                if let at = source.at.flatMap(TodoBoard.saidAt) {
                    Text(at).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .padding(.leading, Theme.Space.medium)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            .contentShape(Rectangle())
            // 读屏一句念完：原话、什么时候说的
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("在笔记库里看这段原话"))
    }

    // MARK: - 哪天、提醒、重复

    private var dayRow: some View {
        let today = model.today
        let choices = [
            ("今天", today), ("明天", PourDate.addDays(today, 1)),
            ("周六", SnoozePreset.saturday.target(now: Date(), today: today).day),
            ("下周一", SnoozePreset.monday.target(now: Date(), today: today).day),
        ]
        return pickRow("日期", symbol: "calendar", tint: Theme.Palette.bad) {
            ForEach(choices, id: \.0) { choice in
                FilterChip(choice.0, selected: row.day == choice.1) { model.editTodo(row.id, day: choice.1) }
            }
            FilterChip(
                choices.contains { $0.1 == row.day } ? "选日子" : TodoBoard.dayName(row.day, today: today),
                selected: !choices.contains { $0.1 == row.day }
            ) { pickingDay.toggle() }
            .accessibilityHint(Text("选别的日子"))
        } extra: {
            if pickingDay {
                DatePicker("日期", selection: dayBinding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.Palette.accentFill)
            }
        }
    }

    private var timeRow: some View {
        pickRow("提醒", symbol: Theme.Symbol.remind, tint: Theme.Palette.accent) {
            ForEach(["09:00", "12:00", "15:00", "17:30", "20:00"], id: \.self) { time in
                FilterChip(time, selected: row.remindAt == time) { model.editTodo(row.id, time: .some(time)) }
            }
            FilterChip("不提醒", selected: row.remindAt == nil) { model.editTodo(row.id, time: .some(nil)) }
            FilterChip(otherTime ?? "别的时间", selected: otherTime != nil) { pickingTime.toggle() }
        } extra: {
            if pickingTime {
                DatePicker("几点", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 不在常用那几个里的钟点
    private var otherTime: String? {
        guard let time = row.remindAt, !["09:00", "12:00", "15:00", "17:30", "20:00"].contains(time) else { return nil }
        return time
    }

    private var repeatRow: some View {
        pickRow("重复", symbol: Theme.Symbol.repeats, tint: Theme.Palette.good) {
            FilterChip("不重复", selected: row.repeat == nil) { model.editTodo(row.id, repeat: .some(nil)) }
            FilterChip("每天", selected: row.repeat == .daily) { model.editTodo(row.id, repeat: .some(.daily)) }
            FilterChip("工作日", selected: row.repeat == .weekdays) { model.editTodo(row.id, repeat: .some(.weekdays)) }
            FilterChip(weeklyTitle, selected: weekly != nil) {
                if weekly == nil {
                    model.editTodo(row.id, repeat: .some(.weekly([PourDate.weekdayMon0(row.day)])))
                }
                pickingWeekdays = true
            }
            FilterChip(monthlyTitle, selected: monthly) {
                model.editTodo(row.id, repeat: .some(.monthly(Int(row.day.suffix(2)) ?? 1)))
            }
        } extra: {
            if pickingWeekdays, let days = weekly { weekdayPicker(days) }
        }
    }

    private var weekly: [Int]? {
        if case .weekly(let days) = row.repeat { return days }
        return nil
    }

    private var monthly: Bool {
        if case .monthly = row.repeat { return true }
        return false
    }

    private var weeklyTitle: String { weekly.map { _ in row.repeatText ?? "每周" } ?? "每周" }
    private var monthlyTitle: String { monthly ? (row.repeatText ?? "每月") : "每月" }

    /// 每周几：一到日七个圆，点了加上、再点去掉（至少留一天）
    private func weekdayPicker(_ days: [Int]) -> some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(0..<7, id: \.self) { day in
                let picked = days.contains(day)
                Button {
                    let next = picked ? days.filter { $0 != day } : (days + [day]).sorted()
                    guard !next.isEmpty else { return }
                    model.editTodo(row.id, repeat: .some(.weekly(next)))
                } label: {
                    Text(["一", "二", "三", "四", "五", "六", "日"][day]).font(Theme.Typeface.subheadline)
                        .foregroundStyle(picked ? Theme.Palette.onAccent : Theme.Palette.label)
                        .frame(
                            width: Theme.Size.touch - Theme.Space.tight, height: Theme.Size.touch - Theme.Space.tight
                        )
                        .background(picked ? Theme.Palette.accentFill : Theme.Palette.fill, in: Circle())
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(Text("周" + ["一", "二", "三", "四", "五", "六", "日"][day]))
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 一行：左边名字和图标，右边一排能点的胶囊；下面可以展开系统的选择器
    private func pickRow<Chips: View, Extra: View>(
        _ name: String, symbol: String, tint: Color, @ViewBuilder chips: () -> Chips, @ViewBuilder extra: () -> Extra
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Label(name, systemImage: symbol).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                .labelStyle(TintedIcon(tint: tint))
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) { chips() }
            extra()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.regular)
    }

    // MARK: - 完成、删除

    private var actions: some View {
        VStack(spacing: Theme.Space.small) {
            Button {
                if !row.done { model.setDone(row.id, true) }
                dismiss()
            } label: {
                Label(row.done ? "已完成" : "完成", systemImage: Theme.Symbol.done)
                    .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.composer - Theme.Space.small)
                    .background(Theme.Palette.accentFill, in: Theme.rounded(Theme.Corner.hubTile))
            }
            .buttonStyle(PressScale())
            .accessibilityIdentifier("todoDetail.done")
            Button {
                model.deleteTodo(row)
            } label: {
                Text("删除这件待办").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.bad)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("todoDetail.delete")
        }
        .padding(.top, Theme.Space.small)
    }

    // MARK: - 帮手

    private func saveTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != row.content else {
            title = row.content
            return
        }
        model.editTodo(row.id, content: trimmed)
    }

    /// 系统月历选的日子 ↔「2026-10-30」
    private var dayBinding: Binding<Date> {
        Binding {
            Calendar.current.date(from: Self.parts(row.day)) ?? Date()
        } set: { date in
            let day = String(PourDate.localDateTime(date, in: .current).prefix(10))
            model.editTodo(row.id, day: day)
            pickingDay = false
        }
    }

    /// 系统时间滚轮 ↔「17:30」
    private var timeBinding: Binding<Date> {
        Binding {
            var parts = Self.parts(row.day)
            let clock = (row.remindAt ?? "09:00").split(separator: ":").compactMap { Int($0) }
            parts.hour = clock.first
            parts.minute = clock.last
            return Calendar.current.date(from: parts) ?? Date()
        } set: { date in
            model.editTodo(row.id, time: .some(String(PourDate.localDateTime(date, in: .current).suffix(5))))
        }
    }

    private static func parts(_ day: String) -> DateComponents {
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return DateComponents() }
        return DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
    }
}

/// 名字前面的图标着色（日期红、提醒蓝、重复绿，照原型）
private struct TintedIcon: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.snug) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
