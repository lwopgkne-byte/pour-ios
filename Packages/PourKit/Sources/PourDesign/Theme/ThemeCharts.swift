public import SwiftUI

/// 进度环：状态色从 12 点开始顺时针画，圆头；底是浅灰的整圈
public struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    public init(progress: Double, color: Color, lineWidth: CGFloat = Theme.Size.ringLine) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.fill, lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

/// 一天里的几段（睡眠、学习、进食窗口）：一条细横条，每段按开始、结束在 0–1 上的位置画
public struct SpanTrack: View {
    public struct Span: Hashable, Sendable {
        public let start: Double
        public let end: Double
        public init(start: Double, end: Double) {
            self.start = start
            self.end = end
        }
    }

    let spans: [Span]
    let color: Color
    let height: CGFloat

    public init(spans: [Span], color: Color, height: CGFloat = Theme.Size.bar) {
        self.spans = spans
        self.color = color
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            context.fill(Capsule().path(in: CGRect(origin: .zero, size: size)), with: .color(Theme.Palette.fill))
            for span in spans {
                let from = min(1, max(0, span.start))
                let width = max(size.height, size.width * (min(1, max(from, span.end)) - from))
                let rect = CGRect(
                    x: min(size.width - width, size.width * from), y: 0, width: width, height: size.height)
                context.fill(Capsule().path(in: rect), with: .color(color))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// 一天里的每一次（喂奶、吃药、遛狗）：一条细线上的小圆点，按时间在 0–1 上的位置；浅的是同一类里的另一件事
public struct DotTrack: View {
    let points: [Double]
    let lighter: [Double]
    let color: Color

    public init(points: [Double], lighter: [Double] = [], color: Color) {
        self.points = points
        self.lighter = lighter
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let middle = size.height / 2
            let line = CGRect(x: 0, y: middle - 1, width: size.width, height: 2)
            context.fill(Capsule().path(in: line), with: .color(Theme.Palette.fill))
            for point in lighter { dot(context, at: point, radius: 5, fill: color.opacity(0.4), size: size) }
            for point in points { dot(context, at: point, radius: 7, fill: color, size: size) }
        }
        .frame(height: Theme.Size.dotRow)
        .accessibilityHidden(true)
    }

    private func dot(_ context: GraphicsContext, at point: Double, radius: CGFloat, fill: Color, size: CGSize) {
        let center = CGPoint(
            x: min(size.width - radius, max(radius, size.width * min(1, max(0, point)))), y: size.height / 2)
        let outer = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Circle().path(in: outer), with: .color(Theme.Palette.card))
        context.fill(Circle().path(in: outer.insetBy(dx: 2, dy: 2)), with: .color(fill))
    }
}

/// 分段条（今天的钱按类别）：每段的宽按分量，段之间 2 点空
public struct SegmentBar: View {
    public struct Segment: Hashable, Sendable {
        public let value: Double
        public let color: Color
        public init(value: Double, color: Color) {
            self.value = value
            self.color = color
        }
    }

    let segments: [Segment]

    public init(_ segments: [Segment]) {
        self.segments = segments
    }

    public var body: some View {
        Canvas { context, size in
            let total = segments.reduce(0) { $0 + max(0, $1.value) }
            guard total > 0 else { return }
            let gap = Theme.Space.hairline
            let usable = size.width - gap * CGFloat(max(0, segments.count - 1))
            var left: CGFloat = 0
            context.clip(to: Capsule().path(in: CGRect(origin: .zero, size: size)))
            for segment in segments {
                let width = usable * max(0, segment.value) / total
                context.fill(
                    Path(CGRect(x: left, y: 0, width: width, height: size.height)), with: .color(segment.color))
                left += width + gap
            }
        }
        .frame(height: Theme.Size.bar)
        .accessibilityHidden(true)
    }
}

/// 一天里的小曲线（心情）：每个点按 0–1 的横轴、1–5 的竖轴；最后一个点实心大一点
public struct LevelCurve: View {
    let points: [(x: Double, level: Double)]
    let color: Color

    public init(points: [(x: Double, level: Double)], color: Color) {
        self.points = points
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let place = { (point: (x: Double, level: Double)) in
                CGPoint(
                    x: 6 + (size.width - 12) * min(1, max(0, point.x)),
                    y: 6 + (size.height - 12) * (1 - (min(5, max(1, point.level)) - 1) / 4))
            }
            var line = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { line.move(to: place(point)) } else { line.addLine(to: place(point)) }
            }
            context.stroke(
                line, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            for (index, point) in points.enumerated() {
                let center = place(point)
                let radius: CGFloat = index == points.count - 1 ? 4.5 : 3.5
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Circle().path(in: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(Theme.Palette.card))
                context.fill(Circle().path(in: rect), with: .color(color))
            }
        }
        .frame(height: Theme.Size.curve)
        .accessibilityHidden(true)
    }
}

/// 今天的样子那张卡的底：这一天心情的颜色从左上、右上、下面三处淡淡地晕开；没记心情的那天是一层平的暖灰（不猜心情）
public struct MoodWash: View {
    let tone: Theme.MoodTone

    public init(_ tone: Theme.MoodTone) {
        self.tone = tone
    }

    public var body: some View {
        let colors = Theme.moodWash(tone)
        Group {
            if tone == .none {
                Rectangle().fill(colors[0])
            } else {
                ZStack {
                    RadialGradient(colors: [colors[0], .clear], center: .topLeading, startRadius: 0, endRadius: 260)
                    RadialGradient(colors: [colors[1], .clear], center: .topTrailing, startRadius: 0, endRadius: 230)
                    RadialGradient(colors: [colors[2], .clear], center: .bottom, startRadius: 0, endRadius: 280)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
