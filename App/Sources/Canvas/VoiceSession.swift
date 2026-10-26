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

    /// 说完了：整段话（空的说「没听清」，返回 nil）
    func finish() async -> String? {
        guard active else { return nil }
        clock?.cancel()
        let words = await input.stop()
        listening?.cancel()
        clear()
        guard !words.isEmpty else {
            phase = .failed("没听清，再说一次", settings: false)
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
            levels.removeFirst()
            levels.append(value)
        case .text(let final, let volatile):
            settled = final
            pending = volatile
        case .failed(let error):
            fail(error)
        }
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
