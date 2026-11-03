import PourAPI
import PourDesign
import SwiftUI

/// 人际星图（docs/3.0/06-交互细节.md 10.6；位置的算法照第一期）：「你」在中间，越近越常在一起，圆点越大在一起的天数越多；
/// 上面家人、右下工作、左下朋友和其他；绿的那些日子心情好一些、黄的差一些、灰的差不多或还太少。
/// 两根手指放大（最多 2.5 倍），放大了能拖着看，点两下回去；点一个人的圆点进那个人那一页
struct PeopleStarMap: View {
    let people: [API.MePerson]
    let open: (String) -> Void
    @State private var scale = 1.0
    @State private var settled = 1.0
    @State private var offset = CGSize.zero
    @State private var dragged = CGSize.zero

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
    private static let maxScale = 2.5

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
        GeometryReader { geo in
            let unit = geo.size.width / 400
            ZStack(alignment: .topLeading) {
                Canvas { context, size in draw(context, scale: size.width / 400) }
                ForEach(placed, id: \.person.name) { item in
                    Button {
                        open(item.person.name)
                    } label: {
                        Color.clear.frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: item.center.x * unit, y: item.center.y * unit)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: Theme.Size.starMap)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(zoom)
        .gesture(pan, isEnabled: scale > 1)
        .onTapGesture(count: 2) { reset() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("和谁在一起：离你越近越常在一起，圆点越大在一起的天数越多；上面是家人，右下是工作，左下是朋友和其他"))
        .accessibilityValue(
            Text(people.map { "\($0.name) \($0.former ? "以前" : "\($0.days.count) 天")" }.joined(separator: "，"))
        )
        .accessibilityIdentifier("people.map")
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = min(max(settled * value.magnification, 1), Self.maxScale) }
            .onEnded { _ in
                settled = scale
                if scale <= 1.01 { reset() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: dragged.width + value.translation.width, height: dragged.height + value.translation.height)
            }
            .onEnded { _ in dragged = offset }
    }

    private func reset() {
        withAnimation(Theme.Motion.standard) {
            scale = 1
            settled = 1
            offset = .zero
            dragged = .zero
        }
    }

    private func tone(_ mood: String) -> Color {
        switch mood {
        case "better": Theme.Palette.good
        case "worse": Theme.Palette.warn
        default: Theme.Palette.tertiaryLabel
        }
    }

    /// 按 400 宽算好的位置缩到实际大小；字不缩
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
                circle(middle, ring), with: .color(Theme.Palette.separator),
                style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
        }
        for angle in [60.0, 180, 300] {
            var line = Path()
            line.move(to: at(middle))
            line.addLine(to: at(Self.point(196, angle)))
            context.stroke(line, with: .color(Theme.Palette.separator), lineWidth: 1)
        }
        for (_, sector) in Self.sectors {
            context.draw(
                Text(sector.name).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel),
                at: at(sector.label), anchor: sector.anchor)
        }
        context.fill(circle(middle, 24), with: .color(Theme.Palette.label))
        context.draw(Text("你").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.card), at: at(middle))
        for item in placed {
            if item.person.former {
                context.stroke(
                    circle(item.center, item.radius), with: .color(Theme.Palette.tertiaryLabel), lineWidth: 1.5)
            } else {
                context.fill(circle(item.center, item.radius), with: .color(tone(item.person.mood)))
            }
            let side = item.right ? item.radius + 6 : -(item.radius + 6)
            let anchor: UnitPoint = item.right ? .leading : .trailing
            let place = at(CGPoint(x: item.center.x + side, y: item.center.y))
            context.draw(
                Text(item.person.name).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label),
                at: CGPoint(x: place.x, y: place.y - Theme.Space.small), anchor: anchor)
            context.draw(
                Text(item.person.former ? "以前" : "\(item.person.days.count) 天").font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.secondaryLabel),
                at: CGPoint(x: place.x, y: place.y + Theme.Space.small + Theme.Space.tight / 2), anchor: anchor)
        }
    }
}
