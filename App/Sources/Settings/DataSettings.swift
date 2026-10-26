import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 设置页「局域网访问」：手机访问地址、PIN（只能在电脑上用「Pour 设置」改）、记住设备几天
struct LanSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let client = model.client
        Loaded(
            load: { () async throws(APIError) in try await client.lan() },
            content: { info, _ in
                VStack(alignment: .leading, spacing: 0) {
                    SettingRow(label: "手机访问地址") {
                        if let url = info.urls.first {
                            // 读屏念「局域网地址」，网址放在值里（整串网址当名字念不顺）
                            Text(url).lineLimit(1).textSelection(.enabled)
                                .accessibilityLabel(Text("局域网地址"))
                                .accessibilityValue(Text(url))
                        } else {
                            Text("没有检测到局域网，请确认电脑已连上 WiFi")
                        }
                    }
                    SettingRow(label: "PIN") {
                        Text("\(info.pinEnabled ? "已开启" : "未开启") · 在电脑上用「Pour 设置」改")
                    }
                    SettingRow(label: "记住设备") { Text("\(info.rememberDays) 天") }
                }
            })
    }
}

/// 设置页「数据」：日界线、自动备份、导出、重新解析、演示数据。
/// 从备份导入只能在电脑上做（「Pour 设置」），手机上不显示
struct DataSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let client = model.client
        Loaded(
            load: { () async throws(APIError) in try await client.dataStatus() },
            content: { status, reload in
                DataRows(status: status, reload: reload)
            })
    }
}

private struct DataRows: View {
    @Environment(AppModel.self) private var model
    let status: API.DataStatus
    let reload: () -> Void
    @State private var busy: String?
    @State private var exported: ExportedFile?

    private var demo: Bool { status.mode == "demo" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "日界线", hint: "几点以前算前一天（熬夜到凌晨说的话）") {
                let clock = Self.clock(status.dayBoundary)
                TimeEdit(label: "日界线", value: clock, display: "凌晨 \(clock)") { saveBoundary($0) }
            }
            FieldMessage(text: "只影响以后说的话，已经记下的日期不变。")
            if !demo {
                SettingRow(label: "自动备份", hint: "每天一次，放在 backups 文件夹，保留最近 30 份") {
                    Text(backupText)
                    busyButton("backup", title: "立即备份") {
                        try await $0.backup()
                        return "已经备份"
                    }
                }
            }
            SettingRow(label: "导出全部数据", hint: "原话 Markdown + 整理结果 JSON（不含密钥）") {
                if busy == "export" {
                    Dots(label: "正在导出").foregroundStyle(Web.accent)
                } else {
                    WebTextButton("导出") { export() }
                }
            }
            ReparseRows(today: model.today)
            SettingRow(label: "演示数据", hint: "一个人连续 9 周的生活，每个功能都用到，用来看看 Pour 用久了是什么样") {
                if demo {
                    WebTextButton("重新生成") { switchMode("demo", regenerate: true) }
                    WebButton("回到真实数据", variant: .primary, loading: busy == "real") { switchMode("real") }
                } else if busy == "demo" {
                    Dots(label: "正在切换").foregroundStyle(Web.accent)
                } else {
                    WebTextButton("切换到演示数据") { switchMode("demo") }
                }
            }
            FieldMessage(text: "演示数据放在单独的数据库里，你的真实数据不会被改动；演示时不发提醒和推送。")
            #if DEBUG
                SettingRow(label: "画布样张", hint: "看生活画布的每一种卡片：这一周每天是一种人的一天，左右滑着看") {
                    WebTextButton(CanvasSamples.isOn ? "关掉样张" : "打开样张") { model.showSamples(!CanvasSamples.isOn) }
                }
                FieldMessage(text: "样张在 App 里，不连服务器；在样张里说的话也不会发出去。")
            #endif
        }
        .sheet(item: $exported) { file in ShareSheet(items: [file.url]) }
    }

    private var backupText: String {
        guard let last = status.backups.first else { return "还没有" }
        return "\(EvalNames.when(last.at)) · \(Self.size(last.size)) · 共 \(status.backupCount) 份"
    }

    @ViewBuilder private func busyButton(
        _ key: String, title: String, _ work: @escaping @Sendable (APIClient) async throws -> String
    ) -> some View {
        if busy == key {
            Dots(label: "\(title)，正在处理").foregroundStyle(Web.accent)
        } else {
            WebTextButton(title) {
                busy = key
                let client = model.client
                Task {
                    defer { busy = nil }
                    do {
                        model.toast(try await work(client))
                        reload()
                    } catch {
                        model.toast(error.readable)
                    }
                }
            }
        }
    }

    /// 日界线只能在 00:00 到 06:00 之间
    private func saveBoundary(_ clock: String) {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        let minutes = (parts.first ?? 0) * 60 + (parts.count > 1 ? parts[1] : 0)
        guard minutes <= 6 * 60 else {
            model.toast("要在 00:00 到 06:00 之间")
            reload()
            return
        }
        let client = model.client
        Task {
            do {
                try await client.setDayBoundary(minutes)
                reload()
                await model.refreshAll()
            } catch {
                model.toast(error.readable)
            }
        }
    }

    /// 导出：先存到手机上，再用系统的分享（存到「文件」、隔空投送……）
    private func export() {
        busy = "export"
        let client = model.client
        Task {
            defer { busy = nil }
            do {
                exported = ExportedFile(url: try await client.download("/api/data/export", name: "pour-export.zip"))
            } catch {
                model.toast(error.readable)
            }
        }
    }

    /// 切换真实数据、演示数据：服务器会重新启动，等它回来再整个重新拿
    private func switchMode(_ mode: String, regenerate: Bool = false) {
        busy = mode
        model.toast(mode == "demo" ? "正在切换到演示数据…" : "正在回到真实数据…")
        let client = model.client
        Task {
            defer { busy = nil }
            do {
                try await client.switchData(to: mode, regenerate: regenerate)
                try? await Task.sleep(for: .milliseconds(800))
                for _ in 0..<60 {
                    if let meta = try? await client.meta(), meta.mode == mode { break }
                    try? await Task.sleep(for: .milliseconds(500))
                }
                await model.refreshAll()
                reload()
            } catch {
                model.toast(error.readable)
            }
        }
    }

    /// 240 →「04:00」
    static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    static func size(_ bytes: Int) -> String {
        bytes < 1024 * 1024
            ? "\(max(1, Int((Double(bytes) / 1024).rounded()))) KB"
            : String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}

