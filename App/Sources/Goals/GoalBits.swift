import PourAPI
import PourDesign
import SwiftUI

/// 目标的状态色小圆点；还谈不上状态的是空心圈
struct ToneDot: View {
    let tone: String

    var body: some View {
        Group {
            if tone == "idle" {
                Circle().strokeBorder(Theme.Palette.secondaryLabel, lineWidth: 1)
            } else {
                Circle().fill(Theme.Palette.status(tone))
            }
        }
        .frame(width: Theme.Space.small, height: Theme.Space.small)
        .accessibilityHidden(true)
    }
}

/// 细进度条：4 点高的浅灰底，状态色填到进度那么长
struct GoalBar: View {
    let pct: Double
    let tone: String

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Theme.Palette.fill).overlay(alignment: .leading) {
                Capsule().fill(Theme.Palette.status(tone)).frame(width: proxy.size.width * min(1, max(0, pct)))
            }
        }
        .frame(height: Theme.Space.tight)
        .accessibilityHidden(true)
    }
}
