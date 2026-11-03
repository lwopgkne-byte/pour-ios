import PourAPI
import PourDesign
import SwiftUI

/// 一个目标页下面几块：最近推进它的（原话，每一条能点开那条记录）、推进的日子和心情、设置（名称和目标值原地改）

/// 最近推进它的：一句一行的原话（宋体）、日子和早上 / 晚上、右边「+8.4 公里」；超过 4 条「全部 9 条」
struct GoalRecentBlock: View {
    @Environment(AppModel.self) private var model
    let page: API.GoalPage
    @State private var all = false

    var body: some View {
        if page.days == nil {
            GoalSection(title: "最近推进它的", meta: page.recentTotal > 0 ? "一共 \(page.recentTotal) 条 · 你说的原话" : nil)
            if page.recent.isEmpty {
                Text("还没有。说一句就会算进来，比如「\(Self.example(page.card.title))」。")
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                        horizontal: false, vertical: true
                    )
                    .themeCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(shown) { item in
                        if item.id != shown.first?.id { Divider() }
                        row(item)
                    }
                    if page.recent.count > 4 {
                        Divider()
                        LinkButton(
                            all ? "收起" : "全部 \(page.recent.count) 条", font: Theme.Typeface.subheadline,
                            identifier: "goal.recent.all"
                        ) {
                            withAnimation(Theme.Motion.standard) { all.toggle() }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Theme.Space.inset)
                .themeCard(padding: 0)
            }
        }
    }

    private var shown: [API.GoalPage.Recent] { all ? page.recent : Array(page.recent.prefix(4)) }

    /// 「每周游泳 1 次」→「游泳 1 次」
    static func example(_ title: String) -> String {
        title.replacingOccurrences(of: "每周", with: "").replacingOccurrences(of: "每月", with: "")
    }

    private func row(_ item: API.GoalPage.Recent) -> some View {
        Button {
            model.openEntry(item.entryId, day: item.day)
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.medium) {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(item.text).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Text(item.when).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel)
                }
                Spacer()
                if !item.plus.isEmpty {
                    Text(item.plus).font(Theme.Typeface.footnoteSemibold).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel)
                }
                Image(systemName: "chevron.right").font(Theme.Typeface.footnote).foregroundStyle(
                    Theme.Palette.tertiaryLabel)
            }
            .padding(.vertical, Theme.Space.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal.recent.\(item.entryId)")
    }
}

/// 推进的日子和心情（发现卡的样子，只是一起出现）：推进了的日子、别的日子，挺好以上各几天；天数少说还少
struct GoalMoodCard: View {
    let mood: API.GoalPage.Mood

