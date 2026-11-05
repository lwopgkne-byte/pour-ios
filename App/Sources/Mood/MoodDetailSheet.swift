import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一条心情（06 交互细节 10.1，点今天的一刻、月历那天的一刻、好时刻；照原型 MoodEntrySheet）：头上「今天 08:20 的心情」、
/// 五个表情直接改档；正中一行「AI 推测 / 你改的」+ 依据；一张白卡三行：精力、情绪词（点 × 去掉、「＋ 添加」）、那一刻；
/// 一句说明；原话和「在笔记库看 ›」；「改好了」（心情色，没改时是灰的）、「删除这条心情」，都带撤销
struct MoodDetailSheet: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let moment: API.MoodMoment
    @State var entry: API.Entry?
    @State var level = 3
    @State var energy: Double?
    @State var emotions: [String] = []
    @State var said = ""
    @State var adding = false
    @State var words: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            LeadingSheetHeader(title) { SheetCloseButton { dismiss() } }.padding(.horizontal, Theme.Space.regular)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 上面留 12：选中的放大、外面一圈，往上多出来约 10，别被滚动区的上沿切掉
                    MoodCheckinRow(selected: level, id: "moodDetail.level") { level = $0 }
                        .padding(.horizontal, -Theme.Space.small).padding(.top, Theme.Space.medium)
                    basisLine.frame(maxWidth: .infinity).padding(.top, Theme.Space.inset)
                    fields.padding(.top, Theme.Space.regular)
                    Text("这是 AI 从你的话里听出来的，不准就改；情绪词只写你说出来的，那一刻是你的原话。")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Space.small).padding(.top, Theme.Space.small)
                    if let source = entry?.sources.first {
                        quote(source).padding(.horizontal, Theme.Space.tight).padding(.top, Theme.Space.regular)
                    }
                    saveButton.padding(.top, Theme.Space.large)
                    Button(role: .destructive) {
                        dismiss()
                        model.delete(moment.entryId)
                    } label: {
                        Text("删除这条心情").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.bad)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("moodDetail.delete")
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.xLarge)
            }
        }
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: reset)
        .task { await load() }
    }

    /// 「今天 08:20 的心情」「10月26日 21:30 的心情」
    var title: String {
        let day = Show.relative(moment.day, today: model.today) ?? Show.monthDay(moment.day)
        return [day, moment.time].compactMap { $0 }.joined(separator: " ") + " 的心情"
    }

    var mood: API.MoodData? {
        if case .mood(let data) = entry?.data { return data }
        return nil
    }

    /// 改了什么（和原来比）；没改是空的
    var changes: [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        if level != moment.level { out["mood"] = .number(Double(level)) }
        if energy != moment.energy { out["energy"] = energy.map { .number($0) } ?? .null }
        if emotions != moment.emotions { out["emotions"] = .array(emotions.map(JSONValue.string)) }
        let trimmed = said.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (moment.moment ?? "") { out["moment"] = trimmed.isEmpty ? .null : .string(trimmed) }
        return out
    }

    func reset() {
        level = moment.level
        energy = moment.energy
        emotions = moment.emotions
        said = moment.moment ?? ""
    }

    /// 改好了：交给服务器改，轻提示能撤销（撤销就把原来的发回去）
    func save() {
        let changed = changes
        guard !changed.isEmpty else { return }
        let before: [String: JSONValue] = changed.keys.reduce(into: [:]) { out, key in
            switch key {
            case "mood": out[key] = .number(moment.mood)
            case "energy": out[key] = moment.energy.map { .number($0) } ?? .null
            case "emotions": out[key] = .array(moment.emotions.map(JSONValue.string))
            default: out[key] = moment.moment.map { .string($0) } ?? .null
            }
        }
        let id = moment.entryId
        model.update(id, changed)
        dismiss()
        model.toast("改好了", action: "撤销") { [weak model] in model?.update(id, before) }
    }

    func load() async {
        if let view = try? await model.client.day(moment.day) {
            entry = view.entries.first { $0.id == moment.entryId }
        }
        if let saved: API.MoodWords = model.client.cached("/api/mood/words") { words = saved.good + saved.bad }
        if let fresh = try? await model.client.moodWords() { words = fresh.good + fresh.bad }
    }
}
