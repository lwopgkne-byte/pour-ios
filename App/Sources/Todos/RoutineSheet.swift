import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 作息（待办的时间线，产品主人 2026-11-06）：每天差不多的几段时间。一段一行，点开就地改名字、上班还是忙着、
/// 几点到几点（跨过半夜也行）、哪几天，删掉；下面一排常见的点一下加上；「保存」整份存到服务器。没存就关先问一句
struct RoutineSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var blocks: [API.RoutineBlock]
    /// 点开在改的那一段
    @State private var open: UUID?
    @State private var leaving = false
    private let original: [API.RoutineBlock]

    init(routine: API.Routine?) {
        let blocks = routine?.blocks ?? []
        original = blocks
        _blocks = State(initialValue: blocks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                header
                if !blocks.isEmpty { list }
                if blocks.count < 8 { presets }
                saveButton
            }
            .padding(.horizontal, Theme.Space.regular)
            .padding(.top, Theme.Space.large)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("不保存这次的改动？", isPresented: $leaving, titleVisibility: .visible) {
            Button("不保存", role: .destructive) { dismiss() }
            Button("保存") { save() }
            Button("继续改", role: .cancel) {}
        }
        .themeSelectionFeedback(trigger: open)
    }

    private var dirty: Bool { blocks != original }

    /// 名字都写了、开始和结束不一样，才能存
    private var valid: Bool {
        blocks.allSatisfy { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.from != $0.to }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .top) {
                Text("作息").font(Theme.Typeface.editTitle).foregroundStyle(Theme.Palette.label)
                Spacer()
                SheetCloseButton {
                    if dirty { leaving = true } else { dismiss() }
                }
            }
            Text("每天差不多的几段时间。时间线上画成淡淡的底色，睡觉的那段收起来；空档不往睡觉、忙着的时间里排，上班的时候照样找。")
                .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 一段一行

    private var list: some View {
        VStack(spacing: 0) {
            ForEach($blocks) { $block in
                VStack(alignment: .leading, spacing: 0) {
                    row(block)
                    if open == block.id { RoutineEditor(block: $block) { remove(block.id) } }
                }
                if block.id != blocks.last?.id { Divider().padding(.leading, Theme.Space.regular) }
            }
        }
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("routine.list")
    }

    private func row(_ block: API.RoutineBlock) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) { open = open == block.id ? nil : block.id }
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: RoutineBand.symbol(title: block.title, kind: RoutineText.kind(block.sort)))
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(width: Theme.Size.badge + Theme.Space.small)
                // 名字一行、几点到几点 · 哪几天一行：字大了也不截
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(block.title.isEmpty ? "还没起名字" : block.title).font(Theme.Typeface.body)
                        .foregroundStyle(block.title.isEmpty ? Theme.Palette.tertiaryLabel : Theme.Palette.label)
                    Text("\(block.from)–\(block.to) · \(RoutineText.days(block.days))").font(Theme.Typeface.subheadline)
                        .monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Space.small)
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
                    .rotationEffect(.degrees(open == block.id ? 90 : 0))
            }
            .padding(.vertical, Theme.Space.small)
            .padding(.horizontal, Theme.Space.regular)
            .frame(minHeight: Theme.Size.touch + Theme.Space.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("routine.row")
    }

    // MARK: - 加一段、保存

    /// 常见的几段（睡觉已经有了就不再给）；「自己写」加一段空名字的，点开写
    private var presets: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("加一段").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
            ChipFlow {
                ForEach(available) { preset in
                    EditChip(preset.title, symbol: "plus", selected: false) { add(preset) }.fixedSize()
                }
                EditChip("自己写", symbol: "plus", selected: false) {
                    add(
                        API.RoutineBlock(title: "", kind: .busy, from: "10:00", to: "11:00", days: RoutineText.everyDay)
                    )
                }
                .fixedSize()
                .accessibilityIdentifier("routine.custom")
            }
        }
    }

    /// 还没加的常见的几段
    private var available: [API.RoutineBlock] {
        RoutineText.presets.filter { preset in !blocks.contains { $0.title == preset.title } }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("保存").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.composer - Theme.Space.tight)
                .background(Theme.Palette.accentFill.opacity(valid ? 1 : 0.4), in: Theme.rounded(Theme.Corner.stat))
        }
        .buttonStyle(PressScale())
        .disabled(!valid)
        .padding(.top, Theme.Space.small)
        .accessibilityIdentifier("routine.save")
    }

    private func add(_ preset: API.RoutineBlock) {
        var block = preset
        block.id = UUID()
        withAnimation(Theme.Motion.standard) {
            blocks.append(block)
            open = block.id
        }
    }

    private func remove(_ id: UUID) {
        withAnimation(Theme.Motion.standard) {
            blocks.removeAll { $0.id == id }
            open = nil
        }
    }

    private func save() {
        guard valid else { return }
        let tidy = blocks.map { block in
            var block = block
            block.title = String(block.title.trimmingCharacters(in: .whitespaces).prefix(8))
            return block
        }
        model.saveRoutine(tidy)
        dismiss()
    }
}

