import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 记一句（01 需求文档 7.3、06 交互细节 5.2）：大宋体输入框 + 麦克风；「记下」→ 原话「记一句：……」走整理，
/// 自动收藏成语录；感悟页最上面马上多一张（亮一下），轻提示能撤销。「我的」的快捷、感悟页右上角「＋」都打开它
struct InsightAddSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var voice = VoiceSession(input: VoiceSession.makeInput())
    @FocusState private var focused: Bool

    private var ready: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, Theme.Space.regular)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    TextField("想明白的一件事、想留着的一句话……", text: $text, axis: .vertical)
                        .font(Theme.Idea.bigQuote(text)).lineSpacing(Theme.Leading.quote).lineLimit(4...10)
                        .focused($focused)
                        .accessibilityIdentifier("insightAdd.text")
                    HStack {
                        Text("记下的会收藏成你的语录").font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                        Spacer()
                        mic
                    }
                }
                .padding(Theme.Space.large)
                .background(Theme.Idea.paper, in: Theme.rounded(Theme.Corner.card))
                .themeEdge(radius: Theme.Corner.card)
                .padding(.horizontal, Theme.Space.regular)
                .padding(.vertical, Theme.Space.small)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // 「记下」钉在最下面：打字时跟着键盘上来，不被盖住
        .safeAreaInset(edge: .bottom) {
            saveButton.padding(.horizontal, Theme.Space.regular).padding(.vertical, Theme.Space.small)
                .background(Theme.Palette.background)
        }
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
        .onChange(of: voice.text) { _, now in
            if voice.active, !now.isEmpty { text = now }
        }
    }

    private var header: some View {
        HStack {
            ThemeTextButton("取消", font: Theme.Typeface.body) { dismiss() }
            Spacer()
            Text("记一句").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: Theme.Size.touch, height: Theme.Size.touch)
        }
        .padding(.top, Theme.Space.small)
    }

    /// 麦克风：点了开始说，再点说完（转成字只在这台手机上）
    private var mic: some View {
        Button {
            Task {
                if voice.active {
                    if let said = await voice.finish() { text = said }
                } else {
                    focused = false
                    voice.start(.tap)
                }
            }
        } label: {
            Image(systemName: voice.active ? "stop.fill" : Theme.Symbol.mic).font(Theme.Typeface.bodySemibold)
                .foregroundStyle(voice.active ? Theme.Palette.onAccent : Theme.Idea.ink)
                .frame(
                    width: Theme.Size.sendButton + Theme.Space.tight, height: Theme.Size.sendButton + Theme.Space.tight
                )
                .background(voice.active ? Theme.Palette.accentFill : Theme.Idea.soft, in: Circle())
                .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(voice.active ? "说完了" : "说话"))
    }

    private var saveButton: some View {
        Button {
            model.recordSaying(text.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } label: {
            Text("记下").font(Theme.Typeface.bodySemibold)
                .foregroundStyle(ready ? Theme.Palette.onAccent : Theme.Palette.tertiaryLabel)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer)
                .background(
                    ready ? Theme.Palette.accentFill : Theme.Palette.fill, in: Theme.rounded(Theme.Corner.hubTile))
        }
        .buttonStyle(PressScale())
        .disabled(!ready)
        .accessibilityIdentifier("insightAdd.save")
    }
}
