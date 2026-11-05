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

    /// 一张白卡三行（照原型 .grp）：左边一列名字，右边精力、情绪词、那一刻
    var fields: some View {
        VStack(spacing: 0) {
            fieldRow("精力") { energyChips }
            Divider().padding(.leading, Theme.Space.regular)
            fieldRow("情绪词") { emotionChips }
            Divider().padding(.leading, Theme.Space.regular)
            fieldRow("那一刻") { momentField }
        }
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.stat))
    }

    /// 一行：名字（原型 .rl 62 宽、15 号次要色），右边是内容
    func fieldRow<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.medium) {
            Text(name).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(width: Theme.Size.label - Theme.Space.hairline, alignment: .leading)
                .frame(minHeight: Theme.Size.capsule)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Space.regular).padding(.vertical, Theme.Space.small + Theme.Space.hairline)
    }

    /// 精力：五档说法 + 没说（只在你说到时才有，没说就是没说）
    var energyChips: some View {
        ChipFlow {
            ForEach(Array((Show.energyWords + ["没说"]).enumerated()), id: \.offset) { index, word in
                let value: Double? = index < 5 ? Double(index + 1) : nil
                let chosen = energy.map { Int($0.rounded()) } == value.map { Int($0) }
                FilterChip(word, selected: chosen) { energy = value }
            }
        }
    }

    /// 情绪词（照原型）：浅粉底粉字「累 ×」点了去掉；「＋ 添加」展开常用的那几个
    var emotionChips: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ChipFlow {
                ForEach(emotions, id: \.self) { word in
                    Button {
                        emotions.removeAll { $0 == word }
                    } label: {
                        chipLabel("\(word) ×", ink: Theme.Mood.softInk, fill: Theme.Mood.soft)
                    }
                    .buttonStyle(PressScale())
                    .accessibilityLabel(Text("\(word)，点了去掉"))
                }
                Button {
                    adding.toggle()
                } label: {
                    chipLabel(adding ? "收起" : "＋ 添加", ink: Theme.Palette.accent, fill: Theme.Palette.fill)
                }
                .buttonStyle(PressScale())
                .accessibilityIdentifier("moodDetail.add")
            }
            if adding {
                ChipFlow {
                    ForEach(words.filter { !emotions.contains($0) && $0 != "累" }, id: \.self) { word in
                        FilterChip(word, selected: false) { emotions.append(word) }
                    }
                }
            }
        }
    }

    /// 一个小胶囊的样子（看得见的 32 高，点的地方 44）
    func chipLabel(_ text: String, ink: Color, fill: Color) -> some View {
        Text(text).font(Theme.Typeface.cardTitle).foregroundStyle(ink)
            .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
            .background(fill, in: Capsule())
            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
    }

    /// 那一刻：直接改（宋体）；没有就写「没说是哪一刻」
    var momentField: some View {
        TextField("没说是哪一刻", text: $said, axis: .vertical)
            .font(Theme.Typeface.quote).lineLimit(1...5)
            .frame(minHeight: Theme.Size.capsule)
            .accessibilityLabel(Text("那一刻"))
            .accessibilityIdentifier("moodDetail.moment")
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

    /// 改好了（照原型：心情色、52 高；没改时是灰的）
    var saveButton: some View {
        let ready = !changes.isEmpty
        return Button(action: save) {
            Text("改好了").font(Theme.Typeface.bodySemibold)
                .foregroundStyle(ready ? Theme.Palette.onAccent : Theme.Palette.tertiaryLabel)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer - Theme.Space.tight)
                .background(
                    ready ? Theme.Quick.moodButton : Theme.Palette.fill, in: Theme.rounded(Theme.Corner.stat))
        }
        .buttonStyle(PressScale())
        .disabled(!ready)
        .accessibilityIdentifier("moodDetail.save")
    }
}
