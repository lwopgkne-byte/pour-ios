import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 人情往来（01 需求文档 5.6、06 交互细节 10.2）：两个大数（你送出的 / 你收到的，下面写送礼几次、请客几次、别人请你几次）；
/// 一个人一行（最近一次、送多少、收多少），点进去是「和小李的来往」；最下面「没说是谁的 2 次」。只摆事实：随多少你自己定
struct RenqingHomePage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    @State private var page: API.RenqingPage?
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
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.RenqingPage) -> some View {
        if page.people.isEmpty && page.unknown == nil {
            Section {
                EmptyState("还没说到人情来往。随礼、包红包、请客、别人请你的时候顺口说一句（「小王结婚随了 800」），这里就会记下。")
                    .listRowBackground(Color.clear)
            }
        } else {
            Section {
                RenqingTotals(
                    out: page.out, into: page.into, labels: .init(out: "你送出的", into: "你收到的", intoTreat: "别人请你")
                )
                .renqingTotalsRow()
            } footer: {
                Text("只算你说过的\(page.started.map { " · \(Show.monthDay($0))开始记" } ?? "")")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            Section {
                ForEach(page.people, id: \.name) { person($0) }
                if let unknown = page.unknown {
                    let amount = unknown.amount > 0 ? " · \(Show.yuan(unknown.amount, hide: hide))" : ""
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text("没说是谁的 \(unknown.times) 次\(amount)").font(Theme.Typeface.body)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                        Text("说一句是谁的，就会归到那个人").font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    .padding(.vertical, Theme.Space.tight)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                // 照原型：右边一句小字；标题自己是一个标题（不和小字合成一句）
                HStack(alignment: .firstTextBaseline) {
                    Text("和谁来往").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Theme.Space.small)
                    Text("按最近一次 · 点一个人看每一次").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .textCase(nil)
            } footer: {
                Text("一起请好几个人的，钱不拆到每个人头上，只数次数。随多少你自己定，这里只记事实。")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }

    /// 一个人一行：名字（关系）、最近一次；右边送多少、收多少
    private func person(_ person: API.RenqingPersonLine) -> some View {
        Button {
            model.open("/money/renqing/\(person.name)")
        } label: {
            HStack(spacing: Theme.Space.medium) {
                // 照原型：红色的圆、白色的人
                Image(systemName: "person.fill").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: Theme.Size.tile, height: Theme.Size.tile)
                    .background(Theme.tag("red").solid, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(person.relation.map { "\(person.name) · \($0)" } ?? person.name).font(Theme.Typeface.body)
                        .foregroundStyle(Theme.Palette.label)
                    let last = Show.maskYuan(person.last.text, hide: hide)
                    Text("\(Show.monthDay(person.last.day)) · \(last)")
                        .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: Theme.Space.hairline) {
                    if person.out.amount > 0 { Text("送 \(Show.yuan(person.out.amount, hide: hide))") }
                    if person.into.amount > 0 {
                        Text("收 \(Show.yuan(person.into.amount, hide: hide))").foregroundStyle(
                            Theme.Palette.secondaryLabel)
                    }
                }
                .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.label).fixedSize()
                Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                    .foregroundStyle(Theme.Palette.tertiaryLabel).accessibilityHidden(true)
            }
            .padding(.vertical, Theme.Space.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        let path = "/api/money/renqing"
        if page == nil, let saved: API.RenqingPage = model.client.cached(path) { page = saved }
        do throws(APIError) {
            page = try await model.client.renqing()
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}

/// 和一个人的来往：你送的 / TA 送的两个大数 + 每一次（日子、事由、和谁一起、你当时的原话），点一次打开那条记录
struct RenqingPersonPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let name: String
    @State private var page: API.RenqingPersonPage?
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
        .refreshable { await load() }
        .task(id: "\(name)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.RenqingPersonPage) -> some View {
        Section {
            RenqingTotals(
                out: page.out, into: page.into,
                labels: .init(out: "你送的", into: "\(page.name)送的", intoTreat: "\(page.name)请你")
            )
            .renqingTotalsRow()
        } footer: {
            let notes = [
                page.relation,
                page.out.treats > 0 || page.rows.contains { !$0.together.isEmpty } ? "一起请好几个人的，钱不拆到每个人头上，只数次数" : nil,
            ]
            Text(notes.compactMap { $0 }.joined(separator: " · ")).font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        Section {
            ForEach(Array(page.rows.enumerated()), id: \.offset) { _, row in self.row(row) }
        } header: {
            MoneySectionHeader("每一次", value: "\(page.rows.count) 次")
        }
    }

    private func row(_ row: API.RenqingPersonPage.Row) -> some View {
        Button {
            model.openEntry(row.entryId, day: row.day)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                Text(Show.monthDay(row.day)).font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minWidth: Theme.Size.touch + Theme.Space.regular, alignment: .leading)
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(Show.maskYuan(row.text, hide: hide)).font(Theme.Typeface.body)
                        .foregroundStyle(Theme.Palette.label)
                    if !row.together.isEmpty {
                        Text("和\(row.together.joined(separator: "、"))一起").font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    if let quote = row.quote {
                        Text("「\(quote)」").font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? name
        if page == nil, let saved: API.RenqingPersonPage = model.client.cached("/api/money/renqing/\(path)") {
            page = saved
        }
        do throws(APIError) {
            page = try await model.client.renqing(person: name)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}

/// 两边两个大数：送出的、收到的（下面写几次；是 0 的不写）
struct RenqingTotals: View {
    struct Labels {
        let out: String
        let into: String
        let intoTreat: String
    }

    @AppStorage(MoneyHidden.key) private var hide = false
    let out: API.RenqingSide
    let into: API.RenqingSide
    let labels: Labels

    /// 照原型：两张白卡左右并排
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.medium) {
            side(labels.out, out, times(out, gift: "送礼", treat: "请客"))
            side(labels.into, into, times(into, gift: "收礼", treat: labels.intoTreat))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func side(_ label: String, _ side: API.RenqingSide, _ count: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(label).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            Text(Show.yuan(side.amount, hide: hide)).font(Theme.Typeface.metric).monospacedDigit()
                .foregroundStyle(Theme.Palette.label).minimumScaleFactor(0.7).lineLimit(1)
            Text(count).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(Theme.Space.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
        .accessibilityElement(children: .combine)
    }

    /// 「送礼 2 次 · 请客 1 次」
    private func times(_ side: API.RenqingSide, gift: String, treat: String) -> String {
        let parts = [
            side.gifts > 0 ? "\(gift) \(side.gifts) 次" : nil, side.treats > 0 ? "\(treat) \(side.treats) 次" : nil,
        ]
        let text = parts.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? "还没有" : text
    }
}

extension View {
    /// 放两张卡的那一行：列表本身不再画白底、不留边（两张卡自己是白的）
    func renqingTotalsRow() -> some View {
        listRowBackground(Color.clear).listRowInsets(EdgeInsets())
    }
}
