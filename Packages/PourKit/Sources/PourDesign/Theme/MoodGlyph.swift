public import SwiftUI

/// 心情的五个表情（很差 · 不太好 · 一般 · 挺好 · 很好）：和原型一样用 Google 的 Material Symbols Rounded
/// （sentiment_very_dissatisfied … sentiment_very_satisfied；实心、粗细 500、24 号）。一张实心的脸，眼睛和嘴是挖空的，
/// 透出底下这一档的颜色。字形照搬官方 SVG（Apache License 2.0，ADR A36），不自己画
public struct MoodGlyph: Shape {
    let level: Int

    public init(level: Int) {
        self.level = min(5, max(1, level))
    }

    public func path(in rect: CGRect) -> Path {
        // 原图是 960 × 960，y 从 -960 到 0：先挪到 0…960，再缩放、放到正中
        let side = min(rect.width, rect.height)
        let scale = side / Self.box
        let place = CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: 0, y: Self.box)
        return Self.paths[level - 1].applying(place)
    }

    static let box: CGFloat = 960
    /// 读一次，之后共用
    static let paths: [Path] = data.map(SVGPath.parse)

    /// 官方 SVG 的 d（只把一长行在数和数之间断开，换行就是分隔）
    static let data = [
        // sentiment_very_dissatisfied
        """
        m356-522 21 21q9 9 21 9t21-9q9-9 9-21t-9-21l-21-21 22-23q8-9 8-21t-9-21q-9-9-21-9t-21 9l-21 21-23-22
        q-9-8-21-8t-21 9q-8 8-8.5 20.5T290-587l22 23-21 21q-9 9-9 21t9 21q8 8 20.5 8.5T333-500l23-22Zm248 0
        23 22q9 8 21 8t21-9q9-9 9-21t-9-21l-21-21 22-23q8-9 8-21t-9-21q-8-8-20.5-8.5T627-630l-23 22-21-21q-9
        -9-21-9t-21 9q-8 8-8.5 20.5T540-587l22 23-21 21q-9 9-9 21t9 21q9 9 21 9t21-9l21-21ZM320.89-103.97q
        -74.43-32.1-129.63-87.29-55.19-55.2-87.29-129.63-32.1-74.44-32.1-159.11 0-84.67 32.1-159.11 32.1
        -74.43 87.29-129.63 55.2-55.19 129.63-87.29 74.44-32.1 159.11-32.1 84.67 0 159.11 32.1 74.43 32.1
        129.63 87.29 55.19 55.2 87.29 129.63 32.1 74.44 32.1 159.11 0 84.67-32.1 159.11-32.1 74.43-87.29
        129.63-55.2 55.19-129.63 87.29-74.44 32.1-159.11 32.1-84.67 0-159.11-32.1ZM480-420q-57 0-106.26
        27.88-49.26 27.88-78.31 76.12-6.23 12 1 24 7.24 12 21.24 12h323.94q14 0 21.36-12 7.36-12 1.12-24
        -29.05-48.24-77.69-76.12Q537.76-420 480-420Z
        """,
        // sentiment_dissatisfied
        """
        M480-420q-52.8 0-99.59 22.42-46.78 22.43-75.78 65.99-11.96 16.96-3.84 34.27Q308.91-280 327.87-280q
        8.72 0 15.93-3.98 7.22-3.98 12.94-11.22 22.28-28.84 54.73-45.03 32.44-16.18 68.53-16.18t68.53 16.18q
        32.45 16.19 54.73 45.03 4.96 7.24 12.17 11.22 7.22 3.98 15.94 3.98 18.96 0 27.2-17.46 8.23-17.45
        -3.48-35.17-29.24-42.8-76.02-65.09Q532.28-420 480-420Zm138.09-98.09q25.95 0 43.93-17.98Q680-554.04
        680-580t-17.98-43.93q-17.98-17.98-43.93-17.98-25.72 0-43.7 18.09-17.98 18.1-17.98 43.82t17.98 43.82q
        17.98 18.09 43.7 18.09Zm-276.18 0q25.72 0 43.7-18.09 17.98-18.1 17.98-43.82t-17.98-43.82q-17.98
        -18.09-43.7-18.09-25.95 0-43.93 17.98Q280-605.96 280-580t17.98 43.93q17.98 17.98 43.93 17.98Zm-21.02
        414.12q-74.43-32.1-129.63-87.29-55.19-55.2-87.29-129.63-32.1-74.44-32.1-159.11 0-84.67 32.1-159.11
        32.1-74.43 87.29-129.63 55.2-55.19 129.63-87.29 74.44-32.1 159.11-32.1 84.67 0 159.11 32.1 74.43
        32.1 129.63 87.29 55.19 55.2 87.29 129.63 32.1 74.44 32.1 159.11 0 84.67-32.1 159.11-32.1 74.43
        -87.29 129.63-55.2 55.19-129.63 87.29-74.44 32.1-159.11 32.1-84.67 0-159.11-32.1Z
        """,
        // sentiment_neutral
        """
        M618.09-518.09q25.95 0 43.93-17.98Q680-554.04 680-580t-17.98-43.93q-17.98-17.98-43.93-17.98-25.72 0
        -43.7 18.09-17.98 18.1-17.98 43.82t17.98 43.82q17.98 18.09 43.7 18.09Zm-276.18 0q25.72 0 43.7-18.09
        17.98-18.1 17.98-43.82t-17.98-43.82q-17.98-18.09-43.7-18.09-25.95 0-43.93 17.98Q280-605.96 280-580t
        17.98 43.93q17.98 17.98 43.93 17.98Zm50 180h176.18q13.71 0 22.81-9.09 9.1-9.1 9.1-22.82t-9.1-22.82q
        -9.1-9.09-22.81-9.09H391.91q-13.71 0-22.81 9.09-9.1 9.1-9.1 22.82t9.1 22.82q9.1 9.09 22.81 9.09Zm
        -71.02 234.12q-74.43-32.1-129.63-87.29-55.19-55.2-87.29-129.63-32.1-74.44-32.1-159.11 0-84.67 32.1
        -159.11 32.1-74.43 87.29-129.63 55.2-55.19 129.63-87.29 74.44-32.1 159.11-32.1 84.67 0 159.11 32.1
        74.43 32.1 129.63 87.29 55.19 55.2 87.29 129.63 32.1 74.44 32.1 159.11 0 84.67-32.1 159.11-32.1
        74.43-87.29 129.63-55.2 55.19-129.63 87.29-74.44 32.1-159.11 32.1-84.67 0-159.11-32.1Z
        """,
        // sentiment_satisfied
        """
        M480-260q52.28 0 99.07-22.28 46.78-22.29 76.02-65.09 11.71-17.72 3.48-35.17-8.24-17.46-27.2-17.46
        -8.72 0-15.94 3.98-7.21 3.98-12.17 11.22-22.28 28.84-54.73 45.03-32.44 16.18-68.53 16.18t-68.53
        -16.18q-32.45-16.19-54.73-45.03-5.72-7.24-12.94-11.22-7.21-3.98-15.93-3.98-18.96 0-27.08 17.32-8.12
        17.31 3.84 34.27 29 43.56 75.78 65.99Q427.2-260 480-260Zm138.09-258.09q25.95 0 43.93-17.98Q680
        -554.04 680-580t-17.98-43.93q-17.98-17.98-43.93-17.98-25.72 0-43.7 18.09-17.98 18.1-17.98 43.82t
        17.98 43.82q17.98 18.09 43.7 18.09Zm-276.18 0q25.72 0 43.7-18.09 17.98-18.1 17.98-43.82t-17.98-43.82
        q-17.98-18.09-43.7-18.09-25.95 0-43.93 17.98Q280-605.96 280-580t17.98 43.93q17.98 17.98 43.93 17.98Z
        m-21.02 414.12q-74.43-32.1-129.63-87.29-55.19-55.2-87.29-129.63-32.1-74.44-32.1-159.11 0-84.67 32.1
        -159.11 32.1-74.43 87.29-129.63 55.2-55.19 129.63-87.29 74.44-32.1 159.11-32.1 84.67 0 159.11 32.1
        74.43 32.1 129.63 87.29 55.19 55.2 87.29 129.63 32.1 74.44 32.1 159.11 0 84.67-32.1 159.11-32.1
        74.43-87.29 129.63-55.2 55.19-129.63 87.29-74.44 32.1-159.11 32.1-84.67 0-159.11-32.1Z
        """,
        // sentiment_very_satisfied
        """
        M480-260q58.72 0 108.2-28.6 49.47-28.6 79.23-77.55 6-12.48-1.23-24.6-7.24-12.12-21.48-12.12H315.28q
        -14.24 0-21.48 12-7.23 12-1.23 24.48 29.76 48.96 79.61 77.67Q422.04-260 480-260ZM356-559.85l20.52
        20.52q9.48 9.48 22.32 9.48 12.83 0 22.31-9.48 9.48-9.47 9.1-22.19-.38-12.72-9.1-22.2l-33.08-34.32q
        -13.68-13.68-32.45-13.68-18.77 0-32.45 13.68l-34.32 34.32q-9.48 9.48-9.36 22.32 .12 12.83 9.6 22.31
        8.71 8.72 21.81 9.1 13.1 .38 22.58-8.34L356-559.85Zm248 0 22.52 21.52q9.48 8.72 22.2 8.6 12.71-.12
        22.19-9.6 9.48-9.47 9.48-22.31 0-12.84-9.48-22.32l-34.08-34.08q-13.68-13.68-32.45-13.68-18.77 0
        -32.45 13.68l-33.84 34.32q-8.72 9.48-8.6 22.2 .12 12.72 9.6 22.19 9.48 9.48 22.19 9.48 12.72 0 22.2
        -9.48L604-559.85ZM320.89-103.97q-74.43-32.1-129.63-87.29-55.19-55.2-87.29-129.63-32.1-74.44-32.1
        -159.11 0-84.67 32.1-159.11 32.1-74.43 87.29-129.63 55.2-55.19 129.63-87.29 74.44-32.1 159.11-32.1
        84.67 0 159.11 32.1 74.43 32.1 129.63 87.29 55.19 55.2 87.29 129.63 32.1 74.44 32.1 159.11 0 84.67
        -32.1 159.11-32.1 74.43-87.29 129.63-55.2 55.19-129.63 87.29-74.44 32.1-159.11 32.1-84.67 0-159.11
        -32.1Z
        """,
    ]
}

