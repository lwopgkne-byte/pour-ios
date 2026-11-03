import PourAPI
import PourDesign
import SwiftUI

/// 重新选类别：平时只显示现在的类别，点一下展开成一排小标签（子类别跟在上级后面）
struct CategoryPicker: View {
    @Environment(AppModel.self) private var model
    let value: String
    let pick: (String) -> Void
    @State private var open: Bool

    init(value: String, startOpen: Bool = false, pick: @escaping (String) -> Void) {
        self.value = value
        self.pick = pick
        _open = State(initialValue: startOpen)
    }

    var body: some View {
        let categories = model.categories
        if open {
            PourFlowLayout(spacing: Theme.Space.tight, lineSpacing: Theme.Space.tight) {
                ForEach(Self.ordered(categories), id: \.key) { category in
                    FilterChip(category.name, selected: category.key == value) {
                        if category.key != value { pick(category.key) }
                    }
                }
            }
        } else {
            let current = categories.first { $0.key == value }
            Button {
                open = true
            } label: {
                Text(current.map { "\($0.emoji) \($0.name)" } ?? "选一个类别")
                    .foregroundStyle(current == nil ? Theme.Palette.secondaryLabel : Theme.Palette.secondaryLabel)
                    .frame(minHeight: Theme.Size.touch)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("修改类别"))
            .accessibilityValue(Text(current?.name ?? "没有选"))
        }
    }

    /// 上级类别，后面跟着它的子类别
    static func ordered(_ categories: [API.Category]) -> [API.Category] {
        categories.filter { $0.parent == nil }.flatMap { top in [top] + categories.filter { $0.parent == top.key } }
    }
}
