import PourAPI
import PourDesign
import PourPlatform
import SwiftUI

/// 设置（3.0 第 10 步，docs/3.0/01-需求文档.md 第 13 章）：系统设置那样的分组列表，左边彩色小图标，第一屏能看到全部分组；
/// 点一行推进那一页（「/settings#reminders」）。以前的链接「/settings#data」「#health」「#privacy」直接打开那一页
struct SettingsPage: View {
    @Environment(AppModel.self) private var model
    /// 哪一页；nil 是分组列表
    let anchor: String?

    var body: some View {
        if let anchor, let page = SettingsPageKey(rawValue: anchor) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) { page.content }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, Theme.Space.small)
                    .padding(.bottom, Theme.Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(SettingsPageKey.groups, id: \.title) { group in
                Section {
                    ForEach(group.rows, id: \.self) { row in settingsRow(row) }
                } header: {
                    header(group.title)
                }
            }
            Section {
                settingsRow(.eval)
                settingsRow(.widgets)
            } header: {
                header("关于 Pour")
            } footer: {
                Text(
                    ["App \(model.appVersionText)", model.serverVersionText.map { "电脑上的 Pour \($0)" }].compactMap { $0 }
                        .joined(separator: " · ")
                )
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .listStyle(.insetGrouped)
        // 第一屏要看得到全部分组（01 需求文档第 13 章）
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListRowHeight, Theme.Size.touch)
        .scrollContentBackground(.hidden)
    }

    /// 组名：系统默认的灰在这个底上不够清楚（审计量过），用主题的第二层字色
    private func header(_ title: String) -> some View {
        Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
    }

    private func settingsRow(_ row: SettingsPageKey) -> some View {
        Button {
            model.open(row.path)
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: row.symbol).font(Theme.Typeface.footnoteSemibold).foregroundStyle(
                    Theme.Palette.onAccent
                )
                .frame(width: Theme.Size.tile, height: Theme.Size.tile)
                .background(
                    Theme.tag(row.color).solid,
                    in: RoundedRectangle(cornerRadius: Theme.Corner.tile, style: .continuous))
                Text(row.title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
        .accessibilityIdentifier("settings.row.\(row.rawValue)")
    }
}

/// 设置的一页：名字、图标、颜色、里面放什么
enum SettingsPageKey: String, CaseIterable {
    case reminders, categories, sayings, privacy, health, calendar, data, llm, phone, lan, eval, widgets

    /// 分组（关于 Pour 单独写：上面还有版本）
    static let groups: [(title: String, rows: [SettingsPageKey])] = [
        ("提醒和通知", [.reminders]), ("记录", [.categories, .sayings]),
        ("隐私和数据", [.privacy, .health, .data]), ("AI 和用量", [.llm]), ("这台手机", [.phone]),
    ]

    var path: String { self == .sayings ? "/about/known#sayings" : "/settings#\(rawValue)" }

    var title: String {
        switch self {
        case .reminders: "提醒和通知"
        case .categories: "类别"
        case .sayings: "你的说法"
        case .privacy: "隐私"
        case .health: "健康和日历"
        case .calendar: "日历"
        case .data: "数据"
        case .llm: "大模型和用量"
        case .phone: "电脑上的 Pour"
        case .lan: "局域网访问"
        case .eval: "AI 表现"
        case .widgets: "小组件和捷径"
        }
    }

    var symbol: String {
        switch self {
        case .reminders: "bell.fill"
        case .categories: "square.grid.2x2.fill"
        case .sayings: "text.bubble.fill"
        case .privacy: "lock.fill"
        case .health: "heart.fill"
        case .calendar: "calendar"
        case .data: "externaldrive.fill"
        case .llm: "sparkles"
        case .phone: "desktopcomputer"
        case .lan: "wifi"
        case .eval: "checkmark.seal.fill"
        case .widgets: "square.on.square"
        }
    }

    var color: String {
        switch self {
        case .reminders, .health: "red"
        case .categories, .eval: "orange"
        case .sayings, .llm: "purple"
        case .privacy, .data: "gray"
        case .calendar, .phone, .lan: "blue"
        case .widgets: "green"
        }
    }

    @MainActor @ViewBuilder var content: some View {
        switch self {
        case .reminders: ReminderSettings()
        case .categories: CategorySettings()
        case .sayings: EmptyView()
        case .privacy: PrivacySettings()
        case .health:
            HealthSettings()
            CalendarSettings()
        case .calendar: CalendarSettings()
        case .data: DataSettings()
        case .llm: LlmSettings()
        case .phone:
            PhoneSettings()
            LanSettings()
        case .lan: LanSettings()
        case .eval: EvalSettings()
        case .widgets: WidgetsGuide()
        }
    }
}

/// 隐私（只管这台手机）：打开钱要面容 ID（01 需求文档 5.6）。遮住金额在钱页右上角的眼睛
struct PrivacySettings: View {
    @AppStorage(MoneyLock.key) private var moneyLock = false

    var body: some View {
        SettingRow(
            label: "打开钱要面容 ID",
            hint: MoneyLock.available ? "只在这台手机上验；App 退到后台再回来要重新验" : "这台手机没设密码，开了也锁不上"
        ) {
            Toggle("打开钱要面容 ID", isOn: $moneyLock).labelsHidden().tint(Theme.Palette.accentFill)
                .accessibilityIdentifier("settings.moneyLock")
        }
    }
}

/// 这台手机连的是哪台电脑上的 Pour（只有手机上有）：地址、连上没有、版本（要输 PIN 时整个 App 先显示 PinGate）
struct PhoneSettings: View {
    @Environment(AppModel.self) private var model
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "电脑上的 Pour", hint: "手机和电脑在同一个 WiFi 时，用这个地址连") {
                InlineEdit(
                    label: "电脑上的 Pour 的地址", value: ServerConfiguration.address.absoluteString,
                    keyboard: .URL, validate: Self.checkAddress,
                    onSave: { text in
                        guard let url = URL(string: text.trimmingCharacters(in: .whitespaces)) else { return }
                        ServerConfiguration.remember(address: url)
                        saved = true
                    })
            }
            if saved { FieldMessage(text: "下次打开 App 时用新的地址。") }
            SettingRow(label: "连接") {
                if let offline = model.offline {
                    Text(offline).foregroundStyle(Web.danger)
                } else {
                    Text("已连上")
                }
            }
            SettingRow(label: "版本") { Text(AppVersion.current.displayText) }
            // 电脑上的 Pour 是哪个版本（docs/模块/产品优化.md R8）
            if let server = model.serverVersionText { SettingRow(label: "电脑上的 Pour") { Text(server) } }
        }
    }

    private static func checkAddress(_ text: String) -> String? {
        URL(string: text.trimmingCharacters(in: .whitespaces))?.host == nil ? "地址写成 http://电脑的名字.local:5188 这样" : nil
    }
}

/// 这一版的版本号和构建号（构建号由 scripts/install-device.sh 按提交数写入）
struct AppVersion: Equatable {
    let marketing: String
    let build: String

    static var current: AppVersion {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppVersion(
            marketing: info["CFBundleShortVersionString"] as? String ?? "0",
            build: info["CFBundleVersion"] as? String ?? "0")
    }

    var displayText: String {
        String(localized: "版本 \(marketing) · 构建 \(build)", comment: "设置里的版本号，例如「版本 0.1.0 · 构建 12」")
    }
}
