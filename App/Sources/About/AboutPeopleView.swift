import PourAPI
import PourDesign
import SwiftUI

/// 人那一页（网页版 AboutPeoplePage.tsx，docs/prd-about-me-2.md 5.4、15.2）：人际星图（你在中间，越常在一起离得越近；
/// 分家人、工作、朋友和其他三块；颜色是在一起那天的心情），下面一列是每个人的细节
struct AboutPeopleView: View {
    @Environment(AppModel.self) private var model
    let navigate: (String) -> Void
    @State private var page: API.MePeoplePage?
    @State private var problem: String?
    @State private var known = KnownStore()

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
        .task(id: model.dataVersion) { await known.load(model.client) }
        .sheet(item: $known.opened) { KnownPeek(store: known, key: $0.id) }
    }

    @ViewBuilder private func content(_ page: API.MePeoplePage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeHead(title: "人") {
                navigate("/about")
            } sub: {
                Text(Show.spaced(page.sentence)).font(Web.body).foregroundStyle(Web.fg)
            }
            if !page.people.isEmpty {
                MePanel {
                    StarMap(people: page.people).frame(maxWidth: Web.space16 * 5.6).frame(maxWidth: .infinity)
                    PourFlowLayout(spacing: Web.space4, lineSpacing: Web.space2) {
                        Text("越近越常在一起 · 越大天数越多")
                        legend("better", "那些日子心情好一些")
                        legend("worse", "差一些")
                        legend("same", "差不多或还太少")
                    }
                    .font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .padding(.top, Web.space3)
                    .accessibilityElement(children: .combine)
                }
                MoneyList { ForEach(page.people, id: \.name) { person($0) } }.padding(.top, Web.space4)
            }
            ReviewSection(title: "Pour 认识的") { KnownPeople(store: known, names: page.people.map(\.name)) }
            if !page.findings.isEmpty { ReviewSection(title: "发现") { MeFindings(findings: page.findings) } }
            if !page.changes.isEmpty {
                ReviewSection(title: "变化") { MeChanges(changes: page.changes, navigate: navigate) }
            }
            MeFoot()
        }
    }

    private func legend(_ tone: String, _ text: String) -> some View {
        HStack(spacing: Web.space1) {
            Circle().fill(MeStyle.tone(tone)).frame(width: Web.space3, height: Web.space3)
            Text(text)
        }
    }

    /// 一个人一行：名字（和你说过的关系）、在一起几天、多是做什么，右边是那些日子的心情；点开看和他有关的原话
    private func person(_ person: API.MePerson) -> some View {
        let title = person.former ? "以前常提到：\(person.name)" : "\(person.name)\(person.relation.map { " · \($0)" } ?? "")"
        let sub =
            person.former
            ? "最近一次 \(Show.monthDay(person.lastDay))"
            : (["\(person.days.count) 天", person.doing].filter { !$0.isEmpty }).joined(separator: " · ")
        let pill = person.mood == "better" ? "green" : person.mood == "worse" ? "yellow" : "gray"
        // Pour 认识这个人（提到 3 次以上）：点开是依据、关系；还不认识的，去笔记库看和他有关的原话
        return MoneyLinkRow(minHeight: Web.space12, chevron: !known.has("person:\(person.name)")) {
            if known.has("person:\(person.name)") {
                known.open("person:\(person.name)")
            } else {
                model.open(
                    "/library?tag=\(person.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")")
            }
        } label: {
            HStack(spacing: Web.space3) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Show.spaced(title)).font(Web.bodySemibold).foregroundStyle(Web.fg)
                    MeNote(sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !person.former {
                    Text(person.moodText).font(Web.caption).foregroundStyle(Web.tag(pill).fg).fixedSize()
                        .padding(.vertical, Web.space1).padding(.horizontal, Web.space3)
                        .background(Capsule().fill(Web.tag(pill).bg))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func load() async {
        do {
            page = try await model.client.mePeople()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 人际星图：你在中间；越常在一起离得越近，圆点越大天数越多；上面是家人，右下是工作，左下是朋友和其他。
/// 按 400×400 的画来算位置（和网页版一样），画的时候按实际大小缩放
private struct StarMap: View {
    let people: [API.MePerson]

    private struct Sector {
        let name: String
        let from: Double
        let to: Double
        let label: CGPoint
        let anchor: UnitPoint
    }

    private static let sectors: [(group: String, sector: Sector)] = [
        ("family", Sector(name: "家人", from: -60, to: 60, label: CGPoint(x: 200, y: 10), anchor: .center)),
        ("work", Sector(name: "工作", from: 60, to: 180, label: CGPoint(x: 394, y: 386), anchor: .trailing)),
        ("other", Sector(name: "朋友和其他", from: 180, to: 300, label: CGPoint(x: 6, y: 386), anchor: .leading)),
    ]
    /// 图里一个字大约多宽（名字 16 号字，按 400 宽的画算）
    private static let char = 17.9

    private struct Placed {
        let person: API.MePerson
        let center: CGPoint
        let radius: Double
        let right: Bool
    }

    private static func point(_ distance: Double, _ degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: 200 + distance * sin(radians), y: 200 - distance * cos(radians))
    }

    private var placed: [Placed] {
        let most = Double(max(1, people.filter { !$0.former }.map(\.days.count).max() ?? 1))
        return Self.sectors.flatMap { group, sector in
            let mine = people.filter { $0.group == group }
            return mine.enumerated().map { index, person in
                let angle = sector.from + Double(index + 1) * (sector.to - sector.from) / Double(mine.count + 1)
                let distance = person.former ? 176 : 62 + (1 - Double(person.days.count) / most) * 108
                let center = Self.point(distance, angle)
                let radius = min(24, 6 + sqrt(Double(person.days.count)) * 2.6)
                // 名字写在不会出画面的那一边
                let width = max(Double(person.name.count) * Self.char, 3 * Self.char)
                var right = center.x >= 200
                if right && center.x + radius + 6 + width > 396 {
                    right = false
                } else if !right && center.x - radius - 6 - width < 4 {
                    right = true
                }
                return Placed(person: person, center: center, radius: radius, right: right)
            }
        }
    }

    var body: some View {
        Canvas { context, size in draw(context, scale: size.width / 400) }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("和谁在一起：离你越近越常在一起，圆点越大在一起的天数越多；上面是家人，右下是工作，左下是朋友和其他"))
            .accessibilityValue(
                Text(people.map { "\($0.name) \($0.former ? "以前" : "\($0.days.count) 天")" }.joined(separator: "，")))
    }

    /// 按 400 宽算好的位置缩到实际大小；字不缩（屏幕上就是 16 号和 13 号）
    private func draw(_ context: GraphicsContext, scale: Double) {
        let at = { (point: CGPoint) in CGPoint(x: point.x * scale, y: point.y * scale) }
        let circle = { (center: CGPoint, radius: Double) in
            Path(
                ellipseIn: CGRect(
                    x: (center.x - radius) * scale, y: (center.y - radius) * scale, width: radius * 2 * scale,
                    height: radius * 2 * scale))
        }
        let middle = CGPoint(x: 200, y: 200)
        for ring in [80.0, 135, 188] {
            context.stroke(
                circle(middle, ring), with: .color(Web.line), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
        }
        for angle in [60.0, 180, 300] {
            var line = Path()
            line.move(to: at(middle))
            line.addLine(to: at(Self.point(196, angle)))
            context.stroke(line, with: .color(Web.lineStrong), lineWidth: 1)
        }
        for (_, sector) in Self.sectors {
            context.draw(
                Text(sector.name).font(Web.caption).foregroundStyle(Web.fgTertiary), at: at(sector.label),
                anchor: sector.anchor)
        }
        context.fill(circle(middle, 24), with: .color(Web.fg))
        context.draw(Text("你").font(Web.bodySemibold).foregroundStyle(Web.bg), at: at(middle))
        for item in placed {
            context.fill(circle(item.center, item.radius), with: .color(MeStyle.tone(item.person.mood)))
            let side = item.right ? item.radius + 6 : -(item.radius + 6)
            let anchor: UnitPoint = item.right ? .leading : .trailing
            let place = at(CGPoint(x: item.center.x + side, y: item.center.y))
            context.draw(
                Text(item.person.name).font(Web.bodySemibold).foregroundStyle(Web.fg),
                at: CGPoint(x: place.x, y: place.y - Web.space2), anchor: anchor)
            context.draw(
                Text(item.person.former ? "以前" : "\(item.person.days.count) 天").font(Web.caption)
                    .foregroundStyle(Web.fgTertiary),
                at: CGPoint(x: place.x, y: place.y + Web.space2 + Web.space1 / 2), anchor: anchor)
        }
    }
}
