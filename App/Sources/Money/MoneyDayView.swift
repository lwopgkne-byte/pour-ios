import PourAPI
import PourDesign
import SwiftUI

/// 一天的钱（网页版 MoneyDayPage.tsx，docs/prd-money.md 5.4）：每一笔的时间、给谁、你说的值不值；
/// 那天和谁在一起、你说的心情；那天你还说了什么。点一笔打开那条记录的详情；左右滑到前后有钱的日子
struct MoneyDayView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let day: String
    let navigate: (String) -> Void
    @State private var page: API.MoneyDayPage?
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage(
            prev: page?.prev.map { prev in { navigate("/money/day/\(prev)") } },
            next: page?.next.map { next in { navigate("/money/day/\(next)") } }
        )
        .task(id: "\(day)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.MoneyDayPage) -> some View {
        let context =
            (page.people.isEmpty ? [] : ["那天和\(page.people.joined(separator: "、"))在一起"])
            + (page.feelings.isEmpty ? [] : ["你说\(page.feelings.map { "「\($0)」" }.joined())"])
        VStack(alignment: .leading, spacing: Web.space6) {
            MoneyHead(title: Show.dayTitle(day, today: model.today)) {
                navigate(Show.moneyPath(String(day.prefix(7)), today: model.today))
            } sub: {
                Text(
                    rich([
                        .init(Show.yuan(page.spent, hide: hide), font: Web.displayBold),
                        .init(" · \(page.count) 笔", color: Web.fgSecondary),
                    ])
                )
                .monospacedDigit()
                if !context.isEmpty {
                    Text(Show.spaced(context.joined(separator: " · "))).font(Web.body).foregroundStyle(Web.fgSecondary)
                }
            }
            if page.items.isEmpty {
                Text("这一天没说到钱。").font(Web.body).foregroundStyle(Web.fgSecondary)
            } else {
                MoneyList {
                    ForEach(Array(page.items.enumerated()), id: \.offset) { _, item in
                        MoneyRow(item: item) { model.openMoney(item) }
                    }
                }
            }
            if !page.notes.isEmpty { notes(page.notes) }
            HStack {
                if let prev = page.prev { MoneyTextLink("‹ \(Show.monthDay(prev))") { navigate("/money/day/\(prev)") } }
                Spacer()
                if let next = page.next { MoneyTextLink("\(Show.monthDay(next)) ›") { navigate("/money/day/\(next)") } }
            }
            .padding(.horizontal, -Web.space3)
        }
    }

    /// 那天你还说了：几点、原话
    private func notes(_ notes: [API.MoneyDayPage.Note]) -> some View {
        ReviewSection(title: "那天你还说了") {
            MoneyList {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                        Text(note.time).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                            .fixedSize().frame(minWidth: Web.space12, alignment: .leading)
                        Text(Show.spaced(note.text)).font(Web.body).foregroundStyle(Web.fgSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Web.space3)
                    .moneyRule()
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func load() async {
        do {
            page = try await model.client.moneyDay(day)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 每一笔（网页版 MoneyListPage.tsx，docs/prd-money.md 5.14）：按天分组，新的在上；每天写「花了 ¥…」（只算日常的）；
/// 能搜名目、人、生活领域。点一笔打开那条记录的详情
struct MoneyListView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let month: String
    let filter: MoneyFilter
    let navigate: (String) -> Void
    @State private var page: API.MoneyMonth?
    @State private var problem: String?
    @State private var text = ""
    @State private var cleared = false

    private static let kindNames = ["fixed": "固定的", "income": "收入", "reimburse": "等报销", "lend": "借出去"]

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: "\(month)-\(model.dataVersion)") { await load() }
    }

    private var active: MoneyFilter { cleared ? MoneyFilter() : filter }

    private func shown(_ page: API.MoneyMonth) -> [API.MoneyItem] {
        let words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        return page.items.filter { item in
            if let kind = active.kind, item.kind != kind { return false }
            if let domain = active.domain, item.domain.key != domain || item.kind != "daily" { return false }
            let hay = "\(item.name) \(item.who) \(Show.whoLabel(item)) \(item.domain.name) \(item.verdict?.quote ?? "")"
                .lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    @ViewBuilder private func content(_ page: API.MoneyMonth) -> some View {
        let name = Show.monthName(month)
        let items = shown(page)
        let days = items.map(\.day).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let filterName =
            active.kind.flatMap { Self.kindNames[$0] }
            ?? active.domain.flatMap { key in
                page.domains.first { $0.key == key }?.name
            }
        VStack(alignment: .leading, spacing: Web.space6) {
            MoneyHead(title: "\(name)的每一笔") {
                navigate(Show.moneyPath(month, today: model.today))
            } sub: {
                Text(summary(page)).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: Web.space2) {
                WebTextField(placeholder: "搜：外卖、儿子、动物园……", text: $text)
                if let filterName {
                    HStack(spacing: Web.space1) {
                        Text("只看「\(filterName)」").font(Web.caption).foregroundStyle(Web.fgSecondary)
                        Button {
                            cleared = true
                        } label: {
                            Image(systemName: "xmark").font(Web.caption).foregroundStyle(Web.fgSecondary)
                                .frame(width: Web.touch, height: Web.touch).contentShape(Rectangle())
                        }
                        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                        .accessibilityLabel(Text("看全部"))
                    }
                }
            }
            if days.isEmpty {
                Text(text.isEmpty ? "\(name)还没说到钱。" : "没有搜到。").font(Web.body).foregroundStyle(Web.fgSecondary)
            }
            ForEach(days, id: \.self) { day in dayGroup(day, items.filter { $0.day == day }) }
        }
    }

    private func summary(_ page: API.MoneyMonth) -> String {
        let names = [("fixed", "固定的"), ("income", "收入"), ("reimburse", "等报销"), ("lend", "借出去"), ("back", "回来的钱")]
        let others = names.compactMap { key, label in
            (page.counts[key] ?? 0) > 0 ? "\(label) \(page.counts[key] ?? 0) 笔" : nil
        }
        return "日常 \(page.count) 笔 \(Show.yuan(page.spent, hide: hide))"
            + (others.isEmpty ? "" : " · 另有\(others.joined(separator: "、"))")
    }

    private func dayGroup(_ day: String, _ here: [API.MoneyItem]) -> some View {
        let spent = (here.filter { $0.kind == "daily" }.reduce(0) { $0 + $1.amount } * 100).rounded() / 100
        let relative = Show.daySeparator(day, today: model.today)
        let title = Show.dayTitle(day, today: model.today)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                Text(relative == title ? relative : "\(relative) · \(title)").font(Web.bodySemibold).foregroundStyle(
                    Web.fg
                )
                .accessibilityAddTraits(.isHeader)
                Spacer()
                if spent > 0 {
                    Text("花了 \(Show.yuan(spent, hide: hide))").font(Web.caption).foregroundStyle(Web.fgTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.bottom, Web.space1)
            MoneyList {
                ForEach(Array(here.enumerated()), id: \.offset) { _, item in
                    MoneyRow(item: item) { model.openMoney(item) }
                }
            }
        }
    }

    private func load() async {
        do {
            page = try await model.client.moneyMonth(month)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

extension AppModel {
    /// 点一笔钱：打开那条记录的详情；是每个月固定扣的，详情里多一行「固定的 · 每个月几日 · 不再算固定的」
    func openMoney(_ item: API.MoneyItem) {
        let fixed = item.kind == "fixed" ? FixedPay(dayOfMonth: Int(item.day.suffix(2)) ?? 1, index: item.index) : nil
        openEntry(item.entryId, day: item.day, fixed: fixed)
    }
}
