import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一周条下面几行安静的字（有才出现）：空的一天说一句；还在整理的（点了打开对话）；要你确认的（点了滚到那一条）。
/// 一天的总结、亮点不放在画布上：产品主人 2026-10-21「一天过完了才知道做了什么」，在回顾里（DayLook）
struct CanvasNotes: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: API.DayView
    let scrollTo: (String) -> Void

    var body: some View {
        let progress = CanvasEmpty.progress(model.dayNotes)
        let waiting = day.entries.filter(\.pending)
        if day.entries.isEmpty || progress != nil || !waiting.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if day.entries.isEmpty && progress == nil {
                    Text(Show.spaced(CanvasEmpty.text(model))).font(Theme.Typeface.body)
                        .foregroundStyle(Theme.Palette.secondaryLabel).lineSpacing(Theme.Leading.body)
                }
                if let progress {
                    line(progress, symbol: "sparkles", breathing: true) {
                        withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                            model.chatOpen = true
                        }
                    }
                }
                if let first = waiting.first {
                    line("有 \(waiting.count) 条要你确认一下", symbol: "questionmark.circle", breathing: false) {
                        scrollTo(Show.group(first, model.categories))
                    }
                }
            }
        }
    }

    private func line(_ text: String, symbol: String, breathing: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.small) {
                Image(systemName: symbol).foregroundStyle(Theme.Palette.accent)
                    .symbolEffect(.breathe, options: .repeating, isActive: breathing && !reduceMotion)
                Text(Show.spaced(text)).foregroundStyle(Theme.Palette.label)
                Image(systemName: "chevron.right").font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .font(Theme.Typeface.footnoteSemibold)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 空的一天、整理进度：沿用以前画布上的说法
enum CanvasEmpty {
    /// 今天「还是空白…」，以前的日子「没有留下记录」，以后的日子「还没到」；说过话但没整理出记录的也说一声
    @MainActor static func text(_ model: AppModel) -> String {
        if !model.dayNotes.isEmpty { return "说过的话里没有整理出记录。" }
        let offset = PourDate.diffDays(model.shownDay, model.today)
        if offset == 0 {
            // 画布上已经有日历的日程、健康的步数（docs/模块/产品优化.md R5、R6）：就不说「还是空白」了
            let shown = !model.shownEvents.isEmpty || model.day?.health?.steps != nil
            return shown ? "说说你做了什么，这里会自己长出来。" : "今天还是空白。说说你做了什么，这里会自己长出来。"
        }
        return offset > 0 ? "这一天还没到。" : "这一天没有留下记录。"
    }

    /// 还在整理、等着、没整理成的话：一行安静的字，点一下打开对话
    static func progress(_ notes: [API.Note]) -> String? {
        let count = { (status: String) in notes.filter { $0.status == status }.count }
        let parts = [
            count("processing") > 0 ? "正在整理…" : nil,
            count("pending") > 0 ? "\(count("pending")) 段等待整理" : nil,
            count("failed") > 0 ? "\(count("failed")) 段处理失败" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 区块标题：「今天推进的目标」「一天的时间」，右边一个小字
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Space.small)
            if let trailing {
                Text(trailing).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }
}
