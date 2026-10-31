import PourAPI
import PourDesign
import SwiftUI

/// 详情里的和谁、东西、地方（01 需求文档 4.3；原来记录详情里就能改，能力只增不减）：每样一行，
/// 点「改」原地改（顿号隔开），点「好」或回车就存；先改界面再发，没网排队
struct TodoRelatedRows: View {
    @Environment(AppModel.self) private var model
    let row: API.TodoRow
    @State private var editing: Field?
    @State private var draft = ""
    @FocusState private var focused: Bool

    enum Field: String, CaseIterable, Identifiable {
        case people, things, places

        var id: String { rawValue }

        var title: String {
            switch self {
            case .people: "和谁"
            case .things: "东西"
            case .places: "地方"
            }
        }

        var symbol: String {
            switch self {
            case .people: Theme.Symbol.people
            case .things: "shippingbox.fill"
            case .places: "mappin.and.ellipse"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Field.allCases) { field in
                if field != .people { Divider().padding(.leading, Theme.Space.regular) }
                line(field)
            }
        }
        .themeCard(padding: 0)
    }

    private func words(_ field: Field) -> [String] {
        switch field {
        case .people: row.people
        case .things: row.things
        case .places: row.places
        }
    }

    private func line(_ field: Field) -> some View {
        HStack(spacing: Theme.Space.medium) {
            Label(field.title, systemImage: field.symbol).font(Theme.Typeface.subheadline)
                .foregroundStyle(Theme.Palette.label).fixedSize()
            if editing == field {
                TextField("用顿号隔开，比如：小王、老婆", text: $draft)
                    .font(Theme.Typeface.body)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { save(field) }
                    .accessibilityIdentifier("todoDetail.edit.\(field.rawValue)")
            } else {
                Text(words(field).isEmpty ? "没有" : words(field).joined(separator: "、"))
                    .font(Theme.Typeface.body)
                    .foregroundStyle(words(field).isEmpty ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ThemeTextButton(editing == field ? "好" : "改") {
                if editing == field { save(field) } else { start(field) }
            }
            .accessibilityLabel(Text(editing == field ? "改好了" : "改\(field.title)"))
        }
        .padding(.horizontal, Theme.Space.regular)
        .frame(minHeight: Theme.Size.touch + Theme.Space.small)
    }

    private func start(_ field: Field) {
        draft = words(field).joined(separator: "、")
        editing = field
        focused = true
    }

    private func save(_ field: Field) {
        var list: [String] = []
        for word in draft.split(whereSeparator: { "、，, ".contains($0) || $0.isNewline }) {
            let item = word.trimmingCharacters(in: .whitespaces)
            if !item.isEmpty, !list.contains(item) { list.append(item) }
        }
        editing = nil
        focused = false
        guard list != words(field) else { return }
        model.editTodoRelated(row.id, field: field.rawValue, words: list)
    }
}
