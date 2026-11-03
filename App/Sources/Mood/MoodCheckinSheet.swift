import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 记心情（01 需求文档 6.3、06 交互细节 4.2）：1 秒记下，想说为什么再说——五个表情（选中的放大）；
/// 好的感觉、不好的感觉两排胶囊（心情不好时不好的排前面），可以多选、可以不选；「因为……」一行宋体 + 麦克风；
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
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    MoodCheckinRow(selected: level, id: "moodCheckin.level") { level = $0 }
                    chips
                    reason
                    Text("记下的是一句原话「\(said)」；情绪词只写你点的和你说的")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.vertical, Theme.Space.small)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // 「记下」钉在最下面：写「因为」时跟着键盘上来，不被盖住
        .safeAreaInset(edge: .bottom) {
            saveButton.padding(.horizontal, Theme.Space.regular).padding(.vertical, Theme.Space.small)
                .background(Theme.Palette.background)
        }
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { level = level ?? start.level }
        .task { await loadWords() }
        .onChange(of: voice.text) { _, now in
            if voice.active, !now.isEmpty { because = now }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("记下").font(Theme.Typeface.bodySemibold)
                .foregroundStyle(level == nil ? Theme.Palette.tertiaryLabel : Theme.Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer)
                .background(
                    level == nil ? Theme.Palette.fill : Theme.Palette.accentFill,
                    in: Theme.rounded(Theme.Corner.hubTile))
        }
        .buttonStyle(PressScale())
        .disabled(level == nil)
        .accessibilityIdentifier("moodCheckin.save")
    }

    private var header: some View {
        HStack {
            ThemeTextButton("取消", font: Theme.Typeface.body) { dismiss() }
            Spacer()
            Text("记心情").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: Theme.Size.touch, height: Theme.Size.touch)
        }
        .padding(.top, Theme.Space.small)
    }

    /// 好的、不好的两排（心情不好时不好的排前面）：点一下选上，再点一下去掉
    private var chips: some View {
        let good: (title: String, list: [String]) = ("好的感觉", words.good)
        let bad: (title: String, list: [String]) = ("不好的感觉", words.bad)
        let rows = (level ?? 3) <= 2 ? [bad, good] : [good, bad]
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            ForEach(rows, id: \.title) { title, list in
                Text(title).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                    ForEach(list, id: \.self) { word in
                        FilterChip(word, selected: picked.contains(word)) {
                            toggle(word)
                        }
                    }
                }
            }
        }
    }

    /// 点一下选上，再点一下去掉（按点的先后排）
    private func toggle(_ word: String) {
        if let index = picked.firstIndex(of: word) { picked.remove(at: index) } else { picked.append(word) }
    }

    /// 因为……（可以不填）：一行宋体 + 麦克风
    private var reason: some View {
        HStack(spacing: Theme.Space.small) {
            TextField("因为……（可以不填）", text: $because, axis: .vertical)
                .font(Theme.Typeface.quote).lineLimit(1...4).focused($focused)
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
                Image(systemName: voice.active ? "stop.fill" : Theme.Symbol.mic).font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(voice.active ? Theme.Palette.onAccent : Theme.Palette.accent)
                    .frame(width: Theme.Size.sendButton, height: Theme.Size.sendButton)
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
