import PourDesign
import SwiftUI

/// 一行几块，宽窄按分量分，但再小也放得下自己的字
struct GrowRow: Layout {
    let weights: [Double]
    var spacing = Web.space1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = Self.widths(
            mins: subviews.map { $0.sizeThatFits(.unspecified).width }, weights: weights,
            space: bounds.width - spacing * CGFloat(max(0, subviews.count - 1)))
        var left = bounds.minX
        for (index, view) in subviews.enumerated() {
            view.place(
                at: CGPoint(x: left, y: bounds.minY),
                proposal: ProposedViewSize(width: widths[index], height: bounds.height))
            left += widths[index] + spacing
        }
    }

    /// 先按分量分；分到的比自己的字还窄的，就给它字那么宽，剩下的再按分量分给别的
    static func widths(mins: [CGFloat], weights: [Double], space: CGFloat) -> [CGFloat] {
        var fixed: [Int: CGFloat] = [:]
        while true {
            let free = space - fixed.values.reduce(0, +)
            let total = weights.indices.filter { fixed[$0] == nil }.reduce(0) { $0 + max(weights[$1], 0.0001) }
            let out = weights.indices.map { fixed[$0] ?? free * CGFloat(max(weights[$0], 0.0001) / total) }
            guard let short = out.indices.first(where: { fixed[$0] == nil && out[$0] < mins[$0] }) else { return out }
            fixed[short] = mins[short]
        }
    }
}
