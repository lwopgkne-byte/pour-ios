import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 日历（可交互原型「日历」；「我的 → 回看 → 日历」进来）：按月看每一天——每一格写几号、那天心情的表情、花了多少；
/// 今天一圈蓝框，还没到的日子浅灰。点一天打开那天的生活画布。右上角 ‹ › 换月，左右滑也行。
/// 心情和钱各拿各的（心情页、钱的那个月）；遮住金额、钱锁着还没打开时写「¥•••」
struct CalendarPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    @AppStorage(MoneyLock.key) private var locked = false
    let month: String
    @State private var mood: [String: Int] = [:]
    @State private var spent: [String: Double] = [:]
    @State private var loaded = false
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                Text("按月看每一天；点一天打开那天的生活画布").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.horizontal, Theme.Space.tight)
                if let problem, !loaded {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    grid
                        .padding(.vertical, Theme.Space.small + Theme.Space.hairline)
                        .padding(.horizontal, Theme.Space.snug)
                        .themeCard(radius: Theme.Corner.smallCard, padding: 0)
                        .gesture(swipe)
                        .redacted(reason: loaded ? [] : .placeholder)
                    Text("每一格：那天的心情、花了多少。").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .padding(.horizontal, Theme.Space.tight)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.section)
        }
        .navigationTitle(month == String(model.today.prefix(7)) ? "日历" : "日历 · \(Show.monthName(month))")
        .toolbar { toolbar }
        .refreshable { await load() }
        .task(id: "\(month)-\(model.dataVersion)") { await load() }
    }

    // MARK: - 月历

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Space.tight) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { name in
                Text(name).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minHeight: Theme.Size.dotRow)
                    .accessibilityHidden(true)
            }
            ForEach(0..<PourDate.weekdayMon0("\(month)-01"), id: \.self) { _ in
                Color.clear.frame(height: 1).accessibilityHidden(true)
            }
            ForEach(days, id: \.self) { day in cell(day) }
        }
    }

    private func cell(_ day: String) -> some View {
        let future = day > model.today
        let isToday = day == model.today
        let amount = spent[day] ?? 0
        return Button {
            model.goHome()
            model.show(day)
        } label: {
            VStack(spacing: Theme.Space.hairline) {
                Text("\(Int(day.suffix(2)) ?? 0)").font(Theme.Typeface.caption).monospacedDigit()
                    .foregroundStyle(future ? Theme.Palette.tertiaryLabel : Theme.Palette.secondaryLabel)
                if !future, let level = mood[day] {
                    MoodBadge(level: level, size: Theme.Size.tickRow + Theme.Space.hairline)
                } else {
                    Color.clear.frame(width: 1, height: Theme.Size.tickRow + Theme.Space.hairline)
                }
                Text(!future && amount > 0 ? Self.short(amount, hide: hide || (locked && !model.moneyUnlocked)) : " ")
                    .font(Theme.Typeface.tick).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.top, Theme.Space.snug)
            .frame(
                maxWidth: .infinity, minHeight: Theme.Size.touch + Theme.Space.medium + Theme.Space.snug,
                alignment: .top
            )
            .opacity(future ? 0.32 : 1)
            .overlay {
                if isToday {
                    Theme.rounded(Theme.Corner.chip).strokeBorder(
                        Theme.Palette.accent, lineWidth: Theme.Space.hairline * 0.75)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .disabled(future)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken(day, amount: amount, future: future)))
        .accessibilityHint(Text(future ? "" : "打开那天的生活画布"))
        // 合成一句念以后它就不算按钮了：补上（读屏、界面测试都按按钮认）
        .accessibilityAddTraits(isToday ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("calendar.\(day)")
    }

    /// 读屏念的：「10月24日，挺好，花了 ¥1,978」
    private func spoken(_ day: String, amount: Double, future: Bool) -> String {
        var parts = [Show.monthDay(day)]
        if future { return parts[0] }
        parts.append(mood[day].map { Theme.Mood.names[min(5, max(1, $0)) - 1] } ?? "没说心情")
        if amount > 0 { parts.append("花了 \(Show.yuan(amount, hide: hide || (locked && !model.moneyUnlocked)))") }
        return parts.joined(separator: "，")
    }

    /// 一格里放得下的钱：「¥1,978」「¥1.2万」
    static func short(_ amount: Double, hide: Bool) -> String {
        if hide { return "¥•••" }
        if amount >= 10000 { return "¥\(String(format: "%.1f", amount / 10000))万" }
        return Show.yuan(amount, hide: false)
    }

    /// 这个月的每一天
    private var days: [String] {
        let count = (28...31).last { PourDate.isValid("\(month)-\(String(format: "%02d", $0))") } ?? 30
        return (1...count).map { "\(month)-\(String(format: "%02d", $0))" }
    }

    // MARK: - 换月

    private var prevMonth: String { String(PourDate.addDays("\(month)-01", -1).prefix(7)) }
    private var nextMonth: String? {
        let next = String(PourDate.addDays(days.last ?? "\(month)-28", 1).prefix(7))
        return next <= String(model.today.prefix(7)) ? next : nil
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                go(prevMonth)
            } label: {
                Image(systemName: "chevron.left").font(Theme.Typeface.toolbarIcon)
            }
            .accessibilityLabel(Text("上个月"))
            .accessibilityIdentifier("calendar.prev")
            Button {
                if let nextMonth { go(nextMonth) }
            } label: {
                Image(systemName: "chevron.right").font(Theme.Typeface.toolbarIcon)
            }
            .disabled(nextMonth == nil)
            .accessibilityLabel(Text("下个月"))
            .accessibilityIdentifier("calendar.next")
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: Theme.Size.touch).onEnded { drag in
            guard abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
            if drag.translation.width < 0, let nextMonth { go(nextMonth) }
            if drag.translation.width > 0 { go(prevMonth) }
        }
    }

    /// 换一个月：同一种页面，换掉这一页
    private func go(_ other: String) {
        model.open(other == String(model.today.prefix(7)) ? "/calendar" : "/calendar/\(other)")
    }

    // MARK: - 数据

    /// 心情和钱各拿各的：拿到一样就先显示一样；两样都拿不到才说出了什么问题
    private func load() async {
        var failed: String?
        do throws(APIError) {
            let page = try await model.client.moodPage(month)
            mood = Dictionary(page.days.map { ($0.day, $0.level) }, uniquingKeysWith: { first, _ in first })
        } catch {
            failed = error.message
        }
        do throws(APIError) {
            let page = try await model.client.moneyMonth(month)
            spent = Dictionary(page.days.map { ($0.day, $0.spent) }, uniquingKeysWith: { first, _ in first })
        } catch {
            failed = failed ?? error.message
        }
        problem = failed
        loaded = failed == nil || !mood.isEmpty || !spent.isEmpty
    }
}
