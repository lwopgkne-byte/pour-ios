public import SwiftUI

/// 一行放不下就换到下一行的排法：一组胶囊标签这样放。每个标签按自己的宽度，字调大时不会被挤成一个字一行
/// （M1 自验收在最大字号的截图里看到「能/报/销」竖着排）
public struct PourFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    public init(spacing: CGFloat = PourSpace.related, lineSpacing: CGFloat = PourSpace.related) {
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

/// 「名字 … 数」一行：平常名字在左、数在右；大字号时数换到名字下面（规范 11 第 2 节）——不把名字挤成一个字一行
public struct PourTitleValueRow<Title: View, Value: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: Title
    let value: Value

    public init(@ViewBuilder title: () -> Title, @ViewBuilder value: () -> Value) {
        self.title = title()
        self.value = value()
    }

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                title
                value
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: PourSpace.related) {
                title
                Spacer(minLength: PourSpace.related)
                value
            }
        }
    }
}
