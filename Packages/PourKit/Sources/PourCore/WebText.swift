public import Foundation

/// 中文和数字、英文之间的空（服务器 shared/src/format.ts 原样）。别的写法都由服务器写好再给 App（ADR A22），
/// 3.0 第 0 步删掉了第一阶段手机自己写的那些
public enum WebText {
    /// 中文和数字、英文挨着时中间留一点空（「10 月 15 日」「跑步 1 小时」）。
    /// 用六分之一个字宽的空格，已经有空格的不再加
    public static func spaced(_ text: String) -> String {
        var out = ""
        var previous: Character?
        for char in text {
            if let last = previous, needsGap(last, char) { out.append("\u{2006}") }
            out.append(char)
            previous = char
        }
        return out
    }

    private static func isHan(_ char: Character) -> Bool {
        char.unicodeScalars.first.map { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
            ?? false
    }

    private static func isLatin(_ char: Character) -> Bool {
        char.isASCII && (char.isLetter || char.isNumber)
    }

    private static func needsGap(_ left: Character, _ right: Character) -> Bool {
        (isHan(left) && isLatin(right)) || (isLatin(left) && isHan(right))
    }
}