    var body: some View {
        GoalSection(title: "推进的日子和心情")
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text(mood.title).font(Theme.Typeface.bodySemibold).fixedSize(horizontal: false, vertical: true)
            bar("推进了的日子", good: mood.movedGood, of: mood.moved, tint: Theme.Palette.good)
            bar("别的日子", good: mood.otherGood, of: mood.other, tint: Theme.Palette.tertiaryLabel)
            Text("只是一起出现，不一定有关。").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            if let foot = mood.foot {
                Text(foot).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                    horizontal: false, vertical: true)
            }
        }
        .themeCard()
    }

    private func bar(_ name: String, good: Int, of total: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack {
                Text(name).font(Theme.Typeface.footnote)
                Spacer()
                Text("\(total) 天里 \(good) 天").font(Theme.Typeface.footnote).monospacedDigit()
            }
            .foregroundStyle(Theme.Palette.secondaryLabel)
            GeometryReader { geo in
                Capsule().fill(Theme.Palette.fill).overlay(alignment: .leading) {
                    Capsule().fill(tint).frame(width: geo.size.width * (total > 0 ? Double(good) / Double(total) : 0))
                }
            }
            .frame(height: Theme.Size.bar)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 设置：名称、目标值、只算（点了原地改：输入框 +「好」，回车也行）、类别和周期（点了是系统菜单）、
/// 从哪天算（点了弹出系统的日历）、我在乎的（点了换一块）、提醒。服务器 2.19.0 以前类别、只算、周期、从哪天算只能看
struct GoalSettingsBlock: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let page: API.GoalPage
    @State private var care: API.CareSettings?
    @State private var editing: String?
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var settings: API.GoalPage.Settings { page.settings }

    var body: some View {
        GoalSection(title: "设置")
        VStack(spacing: 0) {
            editable("title", "名称", settings.title, number: false)
            if settings.target != nil {
                Divider()
                editable("target", "目标值", settings.targetText, number: true)
            }
            if let category = settings.category { Divider(); categoryRow(category) }
            if settings.edit?.keywords != nil {
                Divider()
                editable("only", "只算", settings.only ?? "整个类别都算", number: false)
            } else if let only = settings.only {
                Divider()
                plain("只算", only)
            }
            Divider()
            periodRow
            Divider()
            startRow
            if page.card.parentId == nil {
                Divider()
                careRow
            }
            if let remind = settings.remind {
                Divider()
                Button {
                    model.goals.sheet = .woop(goalId, step: 2)
                } label: {
                    rowLabel("提醒", remind, chevron: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        .task { care = try? await model.client.care() }
    }

    @ViewBuilder private func editable(_ key: String, _ name: String, _ value: String, number: Bool) -> some View {
        if editing == key {
            HStack(spacing: Theme.Space.small) {
                Text(name).font(Theme.Typeface.body)
                TextField(key == "only" ? "名称里带的字，空格隔开" : name, text: $draft).focused($focused)
                    .multilineTextAlignment(number ? .trailing : .leading)
                    .keyboardType(number ? .decimalPad : .default).submitLabel(.done).onSubmit { save(key) }
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("goal.edit.\(key)")
                if number, let unit = settings.target?.unit {
                    Text(unit).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Button("好") { save(key) }.buttonStyle(.borderedProminent).accessibilityIdentifier("goal.edit.save")
            }
            .frame(minHeight: Theme.Size.touch + Theme.Space.small)
        } else {
            Button {
                draft =
                    switch key {
                    case "target": Show.fmtNum(settings.target?.value ?? 0)
                    case "only": (settings.edit?.keywords ?? []).joined(separator: " ")
                    default: settings.title
                    }
                editing = key
                focused = true
            } label: {
                rowLabel(name, value, chevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("goal.setting.\(key)")
        }
    }

    private func save(_ key: String) {
        editing = nil
        let text = draft.trimmingCharacters(in: .whitespaces)
        if key == "target", let value = Double(text), value > 0, value != settings.target?.value {
            model.goalSet(goalId, GoalChange(target: value))
        } else if key == "title", !text.isEmpty, text != settings.title {
            model.goalSet(goalId, GoalChange(title: text))
        } else if key == "only" {
            // 空着是整个类别都算
            let words = text.split { " ,，、".contains($0) }.map(String.init)
            if words != (settings.edit?.keywords ?? []) { model.goalSet(goalId, GoalChange(keywords: words)) }
        }
    }

    /// 类别：系统菜单，点一类换过去（子类别的记录也算进上级）
    @ViewBuilder private func categoryRow(_ name: String) -> some View {
        let sub = "子类别的记录也算进上级"
        if let current = settings.edit?.category {
            Menu {
                ForEach(CategoryPicker.ordered(model.categories), id: \.key) { item in
                    Button {
                        if item.key != current { model.goalSet(goalId, GoalChange(category: item.key)) }
                    } label: {
                        if item.key == current { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                    }
                }
            } label: {
                rowLabel("类别", name, chevron: true, sub: sub)
            }
            .accessibilityIdentifier("goal.setting.category")
        } else {
            plain("类别", name, sub: sub)
        }
    }

    /// 周期：系统菜单（今年 / 这个月 / 这周 / 每月 / 每周）；每天的、坚持的、大目标不能换
    @ViewBuilder private var periodRow: some View {
        if let periods = settings.edit?.periods, !periods.isEmpty {
            Menu {
                ForEach(periods, id: \.label) { option in
                    Button {
                        if !option.current {
                            model.goalSet(goalId, GoalChange(period: option.period, repeats: option.repeats))
                        }
                    } label: {
                        if option.current { Label(option.label, systemImage: "checkmark") } else { Text(option.label) }
                    }
                }
            } label: {
                rowLabel("周期", settings.period, chevron: true)
            }
            .accessibilityIdentifier("goal.setting.period")
        } else {
            plain("周期", settings.period)
        }
    }

    /// 从哪天算：点了弹出系统的日历，只能选这一段的第一天到今天（有终点的目标）
    @ViewBuilder private var startRow: some View {
        if let start = settings.edit?.start {
            HStack(spacing: Theme.Space.medium) {
                Text("从哪天算").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Spacer(minLength: Theme.Space.small)
                DateEdit(label: "从哪天算", value: start.value, display: settings.start, range: start.from...start.to) {
                    model.goalSet(goalId, GoalChange(start: $0))
                }
                .font(Theme.Typeface.body)
                Image(systemName: "chevron.right").font(Theme.Typeface.footnote).foregroundStyle(
                    Theme.Palette.tertiaryLabel
                )
                .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.Size.touch + Theme.Space.small)
        } else {
            plain("从哪天算", settings.start)
        }
    }

    private var careRow: some View {
        Menu {
            ForEach(care?.areas ?? []) { area in
                Button(area.name) { model.goalSet(goalId, GoalChange(care: .some(area.key))) }
            }
            Button("其他") { model.goalSet(goalId, GoalChange(care: .some(nil))) }
        } label: {
            rowLabel("我在乎的", settings.care?.name ?? "其他", chevron: true)
        }
        .accessibilityIdentifier("goal.setting.care")
    }

    private func plain(_ name: String, _ value: String, sub: String? = nil) -> some View {
        rowLabel(name, value, chevron: false, sub: sub)
    }

    private func rowLabel(_ name: String, _ value: String, chevron: Bool, sub: String? = nil) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.medium) {
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                if let sub { Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel) }
            }
            Spacer(minLength: Theme.Space.small)
            Text(value).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(
                .trailing
            )
            .fixedSize(horizontal: false, vertical: true)
            if chevron {
                Image(systemName: "chevron.right").font(Theme.Typeface.footnote).foregroundStyle(
                    Theme.Palette.tertiaryLabel)
            }
        }
        .frame(minHeight: Theme.Size.touch + Theme.Space.small)
        .contentShape(Rectangle())
    }
}
