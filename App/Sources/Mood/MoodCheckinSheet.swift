import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 记心情（01 需求文档 6.3、06 交互细节 4.2）：1 秒记下，想说为什么再说——五个表情（选中的放大）；
/// 好的感觉、不好的感觉两组胶囊（心情不好时不好的排前面），可以多选、可以不选；「因为……」一行宋体 + 麦克风；
/// 记下的是一句原话（「心情挺好，放松，因为……」），Pour 照常整理：情绪词只写你点的和你说的
struct MoodCheckinSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let start: MoodCheckin
    @State private var level: Int?
    @State private var picked: [String] = []
    @State private var because = ""
    @State private var words = API.MoodWords.common
    @State private var voice = VoiceSession(input: VoiceSession.makeInput())
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, Theme.Space.regular)
            ScrollView {
                // 照原型 CheckinSheet：表情一排、两组胶囊、「因为」、一句说明、「记下」从上往下排着（不钉在最下面）
                VStack(alignment: .leading, spacing: 0) {
                    // 一排五个表情两边只留 8（原型 padding 14px 8px 0）
                    MoodCheckinRow(selected: level, id: "moodCheckin.level") { level = $0 }
                        .padding(.horizontal, -Theme.Space.small).padding(.top, Theme.Space.medium)
                    chips
                    caption("因为……（可以不填）")
                    reason
                    Text("记下的是一句原话「\(said)」；情绪词只写你点的和你说的")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Space.tight).padding(.top, Theme.Space.medium)
                    saveButton.padding(.top, Theme.Space.regular)
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.xLarge)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // 照原型：没说哪一档就先选好「挺好」，点「记下」就记（1 秒记下）
        .onAppear { level = level ?? start.level ?? 4 }
        .task { await loadWords() }
        .onChange(of: voice.text) { _, now in
            if voice.active, !now.isEmpty { because = now }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("记下").font(Theme.Typeface.bodySemibold)
                .foregroundStyle(level == nil ? Theme.Palette.tertiaryLabel : Theme.Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer - Theme.Space.tight)
                // 照原型 .primary：52 高、圆角 16，「记下」是心情的颜色
                .background(
                    level == nil ? Theme.Palette.fill : Theme.Quick.moodButton, in: Theme.rounded(Theme.Corner.stat))
        }
        .buttonStyle(PressScale())
        .disabled(level == nil)
        .accessibilityIdentifier("moodCheckin.save")
    }

    /// 照原型：左边问一句「现在心情怎么样？」，右上角灰圆的关闭
    private var header: some View {
        LeadingSheetHeader("现在心情怎么样？") { SheetCloseButton { dismiss() } }
    }

    /// 好的、不好的两组（心情不好时不好的排前面）：点一下选上（心情色），再点一下去掉
    @ViewBuilder private var chips: some View {
        let good = ("好的感觉（可以不选）", words.good)
        let bad = ("不好的感觉（可以不选）", words.bad)
        ForEach((level ?? 4) <= 2 ? [bad, good] : [good, bad], id: \.0) { title, list in
            caption(title)
            ChipFlow {
                ForEach(list, id: \.self) { word in
                    FilterChip(word, selected: picked.contains(word), selectedFill: Theme.Quick.moodButton) {
                        toggle(word)
                    }
                }
            }
        }
    }

    /// 一块上面的小字（原型 13px，离上面 20、离下面 8，比胶囊往里 4）
    private func caption(_ text: String) -> some View {
        Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.tight)
            .padding(.top, Theme.Space.large).padding(.bottom, Theme.Space.small)
    }

    /// 点一下选上，再点一下去掉（按点的先后排）
    private func toggle(_ word: String) {
        if let index = picked.firstIndex(of: word) { picked.remove(at: index) } else { picked.append(word) }
    }

    /// 因为……：白底一行宋体（原型的举例「比如：晚上楼下飘来烤红薯的香味」）+ 浅蓝圆的麦克风
    private var reason: some View {
        HStack(spacing: Theme.Space.small) {
            TextField("比如：晚上楼下飘来烤红薯的香味", text: $because, axis: .vertical)
                .font(Theme.Typeface.quote).lineLimit(1...4).focused($focused)
                .accessibilityLabel(Text("因为……（可以不填）"))
                .accessibilityIdentifier("moodCheckin.because")
            Button {
                Task {
                    if voice.active {
                        if let said = await voice.finish() { because = said }
                    } else {
                        focused = false
                        voice.start(.tap)
                    }
                }
            } label: {
                Image(systemName: voice.active ? "stop.fill" : Theme.Symbol.mic).font(Theme.Typeface.micIcon)
                    .foregroundStyle(voice.active ? Theme.Palette.onAccent : Theme.Palette.accent)
                    .frame(width: Theme.Size.micButton, height: Theme.Size.micButton)
                    .background(voice.active ? Theme.Palette.accentFill : Theme.Palette.bubble, in: Circle())
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Circle())
            }
            .buttonStyle(PressScale())
            .accessibilityLabel(Text(voice.active ? "说完了" : "说话"))
        }
        .padding(.leading, Theme.Space.regular).padding(.trailing, Theme.Space.tight)
        .frame(minHeight: Theme.Size.composer)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.stat))
    }

    /// 生成的原话：「心情挺好」「心情不太好，烦躁，因为方案又改了」（没选档时拿「挺好」举例）
    private var said: String {
        MoodText.said(level: level ?? 4, emotions: picked, because: because)
    }

    private func save() {
        guard let level else { return }
        let reason = because.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = PourDate.localDateTime(Date(), in: .current)
        model.record(
            mood: MoodText.said(level: level, emotions: picked, because: reason),
            pending: PendingMood(
                clientId: UUID().uuidString, level: level, emotions: picked, because: reason.isEmpty ? nil : reason,
                day: model.today, time: String(now.suffix(5))))
        dismiss()
    }

    private func loadWords() async {
        if let saved: API.MoodWords = model.client.cached("/api/mood/words") { words = saved }
        if let fresh = try? await model.client.moodWords() { words = fresh }
    }
}
