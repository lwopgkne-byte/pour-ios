import PourAPI
import PourDesign
import SwiftUI

/// 一天的钱（docs/prd-money.md 5.4）：每一笔的时间、给谁、你说的值不值；
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

extension AppModel {
    /// 点一笔钱：打开一笔的详情（3.0：只列有的、补充缺的；固定的多一行「每个月几日 · 不再算固定的」）
    func openMoney(_ item: API.MoneyItem) {
        moneyDetail = MoneyDetailRef(item: item)
    }
}
