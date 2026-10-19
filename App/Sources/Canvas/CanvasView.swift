import PourCore
import PourData
import PourDesign
import SwiftUI

/// 生活画布（网页版 CanvasPage 1 比 1）：回答「我今天过得怎么样」。
/// 从上到下：日期、一句话总结、还在整理的那一行、时间轴、类别卡片；左右滑换日子
struct CanvasView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DayHeader(picking: $picking)
                CanvasBody()
                    .padding(.top, Web.space4)
                    .id(model.shownDay)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Web.space4)
            .padding(.top, Web.space4)
            .padding(.bottom, Web.space12)
        }
        .scrollDismissesKeyboard(.interactively)
        // 手机：左右滑动切换日期（横着滑 60 点以上、比竖着多一倍才算）
        .simultaneousGesture(
            DragGesture(minimumDistance: Web.space6).onEnded { drag in
                let across = drag.translation.width
                guard abs(across) > Web.space12 + Web.space3, abs(across) > abs(drag.translation.height) * 2 else {
                    return
                }
                withAnimation(Web.panel) { model.show(PourDate.addDays(model.shownDay, across > 0 ? -1 : 1)) }
            }
        )
        .sheet(isPresented: $picking) { DayPicker() }
    }
}

/// 日期标题：「10月19日 周一」加上「今天」；不是今天、昨天就是「回到今天」。点日期选哪一天
private struct DayHeader: View {
    @Environment(AppModel.self) private var model
    @Binding var picking: Bool

    var body: some View {
        let relative = WebText.relative(model.shownDay, today: model.today)
        HStack(alignment: .firstTextBaseline, spacing: Web.space3) {
            Button {
                picking = true
            } label: {
                Text(WebText.dayTitle(model.shownDay, today: model.today))
                    .font(Web.title).foregroundStyle(Web.fg).lineLimit(1).fixedSize()
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("跳到某一天"))
            .accessibilityIdentifier("today.header")
            if let relative {
                Text(relative).font(Web.section).foregroundStyle(Web.fgTertiary)
            } else {
                Button("回到今天") { withAnimation(Web.panel) { model.show(model.today) } }
                    .font(Web.bodyMedium).foregroundStyle(Web.accent)
            }
        }
    }
}

/// 一天的内容：总结、还在整理的、时间轴、卡片；什么都没有时一句话说明
private struct CanvasBody: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let day = model.day
        let entries = day.entries
        let progress = progressLine(day.notes)
        VStack(alignment: .leading, spacing: 0) {
            if entries.isEmpty && day.notes.isEmpty {
                Text(emptyText).font(Web.body).foregroundStyle(Web.fgTertiary).lineSpacing(Web.bodyLineSpacing)
            } else {
                if let summary = day.summary {
                    Text(summary).font(Web.body).foregroundStyle(Web.fgSecondary).lineSpacing(Web.bodyLineSpacing)
                        .accessibilityIdentifier("today.summary")
                }
                if let progress {
                    Button {
                        withAnimation(Web.panel) { model.chatOpen = true }
                    } label: {
                        Label(progress, systemImage: "circle").labelStyle(QuietLabel())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Web.space1)
                }
                if entries.isEmpty && progress == nil {
                    Text("说过的话里没有整理出记录。").font(Web.body).foregroundStyle(Web.fgTertiary)
                }
                TimelineStrip(day: day.day, entries: entries, categories: day.categories)
                DayCards(entries: entries, categories: day.categories, notes: day.notes)
            }
        }
    }

    private var emptyText: String {
        let offset = PourDate.diffDays(model.shownDay, model.today)
        if offset == 0 { return "今天还是空白。说说你做了什么，这里会自己长出来。" }
        return offset > 0 ? "这一天还没到。" : "这一天没有留下记录。"
    }

    /// 还在整理、等着、没整理成的话：一行安静的字，点一下打开对话
    private func progressLine(_ notes: [Note]) -> String? {
        let organizing = notes.filter { $0.status == .organizing }.count
        let waiting = notes.filter { $0.status == .queued || $0.status == .waitingForNetwork }.count
        let failed = notes.filter { $0.status == .failed }.count
        let parts = [
            organizing > 0 ? "正在整理…" : nil,
            waiting > 0 ? "\(waiting) 段等待整理" : nil,
            failed > 0 ? "\(failed) 段处理失败" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 网页版的 quiet-link：小图标 + 次要文字，至少 44 点高
struct QuietLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Web.space1) {
            configuration.icon.font(Web.caption)
            configuration.title.font(Web.body)
        }
        .foregroundStyle(Web.fgSecondary)
        .frame(minHeight: Web.touch)
    }
}

/// 点日期：选一天看（不能选还没到的日子）
private struct DayPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            DatePicker("哪一天", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding(.horizontal, Web.space4)
                .navigationTitle("跳到某一天")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("好") {
                            model.show(PourDate.logicalDay(date, in: .current))
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
        .tint(Web.accent)
    }
}
