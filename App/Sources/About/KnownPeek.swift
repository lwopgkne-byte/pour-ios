import PourAPI
import PourDesign
import SwiftUI

/// 「Pour 认识的」一条的详情：作息、常做的事、人、地方、说法。
/// 点一条依据：这一层收起，打开那条记录的详情
struct KnownPeek: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: KnownStore
    let key: String

    var body: some View {
        WebPeek(title: title) {
            if let about = store.about {
                content(about)
            } else {
                WebSkeleton(height: Web.space16)
            }
        }
    }

    private var title: String {
        guard let about = store.about else { return "" }
        if key == "sleep" { return "作息" }
        if let habit = about.habits.first(where: { $0.key == key }) { return habit.name }
        if let person = (about.people + about.former).first(where: { $0.key == key }) { return "👤 \(person.name)" }
        if let place = about.places.first(where: { $0.key == key }) { return "📍 \(place.name)" }
        if let saying = about.sayings.first(where: { $0.key == key }) { return "「\(saying.phrase)」" }
        return ""
    }

    @ViewBuilder private func content(_ about: API.Known) -> some View {
        if key == "sleep", let sleep = about.sleep {
            SleepDetail(sleep: sleep, store: store, openEntry: openEntry)
        } else if let habit = about.habits.first(where: { $0.key == key }) {
            HabitDetail(habit: habit, store: store, openEntry: openEntry)
        } else if let person = (about.people + about.former).first(where: { $0.key == key }) {
            PersonDetail(person: person, store: store, openEntry: openEntry, leave: leave)
        } else if let place = about.places.first(where: { $0.key == key }) {
            PlaceDetail(place: place, store: store, openEntry: openEntry)
        } else if let saying = about.sayings.first(where: { $0.key == key }) {
            SayingDetail(saying: saying, store: store, leave: leave)
        } else {
            Text("这一条已经不在了。").font(Web.body).foregroundStyle(Web.fgTertiary)
        }
    }

    /// 依据里的一条记录：这一层收起，等它收下去再打开记录详情（同时弹两层系统会拒绝）
    private func openEntry(_ day: String, _ id: Int) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            model.openEntry(id, day: day)
        }
    }

    /// 去别的页（笔记库）：这一层收起
    private func leave(_ path: String) {
        dismiss()
        model.open(path)
    }
}

/// 「说得对吗？ 对 / 不对」：再点一次选中的「对」就是取消；「不对」它就不再这么说，底部能撤销
private struct MarkChoices: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let key: String
    let basis: String
    let mark: String?
    let markedAt: String?
    let sentence: String
    let store: KnownStore

    var body: some View {
        let right = mark == "right"
        VStack(alignment: .leading, spacing: Web.space2) {
            HStack(spacing: Web.space3) {
                Text("说得对吗？").font(Web.body).foregroundStyle(Web.fgSecondary)
                WebChip(selected: right) {
                    store.mark(key, right ? nil : "right", basis: basis, sentence: sentence, model)
                } label: {
                    Text("对")
                }
                WebChip(selected: false) {
                    wrong()
                } label: {
                    Text("不对")
                }
            }
            MeNote(right && markedAt != nil ? "你 \(KnownStore.isoDay(markedAt ?? ""))确认过" : "点「不对」它就不再这么说，可以撤销")
        }
    }

    private func wrong() {
        dismiss()
        store.mark(key, "wrong", basis: basis, sentence: sentence, model)
        model.toast("不再显示「\(sentence)」", action: "撤销") {
            store.mark(key, nil, basis: basis, sentence: sentence, model)
        }
    }
}

/// 一条依据：「9月30日 7:10 · 跑步 5 公里」，右边一小段灰字；点了开记录详情
private struct EvidenceRow: View {
    let text: String
    var side: String?
    var warn = false
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: Web.space3) {
                Text(Show.spaced(text)).font(Web.body).foregroundStyle(Web.fg).frame(
                    maxWidth: .infinity, alignment: .leading)
                if let side { Text(side).font(Web.caption).foregroundStyle(warn ? Web.status("warn") : Web.fgTertiary) }
            }
            .padding(.vertical, Web.space2)
            .frame(minHeight: Web.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: 0))
        .moneyRule()
        .accessibilityElement(children: .combine)
    }
}

/// 先列几条，多的收在「看全部 N 个」里
private struct ShowSome<Item, Row: View>: View {
    let items: [Item]
    let first: Int
    let unit: String
    @ViewBuilder let row: (Item) -> Row
    @State private var all = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array((all ? items : Array(items.prefix(first))).enumerated()), id: \.offset) { _, item in row(item)
            }
            if !all && items.count > first {
                WebTextButton("看全部 \(items.count) \(unit)", font: Web.caption) { all = true }.padding(.top, Web.space2)
            }
        }
    }
}

