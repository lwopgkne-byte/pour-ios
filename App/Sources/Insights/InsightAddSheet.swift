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
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
        .onChange(of: voice.text) { _, now in
            if voice.active, !now.isEmpty { text = now }
        }
    }

    /// 照原型：左边「记一句」，右边金色胶囊「记下」（打字时键盘挡不住它）；不记了往下拉就关掉
    private var header: some View {
        LeadingSheetHeader("记一句") {
            SheetPillButton("记下", color: Theme.Quick.ideaButton, enabled: ready) {
                model.recordSaying(text.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            }
            .accessibilityIdentifier("insightAdd.save")
        }
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
}
