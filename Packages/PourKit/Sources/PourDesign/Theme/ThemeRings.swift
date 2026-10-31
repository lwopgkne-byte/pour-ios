public import SwiftUI

/// 3.0 进度环（docs/3.0/01-需求文档.md 3.2、9.1）：正轨绿、落后黄（落后多的、不可能的也是黄，不用红和灰）、
/// 还谈不上空心、暂停浅灰、完成满环加勾；中间写百分比、「2/4」或「26 天」；刚定好时转一圈
public struct GoalRing: View {
    public enum State: Sendable {
        case onTrack, behind, notYet, paused, done
    }

    let state: State
    let progress: Double
    let label: String
    let size: CGFloat
    let spinIn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var turned = false

    public init(state: State, progress: Double, label: String, size: CGFloat = Theme.Size.ring, spinIn: Bool = false) {
        self.state = state
        self.progress = progress
        self.label = label
        self.size = size
        self.spinIn = spinIn
    }

    public var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.fill, lineWidth: Theme.Size.ringLine)
            switch state {
            case .notYet:
                // 还谈不上：只有一圈虚线，不画进度
                Circle().stroke(color, style: StrokeStyle(lineWidth: Theme.Space.hairline, dash: [3, 3]))
            case .done:
                Circle().stroke(color, lineWidth: Theme.Size.ringLine)
                Image(systemName: "checkmark").font(Theme.Typeface.footnoteSemibold).foregroundStyle(color)
            default:
                Circle().trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: Theme.Size.ringLine, lineCap: .round))
                    .rotationEffect(.degrees(-90 + (turned ? 0 : -360)))
            }
            if state != .done {
                Text(label).font(Theme.Typeface.tick).monospacedDigit().foregroundStyle(Theme.Palette.label)
                    .minimumScaleFactor(0.7).lineLimit(1).padding(Theme.Space.tight)
            }
        }
        .frame(width: size, height: size)
        .padding(Theme.Size.ringLine / 2)
        .onAppear {
            guard spinIn, !reduceMotion else {
                turned = true
                return
            }
            withAnimation(Theme.Motion.spring) { turned = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    private var color: Color {
        switch state {
        case .onTrack, .done: Theme.Palette.good
        case .behind: Theme.Palette.warn
        case .notYet: Theme.Palette.tertiaryLabel
        case .paused: Theme.Palette.separator
        }
    }

    private var spoken: String {
        switch state {
        case .onTrack: "在正轨上，\(label)"
        case .behind: "落后了，\(label)"
        case .notYet: "还谈不上"
        case .paused: "暂停了"
        case .done: "做到了"
        }
    }
}

/// 五档心情（很差 · 不太好 · 一般 · 挺好 · 很好）：自己画的五个表情，同一套线条，只有嘴和眉毛变（不用 emoji）
public struct MoodFace: View {
    /// 1 到 5
    let level: Int
    let size: CGFloat
    let selected: Bool

    public init(level: Int, size: CGFloat = Theme.Size.touch, selected: Bool = false) {
        self.level = min(5, max(1, level))
        self.size = size
        self.selected = selected
    }

    public static let names = ["很差", "不太好", "一般", "挺好", "很好"]

    public var body: some View {
        Canvas { context, canvas in
            let side = min(canvas.width, canvas.height)
            let line = max(1.5, side / 18)
            let face = CGRect(x: line, y: line, width: side - line * 2, height: side - line * 2)
            let ink = selected ? Theme.Palette.accent : Theme.Palette.secondaryLabel
            context.stroke(Path(ellipseIn: face), with: .color(ink), lineWidth: line)
            // 眼睛
            let eyeY = face.minY + face.height * 0.4
            for eyeX in [face.minX + face.width * 0.35, face.minX + face.width * 0.65] {
                let eye = CGRect(x: eyeX - line, y: eyeY - line, width: line * 2, height: line * 2)
                context.fill(Path(ellipseIn: eye), with: .color(ink))
            }
            // 嘴：很差往下弯得最多，一般是平的，很好往上弯得最多
            let bend = CGFloat(level - 3) * face.height * 0.09
            var mouth = Path()
            let mouthY = face.minY + face.height * 0.66
            mouth.move(to: CGPoint(x: face.minX + face.width * 0.3, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: face.minX + face.width * 0.7, y: mouthY),
                control: CGPoint(x: face.midX, y: mouthY + bend * 2))
            context.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: line, lineCap: .round))
            // 眉毛：只有很差的时候皱起来
            if level == 1 {
                for (start, end) in [(0.26, 0.42), (0.74, 0.58)] {
                    var brow = Path()
                    brow.move(to: CGPoint(x: face.minX + face.width * start, y: face.minY + face.height * 0.24))
                    brow.addLine(to: CGPoint(x: face.minX + face.width * end, y: face.minY + face.height * 0.3))
                    context.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: line, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .background(selected ? Theme.Palette.bubble : Color.clear, in: Circle())
        .accessibilityElement()
        .accessibilityLabel(Text(Self.names[level - 1]))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 五档心情一排：点一个就选上（记心情、心情行）；选的时候轻轻一下触感
public struct MoodPicker: View {
    @Binding var level: Int?

    public init(level: Binding<Int?>) {
        _level = level
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    level = value
                } label: {
                    VStack(spacing: Theme.Space.tight) {
                        MoodFace(level: value, selected: level == value)
                        Text(MoodFace.names[value - 1]).font(Theme.Typeface.footnote)
                            .foregroundStyle(level == value ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityElement(children: .combine)
            }
        }
        .themeSelectionFeedback(trigger: level)
    }
}

#Preview("进度环") {
    HStack(spacing: Theme.Space.regular) {
        GoalRing(state: .onTrack, progress: 0.72, label: "72%")
        GoalRing(state: .behind, progress: 0.4, label: "2/4")
        GoalRing(state: .notYet, progress: 0, label: "")
        GoalRing(state: .paused, progress: 0.5, label: "26 天")
        GoalRing(state: .done, progress: 1, label: "")
    }
    .padding()
    .background(Theme.Palette.background)
}

#Preview("五档心情") {
    @Previewable @State var level: Int? = 4
    MoodPicker(level: $level).padding().background(Theme.Palette.background)
}
