/// 说话转成字（docs/模块/生活画布2.0.md 第 6 节「语音识别」）：界面只认这个接口。
/// 现在是手机上的 `OnDeviceVoice`（系统的 SpeechAnalyzer，录音只在内存里，不存不传）；
/// 以后产品主人接上大模型，加一个云端的实现、或者转出来的字发出去之前让大模型理顺，界面不用动
public protocol VoiceInput: Sendable {
    /// 开始听：一边说一边来事件（音量、字）；听不了时抛 `VoiceError`
    func start() async throws -> AsyncStream<VoiceEvent>
    /// 说完了：等最后几个字定下来，返回整段话
    func stop() async -> String
    /// 不要了：马上停，什么都不留
    func cancel() async
}

/// 听的时候来的事件
public enum VoiceEvent: Sendable, Equatable {
    /// 第一次用要下载中文的听写模型：进度 0–1
    case preparing(Double)
    /// 开始听了
    case listening
    /// 音量 0–1（画声波，一秒三十次）
    case level(Double)
    /// 已经定下来的字、还没定下来的字（一边说一边会改）
    case text(final: String, volatile: String)
    /// 中途出错了
    case failed(VoiceError)
}

/// 听不了的原因：界面照这个说人话
public enum VoiceError: Error, Sendable, Equatable {
    /// 麦克风没开（去设置里打开）
    case noPermission
    /// 这台手机不支持中文的听写
    case unsupported
    /// 下载中文模型没成（多半是没网）
    case downloadFailed
    /// 别的（系统给的原话）
    case other(String)

    /// 给人看的一句话
    public var message: String {
        switch self {
        case .noPermission: "要用语音，去设置里打开麦克风"
        case .unsupported: "这台手机还不支持中文的听写"
        case .downloadFailed: "中文的听写模型没下载下来，连上网再试一次"
        case .other(let reason): "没听成：\(reason)"
        }
    }
}
