import Foundation

/// 声波的高低（产品主人 2026-10-26：说话和不说话，声波要不一样，跟着声音大小变）：一小段声音的音量换成 0–1。
/// 屋里、街上的底噪不一样：一直记着最近的底噪（安静时的音量），比底噪高出来的才算说话；起得快、落得慢，看着顺
public struct LevelMeter: Sendable {
    /// 底噪（分贝）
    public private(set) var floor: Double
    private var shown = 0.0

    public init(floor: Double = -55) {
        self.floor = floor
    }

    /// 一小段声音的均方根（0–1）
    public mutating func next(rms: Double) -> Double {
        let decibels = 20 * log10(max(rms, 0.000_01))
        // 更安静就马上跟下来；更吵就慢慢往上爬（一直说话也不会把底噪顶上去，说话中间的停顿又会把它拉下来）
        floor = decibels < floor ? decibels : floor + (decibels - floor) * 0.003
        // 比底噪高 6 分贝以上才算有声音，高出 36 分贝算满
        let target = min(1, max(0, (decibels - floor - 6) / 30))
        shown += (target - shown) * (target > shown ? 0.6 : 0.18)
        return shown
    }
}
