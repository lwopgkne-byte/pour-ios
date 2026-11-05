import PourAPI
import PourDesign
import PourPlatform
import SwiftUI

/// 设置（3.0 第 10 步，docs/3.0/01-需求文档.md 第 13 章；3.0.1 首页照原型：SettingsHome）：系统设置那样的分组列表，
/// 左边彩色小图标；点一行推进那一页（「/settings#reminders」）。以前的链接「/settings#data」「#health」「#privacy」直接打开那一页
struct SettingsPage: View {
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
            SettingsHome()
        }
    }
}

/// 设置的一页：名字、图标、颜色、里面放什么
enum SettingsPageKey: String, CaseIterable {
    case reminders, categories, sayings, privacy, health, calendar, data, llm, phone, lan, eval, widgets, about

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
        case .about: "关于 Pour"
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
        case .about: "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .reminders, .health: "red"
        case .categories, .eval: "orange"
        case .sayings, .llm: "purple"
        case .privacy, .data: "gray"
        case .calendar, .phone, .lan, .about: "blue"
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
        case .about: AboutPourSettings()
        }
    }
}

/// 关于 Pour（照原型「关于 Pour」；「我的」最下面一行进来）：小组件和捷径、AI 表现点进去；版本；隐私一句话；致谢（用到的图标的许可）
struct AboutPourSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            link(.widgets, hint: "桌面、锁屏、控制中心、通知、分享、Siri")
            link(.eval, hint: "整理得准不准、你改过的地方、自动检查")
            SettingRow(label: "版本") {
                Text(
                    ["App \(model.appVersionText)", model.serverVersionText.map { "电脑上的 Pour \($0)" }].compactMap { $0 }
                        .joined(separator: " · ")
                )
                .font(Theme.Typeface.footnote)
            }
            SettingRow(label: "隐私", hint: "原话和整理结果都在你的电脑上；发给大模型的只有要整理的那段话") { EmptyView() }
            SettingRow(label: "致谢", hint: "心情的五个表情来自 Google Material Symbols（Apache License 2.0）") { EmptyView() }
        }
        .settingsCard()
    }

    private func link(_ page: SettingsPageKey, hint: String) -> some View {
        Button {
            model.open(page.path)
        } label: {
            SettingRow(label: page.title, hint: hint) {
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.about.\(page.rawValue)")
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
            Toggle("打开钱要面容 ID", isOn: $moneyLock).labelsHidden().tint(Theme.Palette.switchOn)
                .accessibilityIdentifier("settings.moneyLock")
        }
        .settingsCard()
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
                    Text(offline).foregroundStyle(Theme.Palette.bad)
                } else {
                    Text("已连上")
                }
            }
            SettingRow(label: "版本") { Text(AppVersion.current.displayText) }
            // 电脑上的 Pour 是哪个版本（docs/模块/产品优化.md R8）
            if let server = model.serverVersionText { SettingRow(label: "电脑上的 Pour") { Text(server) } }
        }
        .settingsCard()
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
