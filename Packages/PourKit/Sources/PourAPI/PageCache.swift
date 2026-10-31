public import Foundation

/// 页面缓存（docs/3.0/07-开发任务清单.md 1.11、02 技术方案 4.3）：每个页面接口最后一次拿到的回复存在手机上，
/// 按服务器地址分开。没连上时拿它顶上——打开每一页都有内容，顶上一条细条说是几点的；
/// 新页面打开时先用它画出来、再去拿新的（不整页转圈）。
/// 存在系统的缓存目录里（系统空间不够时可以清掉，清掉了只是下次没网时看不到）；换了真实数据、演示数据整个清掉
public struct PageCache: Sendable {
    let folder: URL

    /// folder 是 nil：用系统缓存目录下按服务器地址分开的一个文件夹
    public init(server: URL, folder: URL? = nil) {
        let root =
            folder
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pour-pages", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pour-pages", isDirectory: true)
        self.folder = root.appendingPathComponent(Self.key(server.absoluteString), isDirectory: true)
    }

    /// 存一份回复（原样的 JSON）
    public func save(_ data: Data, for path: String, at date: Date = Date()) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(Self.key(path))
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
    }

    /// 上次存的那份和存下的时刻；没有是 nil
    public func load(_ path: String) -> (data: Data, savedAt: Date)? {
        let file = folder.appendingPathComponent(Self.key(path))
        guard let data = try? Data(contentsOf: file) else { return nil }
        let date = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date) ?? Date()
        return (data, date)
    }

    /// 全部清掉（换了真实数据、演示数据：别让上一边的东西在没网时冒出来）
    public func clear() {
        try? FileManager.default.removeItem(at: folder)
    }

    /// 文件名：地址里的字换成只用字母数字的一串（FNV-1a，64 位；不同地址撞上的机会可以不管）
    static func key(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