private struct SleepDetail: View {
    let sleep: API.SleepPattern
    let store: KnownStore
    let openEntry: (String, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            Text(Show.spaced(Show.sleepSentence(sleep, full: true))).font(Web.body).foregroundStyle(Web.fg)
            MarkChoices(
                key: sleep.key, basis: sleep.basis, mark: sleep.mark, markedAt: sleep.markedAt,
                sentence: Show.sleepSentence(sleep), store: store)
            if !sleep.outliers.isEmpty {
                PeekSection(title: "和平时差得多的 \(sleep.outliers.count) 晚") {
                    VStack(spacing: 0) {
                        ForEach(sleep.outliers, id: \.entryId) { night in
                            EvidenceRow(text: Self.nightText(night), side: night.note, warn: true) {
                                openEntry(night.day, night.entryId)
                            }
                        }
                    }
                    MeNote("要是记错了，点这一晚就能改；改了，上面跟着重新算").padding(.top, Web.space2)
                }
            }
            PeekSection(title: "\(sleep.nights.count) 个晚上（\(Show.monthDay(sleep.from))–\(Show.monthDay(sleep.to))）") {
                SleepChart(sleep: sleep).padding(.bottom, Web.space2)
                ShowSome(items: sleep.nights, first: 3, unit: "晚") { night in
                    EvidenceRow(text: Self.nightText(night), side: Show.durationCn(night.minutes)) {
                        openEntry(night.day, night.entryId)
                    }
                }
            }
        }
    }

    static func nightText(_ night: API.Night) -> String {
        "\(Show.monthDay(night.day)) · \(Show.hourMinute(String(night.start.dropFirst(11).prefix(5)))) → "
            + Show.hourMinute(String(night.end.dropFirst(11).prefix(5)))
    }
}

/// 每晚一条横线，从入睡画到起床（横轴 20:00 到第二天 12:00）；和平时差得多的用提醒色
private struct SleepChart: View {
    let sleep: API.SleepPattern

    var body: some View {
        let odd = Set(sleep.outliers.map(\.entryId))
        VStack(spacing: Web.space1) {
            VStack(spacing: Web.space1 / 2) {
                ForEach(sleep.nights.reversed(), id: \.entryId) { night in
                    GeometryReader { proxy in
                        let from = Self.place(night.start, after: false)
                        let until = Self.place(night.end, after: true)
                        Capsule().fill(Web.bgSubtle)
                            .overlay(alignment: .leading) {
                                Capsule().fill(
                                    odd.contains(night.entryId)
                                        ? Web.status("warn") : Web.tag("purple").solid.opacity(0.5)
                                )
                                .frame(width: proxy.size.width * max(0.01, until - from))
                                .offset(x: proxy.size.width * from)
                            }
                    }
                    .frame(height: Web.space1)
                }
            }
            HStack {
                ForEach(["20:00", "0:00", "4:00", "8:00", "12:00"], id: \.self) { mark in
                    Text(mark)
                    if mark != "12:00" { Spacer() }
                }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("每晚几点睡、几点起，\(sleep.nights.count) 晚"))
    }

    /// 在横轴上的几分之几
    static func place(_ stamp: String, after: Bool) -> Double {
        let clock = stamp.dropFirst(11)
        var minutes = (Int(clock.prefix(2)) ?? 0) * 60 + (Int(clock.dropFirst(3).prefix(2)) ?? 0)
        if minutes < 20 * 60 && (after || minutes < 12 * 60) { minutes += 24 * 60 }
        return min(1, max(0, Double(minutes - 20 * 60) / Double(16 * 60)))
    }
}

private struct HabitDetail: View {
    let habit: API.Habit
    let store: KnownStore
    let openEntry: (String, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            Text(Show.spaced(Show.habitSentence(habit))).font(Web.body).foregroundStyle(Web.fg)
            MarkChoices(
                key: habit.key, basis: habit.basis, mark: habit.mark, markedAt: habit.markedAt,
                sentence: "\(habit.name)：\(Show.habitMeta(habit))", store: store)
            PeekSection(title: "最近 4 周 \(habit.times) 次") {
                ShowSome(items: habit.occurrences, first: 5, unit: "次") { item in
                    EvidenceRow(text: "\(Show.monthDay(item.day))\(item.at.map { " \($0)" } ?? "") · \(item.label)") {
                        openEntry(item.day, item.entryId)
                    }
                }
            }
        }
    }
}
