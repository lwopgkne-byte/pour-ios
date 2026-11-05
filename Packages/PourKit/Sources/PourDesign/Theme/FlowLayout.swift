public import SwiftUI

/// 一行放不下就换到下一行的排法：一组胶囊标签这样放。每个标签按自己的宽度，字调大时不会被挤成一个字一行
/// （M1 自验收在最大字号的截图里看到「能/报/销」竖着排）
public struct PourFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    public init(spacing: CGFloat = Theme.Space.small, lineSpacing: CGFloat = Theme.Space.small) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        // 只占用实际用到的宽度（不把一行剩下的都要走），放在 HStack 里也不挤别人
        return CGSize(width: rows.map(\.width).max() ?? 0, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                let origin = CGPoint(x: x, y: y + (row.height - item.size.height) / 2)
                // 高度不卡死：字号调大时字可以往下长，不被截
                subviews[item.index].place(at: origin, proposal: ProposedViewSize(width: item.size.width, height: nil))
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            // 一个就比一整行还宽：给它一行的宽度，让它自己换行
            if size.width > width { size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if !row.items.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append((index, size))
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

/// 一组会换行的胶囊（FilterChip 这种：看得见的胶囊 32 高，点的地方 44）。排的时候按看得见的胶囊算：
/// 行和行看上去隔 spacing（原型一组 .chip 是 gap 8），点的地方还是 44——上下多出来的那截叠进行缝里，
/// 整组也往外多出那半截，和上下别的东西的距离按胶囊算（和「说一句」那排小胶囊一个办法）
public struct ChipFlow<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = Theme.Space.small, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let slack = Theme.Size.touch - Theme.Size.capsule
        PourFlowLayout(spacing: spacing, lineSpacing: spacing - slack) { content }
            .padding(.vertical, -slack / 2)
    }
}
