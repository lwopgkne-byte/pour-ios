import Foundation

/// 把一段段转出来的字拼成一整段（产品主人 2026-10-26 的截图：「今天的待办有哪些今天的待办有哪些？」——
/// 系统把同一段声音又识别了一遍，以前两次都接了上去）。按录音的时间段拼：定下来的一段段按时间排，
/// 和已经定下来的时间段大半重叠的，后来的换掉先来的；还没定下来的那段盖在它重叠的那几段上
public struct VoiceTranscript: Sendable, Equatable {
    /// 一段字和它在录音里的时间（秒）
    public struct Piece: Sendable, Equatable {
        public let start: Double
        public let end: Double
        public let text: String

        public init(start: Double, end: Double, text: String) {
            self.start = start
            self.end = end
            self.text = text
        }

        /// 大半重叠：重叠的部分超过短的那段的一半（只是挨着、擦个边不算）
        func overlaps(_ other: Piece) -> Bool {
            let shared = min(end, other.end) - max(start, other.start)
            let shorter = min(end - start, other.end - other.start)
            return shared > 0 && shared > shorter / 2
        }
    }

    private var finals: [Piece] = []
    private var current: Piece?

    public init() {}

    public mutating func add(_ piece: Piece, isFinal: Bool) {
        guard isFinal else {
            current = piece
            return
        }
        finals.removeAll { $0.overlaps(piece) }
        finals.append(piece)
        finals.sort { $0.start < $1.start }
        if let current, current.overlaps(piece) || current.end <= piece.end { self.current = nil }
    }

    /// 定下来的字（被还没定下来的那段盖住的不算）
    public var settled: String {
        finals.filter { piece in current.map { !piece.overlaps($0) } ?? true }.map(\.text).joined()
    }

    /// 还没定下来的字
    public var volatile: String { current?.text ?? "" }

    /// 整段话
    public var text: String { (settled + volatile).trimmingCharacters(in: .whitespacesAndNewlines) }
}
