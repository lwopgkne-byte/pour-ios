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
                // 留的边小一点：一行里的小环（38 点）也放得下「26 天」，不用缩字（缩了审计算截断）
                Text(label).font(Theme.Typeface.tick).monospacedDigit().foregroundStyle(Theme.Palette.label)
                    .minimumScaleFactor(0.7).lineLimit(1).padding(Theme.Space.hairline)
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
        // 照原型：正轨绿、落后琥珀、暂停浅灰（环是图形，比字的颜色亮一档）
        case .onTrack, .done: Theme.Palette.ringGood
        case .behind: Theme.Palette.ringWarn
        case .notYet: Theme.Palette.tertiaryLabel
        case .paused: Theme.Palette.ringPaused
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
