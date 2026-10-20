import PourAPI
import PourDesign
import SwiftUI

/// 人情往来（docs/prd-money.md 第 17 节）：随礼、红包、送礼、请客，你送出的、你收到的。
/// 和谁来往按最近一次排；点一个人看和他的每一次，带着你当时的原话。只摆事实：随多少你自己定
struct RenqingView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let navigate: (String) -> Void
    @State private var page: API.RenqingPage?
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
        .moneyPage()
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.RenqingPage) -> some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            MoneyHead(title: "人情往来") {
                navigate("/money")
            } sub: {
                Text("只算你说过的\(page.started.map { " · \(Show.monthDay($0))开始记" } ?? "")").font(Web.caption)
                    .foregroundStyle(Web.fgTertiary)
            }
            if page.people.isEmpty && page.unknown == nil {
                Text("还没说到人情来往。随礼、包红包、请客、别人请你的时候顺口说一句（「小王结婚随了 800」），这里就会记下。")
                    .font(Web.body).foregroundStyle(Web.fg)
            } else {
                RenqingSides(
                    out: page.out, into: page.into,
                    labels: .init(out: "你送出的", into: "你收到的", intoTreat: "别人请你"))
                ReviewSection(title: "和谁来往") {
                    MoneyList {
                        ForEach(page.people, id: \.name) { person($0) }
                        if let unknown = page.unknown {
                            let amount = unknown.amount > 0 ? " · \(Show.yuan(unknown.amount, hide: hide))" : ""
                            Text("没说是谁的 \(unknown.times) 次\(amount)")
                                .font(Web.caption).foregroundStyle(Web.fgSecondary)
                                .frame(maxWidth: .infinity, minHeight: Web.space12, alignment: .leading)
                                .moneyRule()
                        }
                    }
                }
            }
            ReviewFoot { Text("只算你说过的 · 随多少你自己定，这里只记事实") }
        }
    }

    private func person(_ person: API.RenqingPersonLine) -> some View {
        let sums = [
            person.out.amount > 0 ? "送 \(Show.yuan(person.out.amount, hide: hide))" : "",
            person.into.amount > 0 ? "收 \(Show.yuan(person.into.amount, hide: hide))" : "",
        ]
        .filter { !$0.isEmpty }.joined(separator: " · ")
        return MoneyLinkRow {
            navigate("/money/renqing/\(person.name)")
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(person.name).font(Web.body).foregroundStyle(Web.fg)
                        // 关系在名字下面一行
                        if let relation = person.relation {
                            Text(relation).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !sums.isEmpty {
                        Text(sums).font(Web.body).foregroundStyle(Web.fgSecondary).monospacedDigit().fixedSize()
                    }
                }
                Text(Show.spaced(Show.maskYuan("\(Show.monthDay(person.last.day)) · \(person.last.text)", hide: hide)))
                    .font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func load() async {
        do {
            page = try await model.client.renqing()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 和一个人的来往：你送的、他送的，每一次（新的在前），点开是那条记录
struct RenqingPersonView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(MoneyHidden.key) private var hide = false
    let name: String
    let navigate: (String) -> Void
    @State private var page: API.RenqingPersonPage?
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
        .moneyPage()
        .task(id: "\(name)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.RenqingPersonPage) -> some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            MoneyHead(back: "‹ 人情往来", title: "和\(page.name)的来往") {
                navigate("/money/renqing")
            } sub: {
                if let relation = page.relation { Text(relation).font(Web.caption).foregroundStyle(Web.fgTertiary) }
            }
            VStack(alignment: .leading, spacing: Web.space6) {
                RenqingSides(
                    out: page.out, into: page.into,
                    labels: .init(out: "你送的", into: "\(page.name)送的", intoTreat: "\(page.name)请你"))
                if page.out.treats > 0 || page.rows.contains(where: { !$0.together.isEmpty }) {
                    Text("一起请好几个人的，钱不拆到每个人头上，只数次数").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
            ReviewSection(title: "每一次（\(page.rows.count)）") {
                MoneyList { ForEach(Array(page.rows.enumerated()), id: \.offset) { _, row in self.row(row) } }
            }
        }
    }

    private func row(_ row: API.RenqingPersonPage.Row) -> some View {
        Button {
            model.openEntry(row.entryId, day: row.day)
        } label: {
            // 字很大时日子放在上面一行，句子不被挤窄
            let layout =
                typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Web.space1))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Web.space2))
            layout {
                Text(Show.monthDay(row.day)).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                    .fixedSize().frame(minWidth: Web.space16, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Show.spaced(Show.maskYuan(row.text, hide: hide))).font(Web.body).foregroundStyle(Web.fg)
                        .fixedSize(horizontal: false, vertical: true)
                    if !row.together.isEmpty {
                        Text("和\(row.together.joined(separator: "、"))一起").font(Web.caption).foregroundStyle(
                            Web.fgTertiary)
                    }
                    if let quote = row.quote {
                        Text("「\(quote)」").font(Web.quoteCaption).foregroundStyle(Web.fgTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Web.space3)
            .frame(minHeight: Web.space12)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: 0))
        .moneyRule()
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            page = try await model.client.renqing(person: name)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 两边：送出的、收到的（大字是钱，下面是几次）
private struct RenqingSides: View {
    struct Labels {
        let out: String
        let into: String
        let intoTreat: String
    }

    @AppStorage(MoneyHidden.key) private var hide = false
    let out: API.RenqingSide
    let into: API.RenqingSide
    let labels: Labels

    var body: some View {
        HStack(alignment: .top, spacing: Web.space4) {
            side(labels.out, out, times(out, gift: "送礼", treat: "请客"))
            side(labels.into, into, times(into, gift: "收礼", treat: labels.intoTreat))
        }
    }

    private func side(_ label: String, _ side: API.RenqingSide, _ count: String) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text(label).font(Web.caption).foregroundStyle(Web.fgTertiary)
            Text(Show.yuan(side.amount, hide: hide)).font(Web.title).foregroundStyle(Web.fg).monospacedDigit()
            Text(count).font(Web.caption).foregroundStyle(Web.fgSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// 「送礼 2 次 · 请客 1 次」（是 0 的不写）
    private func times(_ side: API.RenqingSide, gift: String, treat: String) -> String {
        let parts = [
            side.gifts > 0 ? "\(gift) \(side.gifts) 次" : "", side.treats > 0 ? "\(treat) \(side.treats) 次" : "",
        ]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ").ifEmpty("还没有")
    }
}

extension String {
    /// 空的就换成别的
    fileprivate func ifEmpty(_ other: String) -> String { isEmpty ? other : self }
}
