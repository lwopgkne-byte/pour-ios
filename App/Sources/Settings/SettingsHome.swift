import PourAPI
import PourDesign
import PourPlatform
import SwiftUI

/// 设置首页（照可交互原型「设置」；3.0 第 10 步是一组一行、点进去才看得到）：常用的开关和现在的值放在第一层——
/// 提醒和通知（每日回顾、晚上问一句、预警、周报和月报直接开关，推送渠道那些点进去）、记录（类别几个、你的说法几个、
/// 几点以前算前一天）、隐私和数据（打开钱要面容 ID、健康和日历接上没有、用的是哪一份数据）、AI（用哪个、这个月花了多少、
/// 整理得准不准）、连接（电脑上的 Pour）、关于（版本、小组件和捷径）。点一行推进那一页（「/settings#reminders」）
struct SettingsHome: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyLock.key) private var moneyLock = false
    @AppStorage(MoodEvening.key) private var asking = false
    @AppStorage(MoodEvening.mergedKey) private var merged = false
    @State private var reminders: API.ReminderStatus?
    @State private var llm: API.LlmStatus?
    @State private var accuracy: Double?
    @State private var data: API.DataStatus?
    @State private var categories: Int?
    @State private var sayings: Int?

    var body: some View {
        List {
            Section {
                remindersRows
            } header: {
                header("提醒和通知")
            }
            Section {
                row(.categories, color: "green", value: categories.map { "\($0) 个" })
                row(.sayings, color: "brown", value: sayings.map { "\($0) 个" })
                row(
                    .data, title: "几点以前算前一天", symbol: "clock.fill", color: "blue",
                    value: data.map { Self.boundary($0.dayBoundary) }, id: "boundary")
            } header: {
                header("记录")
            }
            Section {
                toggle("打开钱要面容 ID", symbol: "eye.fill", color: "brown", isOn: moneyLock) { moneyLock = $0 }
                    .disabled(!MoneyLock.available)
                row(.health, title: "健康、日历", value: links)
                row(
                    .data, sub: "备份、导出、演示数据、重新解析、画布样张",
                    value: data.map { $0.mode == "demo" ? "正在用演示数据" : "真实数据" })
            } header: {
                header("隐私和数据")
            }
            Section {
                modelRow
                row(.llm, color: "green", value: llm.map { "这个月 ¥\(String(format: "%.1f", $0.usage.costCny))" })
                row(.eval, color: "purple", value: accuracy.map { "\(EvalNames.pct($0)) 正确" })
            } header: {
                header("AI")
            }
            Section {
                row(.phone, value: model.offline == nil ? "已连上" : "没连上")
            } header: {
                header("连接")
            }
            Section {
                row(.about, value: aboutValue)
                row(.widgets)
            } header: {
                header("关于")
            } footer: {
                Text("密钥、PIN、导入、设备管理在电脑上的「Pour 设置」里改（只认电脑本机）。")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListRowHeight, Theme.Size.touch)
        .scrollContentBackground(.hidden)
        .task(id: model.dataVersion) { await load() }
    }

    // MARK: - 提醒和通知

    @ViewBuilder private var remindersRows: some View {
        let morning = reminders?.morning
        toggle(
            "每日回顾", symbol: "book.fill", color: "blue",
            sub: morning.map { "早上 \($0.time) 把昨天整理成一页" }, isOn: morning?.enabled ?? false
        ) { value in
            if let morning { save(["morning": .object(["enabled": .bool(value), "time": .string(morning.time)])]) }
        }
        toggle(
            "晚上问一句", symbol: "face.smiling.inverse", color: "pink",
            sub: "\(MoodEvening.time) · 今天没说过话问过得怎样，没说心情问心情", isOn: asking
        ) { setEvening($0) }
        let warning = reminders?.warning
        toggle(
            "预警", symbol: "exclamationmark.triangle.fill", color: "orange", sub: "目标落后、状态变差",
            isOn: warning?.enabled ?? false
        ) { value in
            if let warning { save(["warning": .object(["enabled": .bool(value), "time": .string(warning.time)])]) }
        }
        let reports = (reminders?.weekly.enabled ?? false) && (reminders?.monthly.enabled ?? false)
        toggle("周报和月报", symbol: "chart.line.uptrend.xyaxis", color: "purple", isOn: reports) { value in
            save(["weekly": .object(["enabled": .bool(value)]), "monthly": .object(["enabled": .bool(value)])])
        }
        row(.reminders, title: "推送渠道、免打扰、入睡时间、试一下", symbol: "slider.horizontal.3", color: "gray")
    }

    /// 晚上问一句（只记在这台手机上）：打开时把电脑那边的倾倒提醒合进来（关掉它），关了再恢复；和「提醒和通知」里那一行一样
    private func setEvening(_ value: Bool) {
        asking = value
        if let evening = reminders?.evening {
            if value, evening.enabled {
                merged = true
                save(["evening": .object(["enabled": .bool(false), "time": .string(evening.time)])])
            } else if !value, merged {
                merged = false
                save(["evening": .object(["enabled": .bool(true), "time": .string(evening.time)])])
            }
        }
        Task { await model.syncEveningMood() }
    }

    private func save(_ patch: [String: JSONValue]) {
        let client = model.client
        Task {
            do {
                reminders = try await client.saveReminders(patch)
            } catch {
                model.toast(error.readable)
            }
        }
    }

    // MARK: - AI

    /// 用哪个：便宜（flash）还是最强（pro）；用的是别的（.env 里写的）只写名字
    @ViewBuilder private var modelRow: some View {
        HStack(spacing: Theme.Space.medium) {
            icon("brain.head.profile.fill", color: "blue")
            Text("用哪个").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            Spacer(minLength: Theme.Space.small)
            if let llm {
                if Self.models.contains(where: { $0.key == llm.model }) {
                    ThemeSegmented("用哪个模型", options: Self.models, selected: llm.model) { choose($0) }
                        .fixedSize()
                } else {
                    Text(llm.model).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
        }
        .frame(minHeight: Theme.Size.touch)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
    }

    // 和「大模型和用量」里一样的说法（「pro · 最强」说的是模型，文案检查认这一句）
    private static let models = [
        (key: "deepseek-flash", label: "flash · 便宜"), (key: "deepseek-v4-pro", label: "pro · 最强"),
    ]

    private func choose(_ name: String) {
        guard name != llm?.model else { return }
        let client = model.client
        Task {
            do {
                try await client.llmSettings(["model": .string(name)])
                llm = try await client.llmStatus()
                model.toast("已换成 \(Self.models.first { $0.key == name }?.label ?? name)，下一段话开始生效")
            } catch {
                model.toast(error.readable)
            }
        }
    }

    // MARK: - 一行

    private func header(_ title: String) -> some View {
        Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
    }

    /// 左边彩色小方块里的白图标（原型 30 点、圆角 8）
    private func icon(_ symbol: String, color: String) -> some View {
        Image(systemName: symbol).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.onAccent)
            .frame(width: Theme.Size.tile + Theme.Space.hairline, height: Theme.Size.tile + Theme.Space.hairline)
            .background(Theme.tag(color).solid, in: Theme.rounded(Theme.Corner.tile))
            .accessibilityHidden(true)
    }

    /// 点进去的一行：图标、名字（下面可以有一句）、右边现在的值、›
    private func row(
        _ page: SettingsPageKey, title: String? = nil, symbol: String? = nil, color: String? = nil, sub: String? = nil,
        value: String? = nil, id: String? = nil
    ) -> some View {
        Button {
            model.open(page.path)
        } label: {
            HStack(spacing: Theme.Space.medium) {
                icon(symbol ?? page.symbol, color: color ?? page.color)
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(title ?? page.title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    if let sub {
                        Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                Spacer(minLength: Theme.Space.small)
                if let value {
                    Text(value).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                        .multilineTextAlignment(.trailing)
                }
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .padding(.vertical, sub == nil ? 0 : Theme.Space.small)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
        .accessibilityIdentifier("settings.row.\(id ?? page.rawValue)")
    }

    /// 直接开关的一行：图标、名字（下面一句说明）、开关
    private func toggle(
        _ title: String, symbol: String, color: String, sub: String? = nil, isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: Theme.Space.medium) {
            icon(symbol, color: color)
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                if let sub {
                    Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: Theme.Space.small)
            ThemeSwitch(title, isOn: isOn, onChange: onChange).tint(Theme.Palette.switchOn)
        }
        .padding(.vertical, sub == nil ? 0 : Theme.Space.small)
        .frame(minHeight: Theme.Size.touch)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
    }

    // MARK: - 值

    /// 健康和日历接上没有
    private var links: String {
        let health = UserDefaults.standard.bool(forKey: HealthLink.connectedKey)
        let calendar = UserDefaults.standard.bool(forKey: CalendarLink.connectedKey)
        switch (health, calendar) {
        case (true, true): return "都接上了"
        case (true, false): return "接上了健康"
        case (false, true): return "接上了日历"
        default: return "还没接上"
        }
    }

    /// 「3.0.1 · 服务器 2.20.0」
    private var aboutValue: String {
        let app = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard let server = model.serverVersion?.server else { return app }
        return "\(app) · 服务器 \(server)"
    }

    /// 240 →「凌晨 4:00」
    static func boundary(_ minutes: Int) -> String {
        "凌晨 \(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    /// 一样一样拿，拿不到的那一样先不写值（不挡别的）
    private func load() async {
        let client = model.client
        reminders = try? await client.reminders()
        llm = try? await client.llmStatus()
        data = try? await client.dataStatus()
        categories = (try? await client.categoriesPage())?.categories.count
        accuracy = (try? await client.evals())?.runs.first?.overall
        sayings = (try? await client.known())?.sayings.count
    }
}
