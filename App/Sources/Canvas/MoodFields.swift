import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 心情：要改的时候才有按钮，按钮上写的是字；点一下就改。
/// 「依据」是 AI 听出这条心情的那几个字，加上它判断的「好 · 强」；你自己改过级别的写「你改的」
struct MoodFields: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let mood: API.MoodData

    private static let tones = ["good": "好", "neutral": "一般", "bad": "不好", "mixed": "又好又不好"]
    private static let strengths = ["weak": "弱", "medium": "中", "strong": "强"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StackedRow(label: "心情") {
                VStack(alignment: .trailing, spacing: Web.space1) {
                    choices(Show.moodWords, selected: Int(mood.mood.rounded()) - 1) { index in
                        model.update(entry.id, ["mood": .number(Double(index + 1))])
                    }
                    if let basis {
                        Text(Show.spaced("依据：\(basis)")).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    }
                }
            }
            StackedRow(label: "精力") {
                choices(Show.energyWords + ["没说"], selected: mood.energy.map { Int($0.rounded()) - 1 } ?? 5) { index in
                    model.update(entry.id, ["energy": index == 5 ? .null : .number(Double(index + 1))])
                }
            }
            PeekRow(label: "情绪") {
                let emotions = mood.emotions.joined(separator: "，")
                InlineEdit(label: "情绪词（用逗号分开）", value: emotions, placeholder: "没有") { text in
                    model.update(entry.id, ["emotions": .array(splitWords(text))])
                }
            }
            PeekRow(label: mood.moment == nil ? "添加" : "那一刻") {
                InlineEdit(label: "那一刻", value: mood.moment ?? "", placeholder: "那一刻") { text in
                    model.update(entry.id, ["moment": .string(text.trimmingCharacters(in: .whitespaces))])
                }
            }
            Text("这是 AI 从你的话里听出来的，不准就改。").font(Web.caption).foregroundStyle(Web.fgTertiary)
                .padding(.top, Web.space1)
        }
    }

    /// 依据：你当时说的那几个字和 AI 判断的「好 · 强」；你改过的写「你改的」
    private var basis: String? {
        let span = entry.sources.first {
            $0.action == "created" && !$0.span.trimmingCharacters(in: .whitespaces).isEmpty
        }?
        .span.trimmingCharacters(in: .whitespaces)
        let said = span.map { "你说「\($0)」" }
        if mood.byYou == true { return "你改的" }
        guard let tone = mood.tone.flatMap({ Self.tones[$0] }) else { return said }
        return "\(said ?? "AI 听出来的")（\(tone) · \(Self.strengths[mood.strength ?? "medium"] ?? "中")）"
    }

    /// 一排写着字的按钮；选中的边框深一点、字重一点
    private func choices(_ words: [String], selected: Int, pick: @escaping (Int) -> Void) -> some View {
        PourFlowLayout(spacing: Web.space1, lineSpacing: Web.space1) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let chosen = index == selected
                Button {
                    if !chosen { pick(index) }
                } label: {
                    Text(word).font(chosen ? Web.bodyMedium : Web.body).foregroundStyle(
                        chosen ? Web.fg : Web.fgSecondary
                    )
                    .padding(.horizontal, Web.space3)
                    .frame(minHeight: Web.touch)
                    .overlay(
                        RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                            chosen ? Web.lineStrong : Web.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
    }
}

/// 放不下一行的那种（一排按钮）：名称在上面，按钮在下面靠右
private struct StackedRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            Text(label).font(Web.body).foregroundStyle(Web.fg)
            content().frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, Web.space2)
    }
}
