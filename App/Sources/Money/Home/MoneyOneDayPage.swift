import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一天的钱（01 需求文档 5.6）：那天花了多少、几笔；那天和谁在一起、你说的心情；每一笔（点开一笔的详情）；那天你还说了什么。
/// 右上角 ‹ › 到前后有钱的日子，在上面那块左右滑也行（换掉这一页，不再往里推）
struct MoneyOneDayPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let day: String
    @State private var page: API.MoneyDayPage?
    @State private var problem: String?

    var body: some View {
        List {
            if let page {
                content(page)
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Theme.Space.medium)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task(id: "\(day)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.MoneyDayPage) -> some View {
        Section {
            hero(page)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: Theme.Size.touch).onEnded { drag in
                        guard abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
                        if drag.translation.width < 0, let next = page.next { go(next) }
                        if drag.translation.width > 0, let prev = page.prev { go(prev) }
                    })
        }
        Section {
            if page.items.isEmpty {
                Text("这一天没说到钱（没说 ≠ 没花）").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            ForEach(page.items, id: \.self) { item in
                Button {
                    model.openMoney(item)
                } label: {
                    MoneyItemRow(item: item).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(
                    EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular)
                )
                .accessibilityIdentifier("money.item")
            }
        } header: {
            MoneySectionHeader("每一笔", value: "\(page.items.count) 笔")
        }
        if !page.notes.isEmpty {
            Section {
                ForEach(Array(page.notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                        Text(note.time).font(Theme.Typeface.footnote).monospacedDigit()
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                            .frame(minWidth: Theme.Size.touch, alignment: .leading)
                        Text(Show.spaced(note.text)).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Theme.Space.tight)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                MoneySectionHeader("那天你还说了")
            }
        }
    }

    /// 那天花了多少（大字）· 几笔；那天和谁在一起 · 你说的心情
    private func hero(_ page: API.MoneyDayPage) -> some View {
        let context =
            (page.people.isEmpty ? [] : ["那天和\(page.people.joined(separator: "、"))在一起"])
            + (page.feelings.isEmpty ? [] : ["你说\(page.feelings.map { "「\($0)」" }.joined())"])
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(Show.relative(day, today: model.today).map { "\($0) · \(Show.weekday(day))" } ?? Show.weekday(day))
                .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                Text(Show.yuan(page.spent, hide: hide)).font(Theme.Typeface.bigNumber).monospacedDigit()
                    .foregroundStyle(Theme.Palette.label)
                    .accessibilityIdentifier("moneyDay.spent")
                Text("日常 \(page.count) 笔").font(Theme.Typeface.subheadline).foregroundStyle(
                    Theme.Palette.secondaryLabel)
            }
            if !context.isEmpty {
                Text(Show.spaced(context.joined(separator: " · "))).font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.label)
            }
        }
        .padding(.vertical, Theme.Space.small)
        .accessibilityElement(children: .combine)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                if let prev = page?.prev { go(prev) }
            } label: {
                Image(systemName: "chevron.left").font(Theme.Typeface.toolbarIcon)
            }
            .disabled(page?.prev == nil)
            .accessibilityLabel(Text(page?.prev.map { "前一天有钱的：\(Show.monthDay($0))" } ?? "前面没有了"))
            .accessibilityIdentifier("moneyDay.prev")
            Button {
                if let next = page?.next { go(next) }
            } label: {
                Image(systemName: "chevron.right").font(Theme.Typeface.toolbarIcon)
            }
            .disabled(page?.next == nil)
            .accessibilityLabel(Text(page?.next.map { "后一天有钱的：\(Show.monthDay($0))" } ?? "后面没有了"))
            .accessibilityIdentifier("moneyDay.next")
        }
    }

    /// 换到前后有钱的一天（同一种页面：换掉这一页）
    private func go(_ other: String) {
        model.open("/money/day/\(other)")
    }

    private func load() async {
        do throws(APIError) {
            page = try await model.client.moneyDay(day)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}
