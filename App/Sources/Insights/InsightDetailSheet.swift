import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一条感悟（06 交互细节 10.3，点任意一张卡、今天重温背面的「以前也说过类似的」）：大宋体直接改字；标签点 × 去掉、
/// 「＋ 添加」（常用的标签、自己写）；「收藏成语录」开关（关掉就是「不放进语录」）；原话（在笔记库看 ›）；
/// 以前也说过类似的几条；「好了」钉在最下面（改字时跟着键盘上来）；分享成图片、删除（能撤销）
struct InsightDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: API.InsightItem
    @State private var quote = ""
    @State private var tags: [String] = []
    @State private var adding = false
    @State private var newTag = ""
    @State private var detail: API.InsightDetail?
    @FocusState private var tagFocused: Bool

    /// 现在的样子（点过星、改过的先用上）
    private var current: API.InsightItem { model.insight.shown(item) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("\(Show.monthDay(item.day)) · 感悟") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    quoteField
                    tagsRow
                    starRow
                    if let said = detail?.said { saidBlock(said) }
                    if let related = detail?.related, !related.isEmpty { relatedBlock(related) }
                    shareAndDelete
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.vertical, Theme.Space.small)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            doneButton.padding(.horizontal, Theme.Space.regular).padding(.vertical, Theme.Space.small)
                .background(Theme.Palette.background)
        }
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            quote = current.quote
            tags = current.tags
        }
        .task { detail = try? await model.client.insight(item.id) }
    }

    /// 那一句：大宋体，点字就能改
    private var quoteField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            TextField("那一句", text: $quote, axis: .vertical)
                .font(Theme.Idea.bigQuote(quote)).lineSpacing(Theme.Leading.quote).lineLimit(1...8)
                .accessibilityIdentifier("insightDetail.quote")
            Text(item.saying == true ? "你让记下的一句，点字就能改" : "这是 AI 从你的话里摘出来的，点字就能改")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(Theme.Space.regular)
        .background(Theme.Idea.paper, in: Theme.rounded(Theme.Corner.card))
        .themeEdge(radius: Theme.Corner.card)
    }

    /// 标签：点 × 去掉；「＋ 添加」展开常用的标签和一个输入框
    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("标签").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(tags, id: \.self) { tag in
                    FilterChip("\(tag) ✕", selected: false) { tags.removeAll { $0 == tag } }
                        .accessibilityLabel(Text("\(tag)，点了去掉"))
                }
                FilterChip(adding ? "收起" : "＋ 添加", selected: false) {
                    adding.toggle()
                    tagFocused = adding
                }
                .accessibilityIdentifier("insightDetail.addTag")
            }
            if adding { addTag }
        }
    }

    /// 添加标签：常用的点一下就加；没有的自己写
    private var addTag: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            let common = commonTags.filter { !tags.contains($0) }
            if !common.isEmpty {
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                    ForEach(common, id: \.self) { tag in FilterChip(tag, selected: false) { tags.append(tag) } }
                }
            }
            TextField("新的标签，写好按换行", text: $newTag)
                .font(Theme.Typeface.body).focused($tagFocused).submitLabel(.done)
                .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.touch)
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.chip))
                .onSubmit {
                    let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tag.isEmpty, !tags.contains(tag) { tags.append(tag) }
                    newTag = ""
                }
                .accessibilityIdentifier("insightDetail.newTag")
        }
    }

    /// 别的感悟上用过的标签（感悟页拿过的那份），多的在前
    private var commonTags: [String] {
        guard let page: API.InsightsPage = model.client.cached(APIClient.insightsPath()) else { return [] }
        return Array(InsightsPage.tagCounts(page.insights).map(\.tag).prefix(12))
    }

    /// 收藏成语录：关掉就是「不放进语录」（马上生效）
    private var starRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Toggle(isOn: Binding(get: { current.isStarred }, set: { model.star(item, $0) })) {
                Text("收藏成语录").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            }
            .tint(Theme.Idea.star)
            .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch + Theme.Space.small)
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.stat))
            .accessibilityIdentifier("insightDetail.star")
            Text("收藏的会出现在「语录 ★」、小组件「我的语录」和回顾的「你说过」里；关掉就是「不放进语录」。")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 原话（宋体，那一句标出来）和什么时候说的，点了去笔记库
    private func saidBlock(_ said: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            QuoteBlock(said, highlight: item.quote, lineLimit: 6)
            if let note = item.noteId {
                Button {
                    dismiss()
                    model.open("/library?note=\(note)")
                } label: {
                    Text("\(Show.monthDay(item.day)) 你说的 · 在笔记库看 ›").font(Theme.Typeface.footnote)
                        .monospacedDigit().foregroundStyle(Theme.Palette.accent)
                        .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 以前也说过类似的：宋体那段话 + 哪天，点了去笔记库看那一段
    private func relatedBlock(_ related: [API.Related]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("以前也说过类似的 \(related.count) 条").font(Theme.Typeface.cardTitle)
                .foregroundStyle(Theme.Palette.label).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(related.enumerated()), id: \.offset) { index, one in
                    if index > 0 { Divider() }
                    Button {
                        guard let note = one.noteId else { return }
                        dismiss()
                        model.open("/library?note=\(note)")
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.tight) {
                            Text(one.text).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                                .lineSpacing(Theme.Leading.body).multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(Show.monthDay(one.day)).font(Theme.Typeface.footnote).monospacedDigit()
                                .foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Space.medium).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
            .themeCard(padding: Theme.Space.regular)
        }
    }

    /// 分享成图片、删除（删除能撤销）
    private var shareAndDelete: some View {
        HStack(spacing: Theme.Space.small) {
            sheetAction("分享成图片", symbol: "square.and.arrow.up", color: Theme.Palette.label) {
                model.insight.sheet = .share(InsightDetailSheet.edited(current, quote: quote, tags: tags))
            }
            .accessibilityIdentifier("insightDetail.share")
            sheetAction("删除", symbol: Theme.Symbol.delete, color: Theme.Palette.bad) {
                model.deleteInsight(item)
            }
            .accessibilityIdentifier("insightDetail.delete")
        }
    }

    private func sheetAction(
        _ title: String, symbol: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(Theme.Typeface.bodyMedium).foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch + Theme.Space.tight)
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.hubTile))
        }
        .buttonStyle(PressScale())
    }

    /// 好了：改了字、标签就交给服务器改（轻提示能撤销），没改就是关上
    private var doneButton: some View {
        Button {
            let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != current.quote || tags != current.tags {
                model.edit(item, quote: trimmed, tags: tags)
            }
            dismiss()
        } label: {
            Text("好了").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer)
                .background(Theme.Palette.accentFill, in: Theme.rounded(Theme.Corner.hubTile))
        }
        .buttonStyle(PressScale())
        .accessibilityIdentifier("insightDetail.done")
    }

    /// 分享时用正在改的样子
    static func edited(_ item: API.InsightItem, quote: String, tags: [String]) -> API.InsightItem {
        var out = item
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { out.quote = trimmed }
        out.tags = tags
        return out
    }
}
