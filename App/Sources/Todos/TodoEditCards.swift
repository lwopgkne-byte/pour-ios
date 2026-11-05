import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 编辑弹框里的两张卡（待办 2.0 第 5 步）：放进哪一格（2×2：左上马上做、右上排时间、左下快速办、右下放一放），
/// 日期和时间（时间三选一：不定时、上午 / 下午 / 晚上、🔔几点；下面一行说怎么提醒）
struct TodoEditCards: View {
    @Binding var draft: TodoDraft
    let row: API.TodoRow
    let today: String
    @Binding var pickingDay: Bool
    @Binding var pickingTime: Bool

    var body: some View {
        VStack(spacing: Theme.Space.medium) {
            quadrantCard
            whenCard
        }
    }

    // MARK: - 放进哪一格

    private var quadrantCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("放进哪一格").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                Spacer()
                if row.guessed && draft.quadrant == row.lane {
                    Label("AI 猜的，点别的就改", systemImage: "sparkles").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            LazyVGrid(columns: Self.columns, spacing: Theme.Space.small + Theme.Space.hairline) {
                ForEach(TodoQuadrant.sorted, id: \.self) { lane in
                    QuadrantChoice(
                        quadrant: lane.rawValue, title: lane.title, subtitle: lane.subtitle,
                        selected: draft.quadrant == lane
                    ) {
                        // 再点一下选中的：回到还没分
                        draft.quadrant = draft.quadrant == lane ? .unsorted : lane
                    }
                    .accessibilityIdentifier("todoDetail.quadrant.\(lane.rawValue)")
                }
            }
        }
        .padding(Theme.Space.regular)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
        .themeSelectionFeedback(trigger: draft.quadrant)
    }

    private static let columns = [
        GridItem(.flexible(), spacing: Theme.Space.small + Theme.Space.hairline),
        GridItem(.flexible(), spacing: Theme.Space.small + Theme.Space.hairline),
    ]

    // MARK: - 日期、时间

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Label("日期", systemImage: "calendar").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            chips { dayChips }
            if pickingDay { dayPicker }
            Label("时间", systemImage: "clock")
                .padding(.top, Theme.Space.small).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            if draft.day != nil {
                chips { timeChips }
                if pickingTime { timePicker }
            }
            Text(hint).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("todoDetail.hint")
        }
        .padding(Theme.Space.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
    }

    /// 一排芯片（看得见的 36 高、点的地方 44：排的时候行和行隔 8）
    private func chips(@ViewBuilder _ content: () -> some View) -> some View {
        let slack = Theme.Size.touch - Theme.Size.editChip
        return PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small - slack) { content() }
            .padding(.vertical, -slack / 2)
    }

    /// 今天 · 明天 · 周六 · 下周一 · 选日子（挑了别的日子写那一天，以后再说写「以后再说」）
    @ViewBuilder private var dayChips: some View {
        let choices = Self.dayChoices(today: today)
        ForEach(choices, id: \.day) { choice in
            EditChip(choice.title, selected: draft.day == choice.day) {
                draft.day = choice.day
                pickingDay = false
            }
        }
        let other = !choices.contains { $0.day == draft.day }
        EditChip(other ? (draft.day.map(Show.monthDay) ?? "以后再说") : "选日子", selected: other) {
            withAnimation(Theme.Motion.standard) { pickingDay.toggle() }
        }
        .accessibilityIdentifier("todoDetail.pickDay")
    }

    /// 选日子：系统的月历，旁边「以后再说」（不定日子，不放进今天）
    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            DatePicker("日期", selection: dayBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.Palette.accentFill)
            EditChip("以后再说", symbol: "tray", selected: draft.day == nil) {
                draft.day = nil
                draft.time = nil
                draft.window = nil
                pickingDay = false
            }
            .accessibilityIdentifier("todoDetail.someday")
        }
    }

    /// 不定时 · 上午 · 下午 · 晚上 · 🔔几点（选了钟点就地写「🔔 12:30」，位置不变）
    @ViewBuilder private var timeChips: some View {
        EditChip("不定时", selected: draft.time == nil && draft.window == nil) {
            draft.time = nil
            draft.window = nil
            pickingTime = false
        }
        ForEach(TimeWindow.allCases, id: \.self) { window in
            EditChip(window.title, selected: draft.time == nil && draft.window == window) {
                draft.time = nil
                draft.window = window
                pickingTime = false
            }
        }
        EditChip(draft.time ?? "几点", symbol: "bell", selected: draft.time != nil) {
            if draft.time == nil { draft.time = Self.nextHour() }
            draft.window = nil
            withAnimation(Theme.Motion.standard) { pickingTime = true }
        }
        .accessibilityIdentifier("todoDetail.clock")
    }

    private var timePicker: some View {
        DatePicker("几点", selection: timeBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
    }

    /// 下面一行：怎么提醒
    private var hint: String {
        guard draft.day != nil else { return "以后再说：不放进今天，也不提醒" }
        if let time = draft.time { return "\(time) 准点提醒" }
        if let window = draft.window {
            let hour = Int(window.nudge.prefix(2)) ?? 0
            return "\(window.title) \(hour > 12 ? hour - 12 : hour) 点轻提醒一次 · 要准点就点「几点」"
        }
        return "不定时：不提醒，放在今天最上面"
    }

    // MARK: - 帮手

    /// 今天、明天、这个周六、下周一（和推迟到的规矩一样）
    static func dayChoices(today: String) -> [(title: String, day: String)] {
        [
            ("今天", today), ("明天", PourDate.addDays(today, 1)),
            ("周六", SnoozePreset.saturday.target(now: Date(), today: today).day),
            ("下周一", SnoozePreset.monday.target(now: Date(), today: today).day),
        ]
    }

    /// 刚点「几点」时先给下一个整点
    static func nextHour(now: Date = Date()) -> String {
        let hour = min(23, Calendar.current.component(.hour, from: now) + 1)
        return String(format: "%02d:00", hour)
    }

    private var dayBinding: Binding<Date> {
        Binding {
            Calendar.current.date(from: Self.parts(draft.day ?? today)) ?? Date()
        } set: { date in
            draft.day = String(PourDate.localDateTime(date, in: .current).prefix(10))
            pickingDay = false
        }
    }

    private var timeBinding: Binding<Date> {
        Binding {
            var parts = Self.parts(draft.day ?? today)
            let clock = (draft.time ?? "09:00").split(separator: ":").compactMap { Int($0) }
            parts.hour = clock.first
            parts.minute = clock.last
            return Calendar.current.date(from: parts) ?? Date()
        } set: { date in
            draft.time = String(PourDate.localDateTime(date, in: .current).suffix(5))
            draft.window = nil
        }
    }

    private static func parts(_ day: String) -> DateComponents {
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return DateComponents() }
        return DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
    }
}