/// 重新解析（规格第十三章）：先估算要用多少，确认了才开始
private struct ReparseRows: View {
    @Environment(AppModel.self) private var model
    let today: String
    @State private var from = ""
    @State private var until = ""
    @State private var estimate: API.ReparseEstimate?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "重新解析", hint: "改了整理规则以后，用新规则重新整理一段时间的原话") {
                if busy && estimate == nil {
                    Dots(label: "正在估算").foregroundStyle(Web.accent)
                } else {
                    WebTextButton("估算") { check() }
                }
            }
            HStack(spacing: Web.space3) {
                dayField("从", value: $from, range: ...(Self.date(until) ?? .now))
                dayField("到", value: $until, range: (Self.date(from) ?? .distantPast)...)
            }
            .padding(.bottom, Web.space2)
            if let estimate {
                SetupBox {
                    Text(
                        Show.spaced(
                            "\(Show.dayTitle(from, today: today)) 到 \(Show.dayTitle(until, today: today)) "
                                + "有 \(estimate.notes) 段话，"
                                + "大约用 \(Numbers.grouped(Double(estimate.tokens))) token（\(estimate.model)，"
                                + "约 ¥\(String(format: "%.2f", estimate.cny))）。原话不变，整理结果会换成新的。")
                    )
                    .font(Web.body).foregroundStyle(Web.fg)
                    HStack(spacing: Web.space3) {
                        WebButton("开始重新解析", variant: .primary, loading: busy, disabled: estimate.notes == 0) { start() }
                        WebTextButton("取消") { self.estimate = nil }
                    }
                }
                .padding(.vertical, Web.space2)
            }
        }
        .onAppear {
            if from.isEmpty {
                from = PourDate.addDays(today, -6)
                until = today
            }
        }
    }

    /// 日期输入框：点开是系统的日期选择
    private func dayField(_ label: String, value: Binding<String>, range: some RangeExpression<Date>) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text(label).font(Web.captionMedium).foregroundStyle(Web.fgSecondary)
            DatePicker(
                label,
                selection: Binding(
                    get: { Self.date(value.wrappedValue) ?? .now },
                    set: {
                        value.wrappedValue = PourDate.logicalDay($0, in: .current, boundary: 0)
                        estimate = nil
                    }),
                displayedComponents: .date
            )
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_CN"))
        }
    }

    /// 「2026-10-19」那一天的中午（日期选择用：中午不怕时区差一点就跳到前后一天）
    static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    private func check() {
        busy = true
        let client = model.client
        let (start, end) = (from, until)
        Task {
            defer { busy = false }
            do {
                estimate = try await client.reparseEstimate(from: start, until: end)
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func start() {
        busy = true
        let client = model.client
        let (start, end) = (from, until)
        Task {
            defer { busy = false }
            do {
                let notes = try await client.reparse(from: start, until: end)
                model.toast("\(notes) 段话开始重新整理，在对话里可以看到进度")
                estimate = nil
                await model.refreshAll()
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 导出好的文件（用系统的分享面板存起来）
struct ExportedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// 系统的分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