/// 把 SVG 的 d 读成 Path：直线、水平线、竖线、二次和三次曲线（M L H V Q T C S Z，大小写都认）；
/// Material Symbols 的字形只用到这些，不认弧线（A）
enum SVGPath {
    fileprivate struct Token {
        let command: Character?
        let value: CGFloat
    }

    static func parse(_ data: String) -> Path {
        var reader = Reader(tokens: tokenize(data))
        while reader.step() {}
        return reader.path
    }

    /// 一段一段往下读：记着当前点、这一笔的起点、上一段的控制点
    private struct Reader {
        let tokens: [Token]
        var index = 0
        var path = Path()
        var point = CGPoint.zero
        var start = CGPoint.zero
        /// 上一段的控制点：T、S 拿它对称过来（上一段不是同一种曲线就用当前点）
        var quad: CGPoint?
        var cubic: CGPoint?
        var command: Character = "M"

        /// 读一段；读完了、或者数据坏了返回 false
        mutating func step() -> Bool {
            guard index < tokens.count else { return false }
            if let next = tokens[index].command {
                command = next
                index += 1
            }
            let relative = command.isLowercase
            let kind = command.uppercased()
            var nextQuad: CGPoint?
            var nextCubic: CGPoint?
            switch kind {
            case "M":
                point = pair(relative)
                start = point
                path.move(to: point)
                // M 后面接着的几对数是直线
                command = relative ? "l" : "L"
            case "L", "H", "V":
                point = lineEnd(kind, relative)
                path.addLine(to: point)
            case "Q", "T":
                nextQuad = kind == "Q" ? pair(relative) : mirror(quad)
                point = pair(relative)
                path.addQuadCurve(to: point, control: nextQuad ?? point)
            case "C", "S":
                let first = kind == "C" ? pair(relative) : mirror(cubic)
                nextCubic = pair(relative)
                point = pair(relative)
                path.addCurve(to: point, control1: first, control2: nextCubic ?? point)
            case "Z":
                return close()
            default:
                return false
            }
            quad = nextQuad
            cubic = nextCubic
            return true
        }

