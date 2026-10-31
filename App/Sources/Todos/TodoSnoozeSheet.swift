import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 推迟到（06 交互细节 2.2）：五个选项，后面写好具体时间——1 小时后（17:10）、今晚（20:00）、明天早上（09:00）、
/// 这个周六（10:00）、下周一（09:00）；「选别的时间」用系统的日子和时间。点了马上挪过去，轻提示能撤销
struct TodoSnoozeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let row: API.TodoRow
    @State private var picking = false
    @State private var custom = Date().addingTimeInterval(3600)

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("推迟到") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    Text(row.content).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                        .padding(.horizontal, Theme.Space.tight)
                    VStack(spacing: 0) {
                        ForEach(SnoozePreset.allCases, id: \.self) { preset in
                            if preset != SnoozePreset.allCases.first {
                                Divider().padding(.leading, Theme.Size.touch + Theme.Space.regular)
                            }
                            option(preset)
                        }
                    }
                    .themeCard(padding: 0)
                    otherTime
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.xLarge)
            }
        }
        .background(Theme.Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func option(_ preset: SnoozePreset) -> some View {
        let target = preset.target(now: Date(), today: model.today)
        return Button {
            model.snooze(row.id, to: preset)
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: preset.symbol).font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.warn)
                    .frame(width: Theme.Size.tile)
                    .accessibilityHidden(true)
                Text(title(preset)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Text(detail(preset, target)).font(Theme.Typeface.subheadline).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.regular)
            .frame(minHeight: Theme.Size.touch + Theme.Space.small)
            .contentShape(Rectangle())
            // 读屏一行念一句「明天早上，09:00」
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("snooze.\(preset.rawValue)")
    }

    /// 周六、周日说「这个周六」推到的是下周六：写「下周六」
    private func title(_ preset: SnoozePreset) -> String {
        preset == .saturday && PourDate.weekdayMon0(model.today) >= 5 ? "下周六" : preset.title
    }

    /// 后面写的具体时间：今天、明天的只写钟点；周六、下周一写上日子
    private func detail(_ preset: SnoozePreset, _ target: (day: String, time: String)) -> String {
        switch preset {
        case .hour, .tonight, .tomorrow:
            target.day == model.today || preset == .tomorrow ? target.time : "明天 \(target.time)"
        case .saturday, .monday: "\(Show.monthDay(target.day)) \(target.time)"
        }
    }

    @ViewBuilder private var otherTime: some View {
        Button {
            withAnimation(Theme.Motion.standard) { picking.toggle() }
        } label: {
            Label("选别的时间", systemImage: "clock")
                .font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.accent)
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("snooze.other")
        if picking {
            VStack(spacing: Theme.Space.medium) {
                DatePicker("推迟到", selection: $custom, in: Date()...)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button {
                    let local = PourDate.localDateTime(custom, in: .current)
                    model.snooze(row.id, day: String(local.prefix(10)), time: String(local.suffix(5)))
                } label: {
                    Text("推迟到这时候").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.composer - Theme.Space.small)
                        .background(Theme.Palette.accentFill, in: Theme.rounded(Theme.Corner.hubTile))
                }
                .buttonStyle(PressScale())
            }
            .themeCard()
        }
    }
}
