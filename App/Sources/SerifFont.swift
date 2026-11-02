import CoreText
import UIKit

/// 宋体（docs/3.0/02-技术方案.md：设计系统「宋体原话」）：iPhone 上的宋体是「用到时才下载」的系统字体，
/// 没下载时写着宋体的字悄悄退回黑体（2026-11-02 第 6 步查出来：前几步截图里的「宋体」其实都是黑体）。
/// 打开 App 时看一眼，没有就请系统在后台下载（只下一次，所有 App 共用，不用我们自己带字体文件）；
/// 下好以后下一次画出来的就是宋体。模拟器上没有字体目录，下不了，照旧黑体
enum SerifFont {
    static let name = "STSongti-SC-Regular"

    static var installed: Bool { UIFont(name: name, size: 17) != nil }

    /// 没有就下（失败只记一句日志，不打扰）
    static func ensure() {
        guard !installed else { return }
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute: name] as CFDictionary)
        CTFontDescriptorMatchFontDescriptorsWithProgressHandler([descriptor] as CFArray, nil) { state, progress in
            if state == .didFailWithError {
                let reason = (progress as NSDictionary)[kCTFontDescriptorMatchingError] as? NSError
                Log.error("宋体下载不了：\(reason?.localizedDescription ?? "不知道为什么")")
            }
            return true
        }
    }
}
