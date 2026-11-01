import PourAPI
import PourCore
import PourDesign
import SwiftUI

extension MoodDetailSheet {
    /// 「AI 推测」或「你改的」+ 依据：你当时说的那几个字
    var basisLine: some View {
        let mine = moment.byYou || level != moment.level
        let span = entry?.sources.first { $0.action == "created" }?.span.trimmingCharacters(in: .whitespaces)
        return HStack(spacing: Theme.Space.small) {
            Text(mine ? "你改的" : "AI 推测").font(Theme.Typeface.caption)
                .foregroundStyle(mine ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
                .padding(.horizontal, Theme.Space.snug).padding(.vertical, Theme.Space.hairline)
                .background(mine ? Theme.Palette.remindFill : Theme.Palette.fill, in: Capsule())
            if let span, !span.isEmpty, !mine {
                Text("依据：你说「\(span)」").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 精力：五档说法 + 没说（只在你说到时才有，没说就是没说）
    var energyRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("精力").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(Array((Show.energyWords + ["没说"]).enumerated()), id: \.offset) { index, word in
                    let value: Double? = index < 5 ? Double(index + 1) : nil
                    let chosen = energy.map { Int($0.rounded()) } == value.map { Int($0) }
                    FilterChip(word, selected: chosen) { energy = value }
                }
            }
        }
    }

    /// 情绪词：点 × 去掉；「＋ 添加」展开常用的那几个
    var emotionsRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("情绪词（只写你说出来的）").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(emotions, id: \.self) { word in
                    FilterChip("\(word) ✕", selected: true) { emotions.removeAll { $0 == word } }
                        .accessibilityLabel(Text("\(word)，点了去掉"))
                }
                FilterChip(adding ? "收起" : "＋ 添加", selected: false) { adding.toggle() }
                    .accessibilityIdentifier("moodDetail.add")
            }
            if adding {
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                    ForEach(words.filter { !emotions.contains($0) && $0 != "累" }, id: \.self) { word in
                        FilterChip(word, selected: false) { emotions.append(word) }
                    }
                }
            }
        }
    }

    /// 那一刻：直接改（宋体）；没有就写一句
    var momentField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("那一刻").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            TextField("让你有这种感觉的那一刻（可以不写）", text: $said, axis: .vertical)
                .font(Theme.Typeface.quote).lineLimit(1...5)
                .padding(Theme.Space.medium)
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.stat))
                .accessibilityIdentifier("moodDetail.moment")
        }
    }

    /// 原话（宋体）和什么时候说的，点了去笔记库
    func quote(_ source: API.Source) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            QuoteBlock(source.text, highlight: moment.moment, lineLimit: 4)
            Button {
                dismiss()
                model.openLink("/library?note=\(source.noteId)")
            } label: {
                Text("\(TodoBoard.saidAt(source.createdAt) ?? Show.monthDay(moment.day)) 你说的 · 在笔记库看 ›")
                    .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.accent)
                    .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 改好了（没改时是灰的）
    var saveButton: some View {
        let ready = !changes.isEmpty
        return Button(action: save) {
            Text("改好了").font(Theme.Typeface.bodySemibold)
                .foregroundStyle(ready ? Theme.Palette.onAccent : Theme.Palette.tertiaryLabel)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch + Theme.Space.tight)
                .background(
                    ready ? Theme.Palette.accentFill : Theme.Palette.fill, in: Theme.rounded(Theme.Corner.hubTile))
        }
        .buttonStyle(PressScale())
        .disabled(!ready)
        .accessibilityIdentifier("moodDetail.save")
    }
}