/// 重复：不重复 · 每天 · 工作日 · 每周（选了再挑周几）· 每月（那一天）
struct TodoRepeatPicker: View {
    @Binding var rule: API.Repeat?
    let day: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: 0) {
                EditChip("不重复", selected: rule == nil) { rule = nil }
                EditChip("每天", selected: rule == .daily) { rule = .daily }
                EditChip("工作日", selected: rule == .weekdays) { rule = .weekdays }
                EditChip(weekly == nil ? "每周" : (rule?.text ?? "每周"), selected: weekly != nil) {
                    if weekly == nil { rule = .weekly([PourDate.weekdayMon0(day)]) }
                }
                EditChip(monthly ? (rule?.text ?? "每月") : "每月", selected: monthly) {
                    rule = .monthly(Int(day.suffix(2)) ?? 1)
                }
            }
            if let days = weekly { weekdays(days) }
        }
    }

    private var weekly: [Int]? {
        if case .weekly(let days) = rule { return days }
        return nil
    }

    private var monthly: Bool {
        if case .monthly = rule { return true }
        return false
    }

    /// 每周几：一到日七个圆，点了加上、再点去掉（至少留一天）
    private func weekdays(_ days: [Int]) -> some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(0..<7, id: \.self) { index in
                let picked = days.contains(index)
                let name = ["一", "二", "三", "四", "五", "六", "日"][index]
                Button {
                    let next = picked ? days.filter { $0 != index } : (days + [index]).sorted()
                    guard !next.isEmpty else { return }
                    rule = .weekly(next)
                } label: {
                    Text(name).font(Theme.Typeface.subheadline)
                        .foregroundStyle(picked ? Theme.Palette.onAccent : Theme.Palette.label)
                        .frame(
                            width: Theme.Size.touch - Theme.Space.tight, height: Theme.Size.touch - Theme.Space.tight
                        )
                        .background(picked ? Theme.Palette.label : Theme.Palette.fill, in: Circle())
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(Text("周" + name))
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}
