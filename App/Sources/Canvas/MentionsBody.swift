import PourAPI
import PourDesign
import SwiftUI

/// 说到的（产品主人 2026-10-21：画布跟着说的话长——人、事、物、话题）：这一天说到的人、东西、地方、话题，
/// 一类一行小胶囊，按说的先后；点一个就搜它（以前哪天也说到过）。两样以上才长出来。
/// 胶囊旁边写以前说到过多少（服务器数的）：「第一次」「这周 3 天」；下面一行说清楚怎么数的、点了看什么
struct MentionsBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]
    let history: [API.MentionHistory]?
    /// 长按「改名字…」的那一个（docs/模块/产品优化.md R2）
    @State private var renaming: Renaming?
    @State private var newName = ""

    struct Renaming: Identifiable {
        let kind: String
        let name: String
        var id: String { "\(kind)|\(name)" }
    }

    var body: some View {
        let mentions = CanvasPlan.mentions(entries, history: history)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            row("人", mentions.people, kind: "person")
            row("东西", mentions.things, kind: "thing")
            row("地方", mentions.places, kind: "place")
            row("话题", mentions.topics, kind: "tag", prefix: "#")
            // 数字的意思写明白（自然周、数的是天数），和点了会看到什么
            let counted = (history ?? []).contains { !$0.firstTime && $0.weekDays >= 2 }
            Text(counted ? "「这周 N 天」从周一算起，数的是说到的天数；点一下看说到它的原话" : "点一下看说到它的原话")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .alert(
            "改名字", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
            presenting: renaming
        ) { item in
            TextField("对的名字", text: $newName)
            Button("改") { model.renameMention(kind: item.kind, name: item.name, to: newName) }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("「\(item.name)」以后都按对的名字算，原话不改。改成已经有的名字，就合成一个")
        }
    }

    @ViewBuilder private func row(_ title: String, _ items: [String], kind: String, prefix: String = "") -> some View {
        if !items.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minWidth: Theme.Size.tile, alignment: .leading)
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: 0) {
                    ForEach(items, id: \.self) { item in
                        chip(
                            item, shown: prefix + item,
                            note: CanvasPlan.mentionNote(CanvasPlan.history(history, kind: kind, name: item))
                        )
                        // 认错了、写法不一样、不想看到：长按改（原话不改；关于我 →「改过的名字」能恢复）
                        .contextMenu {
                            Button("改名字…", systemImage: "pencil") {
                                newName = item
                                renaming = Renaming(kind: kind, name: item)
                            }
                            Button("不再显示", systemImage: "eye.slash") { model.hideMention(kind: kind, name: item) }
                        }
                    }
                }
            }
            // 一类一组；组名就是前面那个字（不再给组起名，免得念两遍）
            .accessibilityElement(children: .contain)
        }
    }

    private func chip(_ item: String, shown: String, note: String?) -> some View {
        Button {
            model.search = item
        } label: {
            // 名字和「这周第 3 次」拼成一段字：字大了放不下就折行，不会被截掉
            (Text(Show.spaced(shown)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                + Text(note.map { "  \($0)" } ?? "").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel))
                .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                .background(Theme.Palette.fill, in: Capsule())
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(note.map { "\(shown)，\($0)" } ?? shown))
        .accessibilityHint(Text("搜一搜以前也说到的；长按能改名字、不再显示"))
    }
}
