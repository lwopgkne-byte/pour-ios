import PourAPI
import PourDesign
import SwiftUI

/// 一个月一组的标题（「2026年10月」）：感悟、好时刻按月分组
struct LibraryMonth: View {
    let title: String

    var body: some View {
        Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Theme.Space.small)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.separator).frame(height: 1) }
            .padding(.bottom, Theme.Space.tight)
            .accessibilityAddTraits(.isHeader)
    }

    /// 「2026-10-15」→「2026年10月」
    static func of(_ day: String) -> String { "\(day.prefix(4))年\(Int(day.dropFirst(5).prefix(2)) ?? 0)月" }

    /// 按月分组，保持原来的顺序（新的在前）
    static func group<Item>(_ items: [Item], day: (Item) -> String) -> [(month: String, items: [Item])] {
        var out: [(month: String, items: [Item])] = []
        for item in items {
            let month = of(day(item))
            if let last = out.indices.last, out[last].month == month {
                out[last].items.append(item)
            } else {
                out.append((month, [item]))
            }
        }
        return out
    }
}

/// 好时刻（docs/prd-mood.md 5.7）：你说过觉得好的那一刻，按月分组、新的在前。不显示总数、不排名。
/// 点那一刻打开这条心情的详情；「原话」打开那一整段原话。不好的时刻不单独列
struct MomentsView: View {
    @Environment(AppModel.self) private var model
    let openNote: (Int) -> Void
    @State private var moments: [API.Moment]?
    @State private var problem: String?

    var body: some View {
        Group {
            if let moments {
                if moments.isEmpty {
                    LibraryEmpty(text: "还没有好时刻。说到哪一刻觉得挺好，它会被收在这里。")
                } else {
                    content(moments)
                }
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }.padding(
                    .top, Theme.Space.xLarge)
            } else {
                SkeletonBlock(height: (Theme.Space.section * 2)).padding(.top, Theme.Space.xLarge)
            }
        }
        .task(id: model.dataVersion) { await load() }
    }

    private func content(_ moments: [API.Moment]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            Text("你说过觉得好的那一刻。心情是 AI 听出来的，点开可以改。").font(Theme.Typeface.footnote).foregroundStyle(
                Theme.Palette.secondaryLabel)
            VStack(alignment: .leading, spacing: (Theme.Size.touch + Theme.Space.tight)) {
                ForEach(LibraryMonth.group(moments, day: \.entry.day), id: \.month) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.section) {
                        LibraryMonth(title: group.month)
                        ForEach(group.items) { moment($0) }
                    }
                }
            }
        }
        .padding(.top, Theme.Space.xLarge)
    }

    @ViewBuilder private func moment(_ item: API.Moment) -> some View {
        if case .mood(let mood) = item.entry.data {
            let emotions = mood.emotions.reduce(into: [String]()) {
                if !$0.contains($1) && $0.count < 3 { $0.append($1) }
            }
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Button {
                    model.openEntry(item.entry.id, day: item.entry.day)
                } label: {
                    EssayQuote(text: mood.moment ?? "").padding(.vertical, Theme.Space.tight).padding(
                        .horizontal, Theme.Space.small
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -Theme.Space.small)
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.tight) {
                    Text(Show.monthDay(item.entry.day))
                    Text("·")
                    Text(Show.moodWord(mood.mood))
                    if !emotions.isEmpty {
                        Text("·")
                        Text(emotions.joined(separator: "、"))
                    }
                    if let note = item.noteId {
                        LinkButton("原话", font: Theme.Typeface.footnoteSemibold) { openNote(note) }
                    }
                }
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }

    private func load() async {
        do {
            moments = try await model.client.moments()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 随笔集里的一段：左边一条细线，小节那么大，行高 1.9
struct EssayQuote: View {
    let text: String

    var body: some View {
        Text(Show.spaced(text)).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label).lineSpacing(
            Theme.Leading.quote
        )
        .padding(.leading, Theme.Space.medium)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.Palette.separator).frame(width: Theme.Space.tight / 2) }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 什么都还没有：一句话
struct LibraryEmpty: View {
    let text: String

    var body: some View {
        Text(text).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).padding(
            .top, Theme.Space.xLarge)
    }
}