        /// Z：回到这一笔的起点；后面只能是新的命令，是数说明数据坏了，到此为止
        private mutating func close() -> Bool {
            path.closeSubpath()
            point = start
            quad = nil
            cubic = nil
            return index < tokens.count && tokens[index].command != nil
        }

        private mutating func lineEnd(_ kind: String, _ relative: Bool) -> CGPoint {
            switch kind {
            case "H":
                let x = number()
                return CGPoint(x: relative ? point.x + x : x, y: point.y)
            case "V":
                let y = number()
                return CGPoint(x: point.x, y: relative ? point.y + y : y)
            default:
                return pair(relative)
            }
        }

        private mutating func number() -> CGFloat {
            guard index < tokens.count, tokens[index].command == nil else { return 0 }
            index += 1
            return tokens[index - 1].value
        }

        private mutating func pair(_ relative: Bool) -> CGPoint {
            let x = number()
            let y = number()
            return relative ? CGPoint(x: point.x + x, y: point.y + y) : CGPoint(x: x, y: y)
        }

        private func mirror(_ control: CGPoint?) -> CGPoint {
            control.map { CGPoint(x: point.x * 2 - $0.x, y: point.y * 2 - $0.y) } ?? point
        }
    }

    /// 拆成命令和数：「17.98-17.98」是两个数，「.5.5」也是两个数
    private static func tokenize(_ data: String) -> [Token] {
        var tokens: [Token] = []
        var number = ""
        func flush() {
            if let value = Double(number) { tokens.append(Token(command: nil, value: CGFloat(value))) }
            number = ""
        }
        for char in data {
            switch char {
            case "0"..."9":
                number.append(char)
            case ".":
                if number.contains(".") || number.contains("e") || number.contains("E") { flush() }
                number.append(char)
            case "-", "+":
                if number.last != "e", number.last != "E" { flush() }
                number.append(char)
            case "e" where !number.isEmpty, "E" where !number.isEmpty:
                number.append(char)
            case _ where char.isLetter:
                flush()
                tokens.append(Token(command: char, value: 0))
            default:
                flush()
            }
        }
        flush()
        return tokens
    }
}
