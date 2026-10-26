import Foundation
import Observation
import PourPlatform

/// 说一次话（docs/模块/生活画布2.0.md 第 6 节）：点一下说（输入框长成录音卡）或者按住说（松开就发）。
/// 管状态、声波、字（定下来的 + 还没定下来的）、计时；最长 2 分钟，1 分 50 秒轻震一下提醒
@MainActor @Observable
final class VoiceSession {
    /// 点一下说、按住说
    enum Mode: Sendable {
        case tap, hold
    }

    /// 现在在哪一步
    enum Phase: Equatable {
        case idle
        /// 第一次用：系统在下载中文的听写模型（0–1）
        case preparing(Double)
        case listening
        /// 听不了、没听清：一句话说清楚；`settings` 是要去设置里打开麦克风
        case failed(String, settings: Bool)
    }

    /// 声波有几根竖条
    static let bars = 46
    /// 声波每多少秒往左挪一根（46 根大约是最近 2.8 秒的声音）
    static let step: TimeInterval = 0.06
    /// 音量到多少算「在说话」（LevelMeter 已经扣掉了底噪）
    static let voiced = 0.25
    /// 最长说多久
    static let limit: TimeInterval = 120
    /// 快到时提醒
    static let warning: TimeInterval = 110

    private(set) var phase: Phase = .idle
    private(set) var mode: Mode = .tap
    private(set) var settled = ""
    private(set) var pending = ""
    private(set) var levels = [Double](repeating: 0, count: VoiceSession.bars)
    private(set) var startedAt: Date?
    /// 快到 2 分钟了（轻震一下）
    private(set) var nearLimit = false
    /// 到 2 分钟了：外面决定怎么收尾（点一下的转成字，按住的发出去）
    var onLimit: (() -> Void)?
    /// 被打断了（来电话、闹钟、换耳机）：外面把说到的字放进输入框，不发
    var onInterrupted: (() -> Void)?
    /// 说话时的一句提示：一直没听到声音、说完停了一会儿
    private(set) var hint: String?
    @ObservationIgnored private var lastShift = Date.distantPast
    @ObservationIgnored private var lastVoice: Date?

    private let input: any VoiceInput
    private var listening: Task<Void, Never>?
    private var clock: Task<Void, Never>?

    init(input: any VoiceInput) {
        self.input = input
    }

    /// 手机上的听写；界面测试（-uiTest）、连真服务器联调（-fakeVoice）用假的，不开麦克风
    static func makeInput() -> any VoiceInput {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-uiTest") || arguments.contains("-fakeVoice") { return FakeVoice() }
        #endif
        return OnDeviceVoice()
    }

    /// 看过「用说的」那张说明了（存在手机上；界面测试每次从头来，不存）
    var explained: Bool {
        get { explainedNow || (!Self.testing && UserDefaults.standard.bool(forKey: Self.explainedKey)) }
        set {
            explainedNow = newValue
            if !Self.testing { UserDefaults.standard.set(newValue, forKey: Self.explainedKey) }
        }
    }

    private var explainedNow = false
    private static let explainedKey = "pour.voice.explained"
    private static let testing = ProcessInfo.processInfo.arguments.contains("-uiTest")

    /// 录音卡、按住说的卡要不要出现
    var active: Bool {
        switch phase {
        case .preparing, .listening: true
        case .idle, .failed: false
        }
    }

    /// 已经说了的字（定下来的在前）
    var text: String { settled + pending }

    func start(_ mode: Mode) {
        guard !active else { return }
        self.mode = mode
        clear()
        phase = .preparing(0)
        listening = Task { [input] in
            do {
                for await event in try await input.start() { handle(event) }
            } catch let error as VoiceError {
                fail(error)
            } catch {
                fail(.other(error.localizedDescription))
            }
        }
    }

    /// 说完了：整段话（空的说「没听清」，返回 nil；被打断时 quiet，什么都没说就安静地收起）
    func finish(quiet: Bool = false) async -> String? {
        guard active else { return nil }
        clock?.cancel()
        let words = await input.stop()
        listening?.cancel()
        clear()
        guard !words.isEmpty else {
            phase = quiet ? .idle : .failed("没听清，再说一次", settings: false)
            return nil
        }
        phase = .idle
        return words
    }

    /// 不要了
    func cancel() {
        clock?.cancel()
        listening?.cancel()
        Task { [input] in await input.cancel() }
        clear()
        phase = .idle
    }

    /// 看过了出错的那句话
    func dismissFailure() {
        if case .failed = phase { phase = .idle }
    }

    private func handle(_ event: VoiceEvent) {
        switch event {
        case .preparing(let progress):
            phase = .preparing(progress)
        case .listening:
            phase = .listening
            startedAt = Date()
            startClock()
        case .level(let value):
            meter(value)
        case .text(let final, let volatile):
            settled = final
            pending = volatile
        case .interrupted:
            onInterrupted?()
        case .failed(let error):
            fail(error)
        }
    }

    /// 声波：最右边那根是这一小会儿里最响的，每 0.06 秒往左挪一根；顺便看有没有在说话、要不要提示
    private func meter(_ value: Double) {
        let now = Date()
        if now.timeIntervalSince(lastShift) >= Self.step {
            levels.removeFirst()
            levels.append(value)
            lastShift = now
        } else if let last = levels.indices.last {
            levels[last] = max(levels[last], value)
        }
        if value >= Self.voiced { lastVoice = now }
        let next = Self.hint(startedAt: startedAt, lastVoice: lastVoice, now: now, mode: mode)
        if next != hint { hint = next }
    }

    /// 开始 4 秒还没听到声音：靠近一点说；说过话以后停了 5 秒（点一下说的）：可以发了
    static func hint(startedAt: Date?, lastVoice: Date?, now: Date, mode: Mode) -> String? {
        guard let startedAt else { return nil }
        guard let lastVoice else { return now.timeIntervalSince(startedAt) > 4 ? "没听到声音，靠近手机说" : nil }
        return mode == .tap && now.timeIntervalSince(lastVoice) > 5 ? "说完了就点 ↑ 发出去，点 ✓ 可以先改一改" : nil
    }

    private func fail(_ error: VoiceError) {
        clock?.cancel()
        clear()
        phase = .failed(error.message, settings: error == .noPermission)
    }

    private func clear() {
        settled = ""
        pending = ""
        levels = [Double](repeating: 0, count: Self.bars)
        startedAt = nil
        nearLimit = false
        hint = nil
        lastVoice = nil
        lastShift = .distantPast
    }

    /// 1 分 50 秒提醒一下，2 分钟到了交给外面收尾
    private func startClock() {
        clock?.cancel()
        clock = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.warning))
            guard !Task.isCancelled else { return }
            self?.nearLimit = true
            try? await Task.sleep(for: .seconds(Self.limit - Self.warning))
            guard !Task.isCancelled else { return }
            self?.onLimit?()
        }
    }
}
