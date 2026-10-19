import PourAPI
import PourDesign
import SwiftUI

/// 设置页的一行（网页版 SettingRow）：左边名称（下面可以有一句说明），右边现在的值和操作。
/// 名称至少占 192 点；右边放不下就换到下一行靠右，不压住名称（网页版 flex-wrap）
struct SettingRow<Content: View>: View {
    let label: String
    var hint: String?
    /// 说明读屏念起来不顺时（一个网址）换一种说法
    var spokenHint: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        SettingRowLayout {
            VStack(alignment: .leading, spacing: 0) {
                Text(Show.spaced(label)).font(Web.body).foregroundStyle(Web.fg)
                if let hint, !hint.isEmpty {
                    Text(Show.spaced(hint)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            // 名称和下面那句说明读屏一起念
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text([label, spokenHint ?? hint ?? ""].filter { !$0.isEmpty }.joined(separator: "，")))
            HStack(spacing: Web.space3) { content() }
                .font(Web.body).foregroundStyle(Web.fgSecondary).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Web.space2)
        .frame(minHeight: Web.touch)
        .accessibilityElement(children: .contain)
    }
}

/// 名称和右边的东西排一行还是两行：名称 192 点 + 间距 + 右边要的宽度放得下就一行（垂直居中），放不下右边换行靠右
private struct SettingRowLayout: Layout {
    private let basis = Web.space16 * 3
    private let gap = Web.space4
    private let rowGap = Web.space2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? basis * 2
        let (label, control) = sizes(width: width, subviews: subviews)
        if oneLine(width: width, control: control) {
            return CGSize(width: width, height: max(label.height, control.height))
        }
        return CGSize(width: width, height: label.height + rowGap + control.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let (label, control) = sizes(width: bounds.width, subviews: subviews)
        if oneLine(width: bounds.width, control: control) {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(width: label.width, height: nil))
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                proposal: ProposedViewSize(width: control.width, height: nil))
        } else {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil))
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY + label.height + rowGap), anchor: .topTrailing,
                proposal: ProposedViewSize(width: control.width, height: nil))
        }
    }

    private func oneLine(width: CGFloat, control: CGSize) -> Bool { basis + gap + control.width <= width }

    /// 名称和右边各要多大：右边先按它想要的宽度（最多一整行），名称拿剩下的
    private func sizes(width: CGFloat, subviews: Subviews) -> (CGSize, CGSize) {
        guard subviews.count == 2 else { return (.zero, .zero) }
        let ideal = subviews[1].sizeThatFits(.unspecified)
        let control =
            ideal.width <= width ? ideal : subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let labelWidth = oneLine(width: width, control: control) ? width - gap - control.width : width
        let label = subviews[0].sizeThatFits(ProposedViewSize(width: labelWidth, height: nil))
        return (CGSize(width: labelWidth, height: label.height), control)
    }
}

/// 设置页一大块的标题（网页版 h2：18 号、半粗）
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            Text(title).font(Web.sectionSemibold).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// 一块里面的小标题（网页版 h3：13 号、中粗、次要色）
struct SettingsHeading: View {
    let title: String

    var body: some View {
        Text(title).font(Web.captionMedium).foregroundStyle(Web.fgSecondary)
            .padding(.top, Web.space4).padding(.bottom, Web.space1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 一行下面的小字说明（网页版 field-message）
struct FieldMessage: View {
    let text: String
    var tone: Color = Web.fgTertiary

    var body: some View {
        Text(Show.spaced(text)).font(Web.caption).foregroundStyle(tone)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 浅灰底的一块（网页版 setup-card）：整理建议、确认要不要导入、重新解析的估算
struct SetupBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) { content() }
            .padding(Web.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bgSubtle))
    }
}

/// 还在拿的时候：两条灰条（网页版每一块的 Skeleton）
struct SettingsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            WebSkeleton().containerRelativeFrame(.horizontal) { width, _ in width * 2 / 3 }
            WebSkeleton().containerRelativeFrame(.horizontal) { width, _ in width / 2 }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Web.space3)
    }
}

/// 改时间（网页版 InlineEdit type="time"）：平时是一段能点的字「07:30」；点一下弹出系统的时间滚轮（手机网页上点时间框也是它），
/// 滚完收起就保存
struct TimeEdit: View {
    let label: String
    /// 「07:30」
    let value: String
    /// 平时显示的字（网页版 display：「凌晨 04:00」）；不给就显示 value
    var display: String?
    /// 还没设过（显示的是「不检查」这种灰字）：滚轮动过就算设上（停在 00:00 也算）
    var unset = false
    let onSave: (String) -> Void

    @State private var picking = false
    @State private var chosen = Date()
    /// 滚轮动过没有（打开看一眼就收起不算改）
    @State private var touched = false

    var body: some View {
        Button {
            chosen = Self.date(value)
            touched = false
            picking = true
        } label: {
            Text(display ?? value).foregroundStyle(unset ? Web.fgTertiary : Web.fgSecondary).monospacedDigit()
                .frame(minHeight: Web.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("修改\(label)"))
        .accessibilityValue(Text(display ?? value))
        .popover(isPresented: $picking) {
            DatePicker(label, selection: $chosen, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding(Web.space2)
                .presentationCompactAdaptation(.popover)
                .onChange(of: chosen) { _, _ in touched = true }
                .onDisappear {
                    let clock = Self.clock(chosen)
                    if touched, clock != value || unset { onSave(clock) }
                }
        }
    }

    static func date(_ clock: String) -> Date {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 0
        let minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

/// 设置页每一块都这样拿数据：拿的时候灰条，拿不到说为什么、能重试
struct Loaded<Value: Sendable, Content: View>: View {
    @Environment(AppModel.self) private var model
    let load: @Sendable () async throws(APIError) -> Value
    @ViewBuilder let content: (Value, _ reload: @escaping () -> Void) -> Content

    @State private var value: Value?
    @State private var problem: String?
    @State private var version = 0

    var body: some View {
        Group {
            if let value {
                content(value) { version += 1 }
            } else if let problem {
                WebErrorState(problem) { version += 1 }
            } else {
                SettingsSkeleton()
            }
        }
        // 别处改了设置也重新拿（网页版 settings-changed）
        .task(id: [version, model.settingsVersion]) {
            do {
                value = try await load()
                problem = nil
            } catch {
                problem = error.readable
            }
        }
    }
}

/// 设置页里的数字写法
enum Numbers {
    /// 1234567 →「1,234,567」（网页版 toLocaleString）
    static func grouped(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    /// 花费很少时多保留几位小数，免得显示成 ¥0.00
    static func cny(_ value: Double) -> String {
        if value == 0 { return "¥0" }
        if value < 0.01 { return String(format: "¥%.4f", value) }
        if value < 1 { return String(format: "¥%.3f", value) }
        return String(format: "¥%.2f", value)
    }
}

/// 一行里颜色不一样的几段字（网页版 <span className="text-fg">…</span>）；bold 是前几段用中粗
func spans(_ parts: [(String, Color)], bold: Int = 0) -> AttributedString {
    parts.enumerated().reduce(into: AttributedString()) { text, item in
        var part = AttributedString(Show.spaced(item.element.0))
        part.foregroundColor = item.element.1
        if item.offset < bold { part.font = Web.captionMedium }
        text += part
    }
}

extension Error {
    /// 给人看的一句话：服务器说的，或者连不上（网页版 errorMessage）
    var readable: String { (self as? APIError)?.message ?? APIError.unreachable.message }
}
