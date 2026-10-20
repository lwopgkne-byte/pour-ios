import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一样东西的那一页（docs/prd-money.md 5.8）：每次多少钱（价钱 ÷ 之后说到用它的次数）、
/// 你怎么说它（原话）、说到用它的那几次、买的那天。出去玩这类不除，只写之后又说起几次
struct MoneyThingView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let id: Int
    let navigate: (String) -> Void
    @State private var page: API.MoneyThingPage?
    @State private var problem: String?
    @State private var all = false

    /// 说到用它的那几次：先列最近的几次，其余点「全部」
    private static let firstUses = 4

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
        .task(id: "\(id)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ thing: API.MoneyThingPage) -> some View {
        let count = thing.uses.count
        let forWhom =
            !thing.who.isEmpty && thing.who != "自己" ? (thing.who == "一家人" ? " · 一家人用" : " · 给\(thing.who)") : ""
        let uses = Array(thing.uses.reversed())
        VStack(alignment: .leading, spacing: Web.space6) {
            MoneyHead(title: thing.name) {
                navigate("/money")
            } sub: {
                Text("\(Show.yuan(thing.amount, hide: hide)) · \(Show.monthDay(thing.day))买的\(forWhom)").font(
                    Web.caption
                )
                .foregroundStyle(Web.fgTertiary).monospacedDigit()
            }
            hero(thing, count: count)
            if let verdict = thing.verdict {
                ReviewSection(title: "你怎么说它") {
                    Text("「\(verdict.quote)」").font(Web.quoteSection).foregroundStyle(Web.fg)
                    Text(saidWhen(verdict, bought: thing.day)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
            if count > 0 {
                ReviewSection(title: thing.durable ? "说到用它的 \(count) 次" : "之后说起的 \(count) 次") {
                    MoneyList {
                        ForEach(all ? uses : Array(uses.prefix(Self.firstUses)), id: \.entryId) { use in
                            useRow(day: use.day, text: use.text ?? use.label)
                        }
                        if !all && count > Self.firstUses {
                            Button("全部 \(count) 次") { withAnimation(Web.fast) { all = true } }
                                .buttonStyle(.plain).font(Web.caption).foregroundStyle(Web.fgSecondary)
                                .frame(maxWidth: .infinity, minHeight: Web.space12, alignment: .leading)
                                .contentShape(Rectangle())
                                .moneyRule()
                        }
                    }
                }
            }
            if let bought = thing.bought {
                ReviewSection(title: "买的那天") { useRow(day: bought.day, text: bought.text) }
            }
        }
    }

    @ViewBuilder private func hero(_ thing: API.MoneyThingPage, count: Int) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            if thing.durable, let perUse = thing.perUse, count > 1 {
                big("每次 \(Show.yuan(perUse, hide: hide))")
                Text("用了 \(count) 次。每用一次，它就更划算一点。").font(Web.body).foregroundStyle(Web.fg)
                StepChart(thing: thing, today: model.today).padding(.vertical, Web.space2)
                Text("每个点是你说到用它的一天 · 每次 = \(Show.yuan(thing.amount, hide: hide)) ÷ 用了几次 · 没说到的不算，实际可能更划算")
                    .font(Web.caption).foregroundStyle(Web.fgTertiary)
            } else if thing.durable {
                big(count > 0 ? "用了 \(count) 次" : "还没说到用它")
                Text("之后说到用它（「用空气炸锅烤了鸡翅」），这里就会算每次多少钱。").font(Web.body)
                    .foregroundStyle(Web.fgSecondary)
            } else {
                big(count > 0 ? "之后又说起 \(count) 次" : "之后还没再说起")
                Text("出去玩这类的钱不按次数除，只记你之后又说起几次。").font(Web.body).foregroundStyle(Web.fgSecondary)
            }
        }
    }

    private func big(_ text: String) -> some View {
        Text(text).font(Web.displayBold).foregroundStyle(Web.fg).monospacedDigit()
    }

    private func saidWhen(_ verdict: API.Verdict, bought: String) -> String {
        let said = verdict.said ?? bought
        if said != bought { return "\(Show.monthDay(said)) · 买了 \(PourDate.diffDays(said, bought)) 天以后说的" }
        return "\(Show.monthDay(said)) · 买的那天说的"
    }

    private func useRow(day: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
            Text(Show.monthDay(day)).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                .fixedSize().frame(minWidth: Web.space16, alignment: .leading)
            Text(Show.spaced(text)).font(Web.body).foregroundStyle(Web.fg).frame(
                maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Web.space3)
        .frame(minHeight: Web.space12)
        .moneyRule()
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            page = try await model.client.moneyThing(id)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 每次多少钱的台阶线：横着是从买的那天到今天，竖着是每次多少钱；每说到用一次往下走一阶。字放在图外面
private struct StepChart: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let thing: API.MoneyThingPage
    let today: String

    var body: some View {
        let now = Show.yuan(thing.perUse ?? thing.amount, hide: hide)
        VStack(spacing: Web.space1) {
            HStack {
                Text(
                    rich([
                        .bold(Show.yuan(thing.amount, hide: hide)),
                        .init(" 买的时候", font: Web.caption, color: Web.fgTertiary),
                    ]))
                Spacer()
                Text(rich([.init("现在每次 ", font: Web.caption, color: Web.fgTertiary), .bold(now)]))
            }
            .monospacedDigit()
            Canvas { context, size in draw(context, size) }
                .frame(height: Web.space16 * 2 - Web.space2)
            HStack {
                Text(Show.monthDay(thing.day))
                Spacer()
                Text("今天")
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("每次多少钱：买的时候 \(Show.yuan(thing.amount, hide: hide))，用到第 \(thing.uses.count) 次是每次 \(now)"))
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        let edge = Web.space2
        let span = Double(max(1, PourDate.diffDays(today, thing.day)))
        let xAt = { (day: String) in
            edge + CGFloat(min(span, max(0, Double(PourDate.diffDays(day, thing.day)))) / span)
                * (size.width - edge * 2)
        }
        let yAt = { (value: Double) in size.height - edge - CGFloat(value / thing.amount) * (size.height - Web.space6) }
        var axis = Path()
        axis.move(to: CGPoint(x: edge, y: size.height - edge))
        axis.addLine(to: CGPoint(x: size.width - edge, y: size.height - edge))
        context.stroke(axis, with: .color(Web.line), lineWidth: 1)
        var line = Path()
        var point = CGPoint(x: xAt(thing.day), y: yAt(thing.amount))
        line.move(to: point)
        var dots: [CGPoint] = []
        for (index, use) in thing.uses.enumerated() {
            point = CGPoint(x: xAt(use.day), y: point.y)
            line.addLine(to: point)
            point = CGPoint(x: point.x, y: yAt(thing.amount / Double(index + 1)))
            line.addLine(to: point)
            dots.append(point)
        }
        line.addLine(to: CGPoint(x: xAt(today), y: point.y))
        let yellow = Web.tag("yellow").solid
        context.stroke(line, with: .color(yellow), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        for dot in dots {
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)), with: .color(yellow))
        }
    }
}
