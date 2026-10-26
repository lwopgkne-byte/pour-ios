/// 服务器写好的一个数（「12 杯」「1 小时 20 分」「¥680」「23:40」）拆成大数字和小单位，画成 FigureText
/// （docs/模块/产品优化.md R3：我的卡片里的数由服务器现算，手机只管画）
extension CanvasPlan {
    public struct Figure: Equatable, Sendable {
        public var prefix: String?
        public var parts: [Part]
    }

    public static func figure(_ text: String) -> Figure {
        var rest = text.trimmingCharacters(in: .whitespaces)
        var prefix: String?
        if rest.hasPrefix("¥") {
            prefix = "¥"
            rest.removeFirst()
        }
        var pairs: [(number: String, unit: String)] = []
        for token in rest.split(separator: " ").map(String.init) {
            if token.first?.isNumber == true || (token.first == "-" && token.count > 1) {
                pairs.append((token, ""))
            } else if let last = pairs.indices.last {
                pairs[last].unit += pairs[last].unit.isEmpty ? token : " \(token)"
            } else {
                pairs.append(("", token))
            }
        }
        return Figure(prefix: prefix, parts: pairs.map { Part(number: $0.number, unit: $0.unit) })
    }
}
