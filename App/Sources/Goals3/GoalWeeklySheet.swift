import PourAPI
import PourDesign
import SwiftUI

/// 每周回顾（周日晚上 8 点，docs/3.0/06-交互细节.md 12.8）：三屏——这一周（每个目标一行 + 一个观察）→ 要调一调的（落后的一两个，
/// 各一个办法，点了就改；「细聊」进 GROW）→ 下周最重要的一件（放进待办，看完了）
struct GoalWeeklySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var review: API.WeeklyReview?
    @State private var step = 0
    @State private var changed: Set<Int> = []
    @State private var next: Int?

    private static let names = ["这一周", "要调一调的", "下周最重要的一件"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    if let review { content(review) } else { ProgressView().frame(maxWidth: .infinity) }
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
            .navigationTitle(review?.title ?? "每周回顾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.accessibilityIdentifier("weekly.close")
                }
            }
        }
        .task { review = try? await model.client.goalsWeekly() }
    }

    @ViewBuilder private func content(_ review: API.WeeklyReview) -> some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(0..<3, id: \.self) { index in
                Button {
                    withAnimation(Theme.Motion.standard) { step = index }
                } label: {
                    VStack(spacing: Theme.Space.tight) {
                        Capsule().fill(index <= step ? Theme.Palette.accent : Theme.Palette.fill).frame(
                            height: Theme.Space.tight)
                        Text(Self.names[index]).font(Theme.Typeface.tick).foregroundStyle(
                            index <= step ? Theme.Palette.accent : Theme.Palette.tertiaryLabel)
                    }
                    .frame(minHeight: Theme.Size.touch)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weekly.step.\(index)")
            }
        }
        Text(Self.names[step]).font(Theme.Typeface.largeTitle).accessibilityAddTraits(.isHeader)
        switch step {
        case 0: week(review)
        case 1: adjust(review)
        default: nextWeek(review)
        }
        Text("3 分钟 · 周日晚上 8 点 · 在设置里能改时间、能关").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel).frame(maxWidth: .infinity)
    }

    // MARK: - 这一周

    @ViewBuilder private func week(_ review: API.WeeklyReview) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(review.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider() }
                HStack(spacing: Theme.Space.medium) {
                    Image(systemName: row.done ? "checkmark.circle.fill" : "circle").font(Theme.Typeface.section)
                        .foregroundStyle(row.done ? Theme.Palette.good : Theme.Palette.tertiaryLabel)
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(row.title).font(Theme.Typeface.body)
                        if !row.sub.isEmpty {
                            Text(row.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                    }
                    Spacer()
                    Text(row.value).font(Theme.Typeface.footnoteSemibold).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, Theme.Space.small)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        if let observation = review.observation {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Label("一个观察", systemImage: "sparkles").font(Theme.Typeface.footnoteSemibold).foregroundStyle(
                    Theme.Palette.accent)
                Text(observation.text).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weekly.observation")
                Text(observation.foot).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .themeCard()
        }
        stepButton("下一步") { step = 1 }
    }

    // MARK: - 要调一调的

    @ViewBuilder private func adjust(_ review: API.WeeklyReview) -> some View {
        if review.adjust.isEmpty {
            Text("这周没有落后两周的，不用调。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).themeCard()
        }
        ForEach(review.adjust) { item in
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text(item.title).font(Theme.Typeface.bodySemibold)
                Text(item.why).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.warn).fixedSize(
                    horizontal: false, vertical: true)
                Text("\(item.option.title)：\(item.option.how)").font(Theme.Typeface.subheadline).fixedSize(
                    horizontal: false, vertical: true)
                Text(item.option.when).font(Theme.Typeface.subheadline.weight(.semibold)).foregroundStyle(
                    Theme.Palette.accent)
                if changed.contains(item.id) {
                    Label("改好了", systemImage: "checkmark").font(Theme.Typeface.bodySemibold).foregroundStyle(
                        Theme.Palette.good)
                } else {
                    HStack {
                        Button("就这样改") {
                            changed.insert(item.id)
                            model.applyGrow(
                                item.id, key: item.option.key, restart: true, remind: item.option.remind,
                                ifthen: item.option.ifthen)
                        }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("weekly.apply.\(item.id)")
                        Button("细聊") { model.goals.sheet = .grow(item.id) }.buttonStyle(.bordered)
                    }
                }
            }
            .themeCard()
        }
        stepButton("下一步") { step = 2 }
    }

    // MARK: - 下周最重要的一件

    @ViewBuilder private func nextWeek(_ review: API.WeeklyReview) -> some View {
        ForEach(Array(review.next.enumerated()), id: \.offset) { index, item in
            Button {
                next = index
            } label: {
                HStack(alignment: .top, spacing: Theme.Space.medium) {
                    Image(systemName: next == index ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(next == index ? Theme.Palette.accent : Theme.Palette.tertiaryLabel)
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        Text(item.goal).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        Text(item.text).font(Theme.Typeface.bodySemibold).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .themeCard(padding: Theme.Space.inset)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(next == index ? .isSelected : [])
            .accessibilityIdentifier("weekly.next.\(index)")
        }
        Text(review.nextFoot).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
            horizontal: false, vertical: true)
        stepButton(next == nil ? "看完了" : "放进待办，看完了") {
            if let next, review.next.indices.contains(next) { model.weeklyTodo(review.next[next].todo) }
            Task {
                try? await model.client.weeklySeen(review.from)
                model.dataChanged()
            }
            dismiss()
        }
    }

    private func stepButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) { action() }
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("weekly.button")
    }
}