/// 点开的一段：名字、上班还是忙着（睡觉不用选）、从几点到几点、哪几天、删掉
private struct RoutineEditor: View {
    @Binding var block: API.RoutineBlock
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            TextField("名字（最多 8 个字）", text: $block.title).font(Theme.Typeface.body)
                .padding(.horizontal, Theme.Space.medium)
                .frame(minHeight: Theme.Size.touch)
                .background(Theme.Palette.fill, in: Theme.rounded(Theme.Corner.choice))
                .accessibilityIdentifier("routine.title")
            if block.sort != .sleep {
                Picker("这段时间", selection: $block.kind) {
                    Text("上班、上学 · 照样排事").tag(API.RoutineBlock.Kind.work.rawValue)
                    Text("忙着 · 不往里排").tag(API.RoutineBlock.Kind.busy.rawValue)
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: Theme.Space.small) {
                Text("从").foregroundStyle(Theme.Palette.secondaryLabel)
                clockPicker($block.from, label: "开始")
                Text("到").foregroundStyle(Theme.Palette.secondaryLabel)
                clockPicker($block.to, label: "结束")
                Spacer(minLength: 0)
            }
            .font(Theme.Typeface.body)
            days
            ThemeTextButton("删掉这一段", font: Theme.Typeface.subheadline, color: Theme.Palette.bad, action: remove)
                .accessibilityIdentifier("routine.remove")
        }
        .padding(.horizontal, Theme.Space.regular)
        .padding(.bottom, Theme.Space.medium)
    }

    /// 哪几天：每天、工作日、周末，下面一周七天一个个点（至少留一天）
    private var days: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ChipFlow {
                ForEach([RoutineText.everyDay, RoutineText.workdays, RoutineText.weekend], id: \.self) { set in
                    EditChip(RoutineText.days(set), selected: Set(block.days) == Set(set)) { block.days = set }
                        .fixedSize()
                }
            }
            HStack(spacing: Theme.Space.tight) {
                ForEach(0..<7, id: \.self) { day in
                    let isOn = block.days.contains(day)
                    Button {
                        if isOn, block.days.count > 1 {
                            block.days.removeAll { $0 == day }
                        } else if !isOn {
                            block.days = (block.days + [day]).sorted()
                        }
                    } label: {
                        Text(RoutineText.dayName(day)).font(Theme.Typeface.subheadline)
                            .foregroundStyle(isOn ? Theme.Palette.onAccent : Theme.Palette.label)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                            .background(isOn ? Theme.Palette.label : Theme.Palette.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("周\(RoutineText.dayName(day))"))
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    /// 钟点（「23:30」）和系统的时间选择互转
    private func clockPicker(_ clock: Binding<String>, label: String) -> some View {
        DatePicker(
            label,
            selection: Binding(
                get: { Self.date(clock.wrappedValue) },
                set: { clock.wrappedValue = Self.clock($0) }),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .tint(Theme.Palette.accentFill)
    }

    private static func date(_ clock: String) -> Date {
        let minute = TodoTimelinePlan.minute(clock) ?? 0
        return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    private static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

extension View {
    /// 作息弹框（时间线上那一行「作息」、右上角「···」里点了打开）
    func routineSheet(_ model: AppModel) -> some View {
        sheet(
            isPresented: Binding(get: { model.timeline.editing }, set: { model.timeline.editing = $0 })
        ) {
            RoutineSheet(routine: model.timeline.routine).environment(model)
        }
    }
}
