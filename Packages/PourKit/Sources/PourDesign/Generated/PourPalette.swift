// 生成的文件：scripts/palette.py --swift。不要手改——改颜色改脚本里的亮度、饱和度、色相。
// 原始色板只在令牌定义里用（PourColor），界面代码不直接引用（设计规范 01 第 1 节）。

/// 原始色板（OKLCH 生成）
public enum PourPalette {
    public static let paper0 = RGB(0xFFFFFF)
    public static let paper25 = RGB(0xFBFAF8)
    public static let paper50 = RGB(0xF6F4F0)
    public static let paper100 = RGB(0xEDEBE7)
    public static let paper150 = RGB(0xE1DFDB)
    public static let paper200 = RGB(0xD4D2CE)
    public static let paper300 = RGB(0xBCBAB6)
    public static let paper400 = RGB(0xA09E9A)
    public static let paper500 = RGB(0x85837F)
    public static let paper600 = RGB(0x6D6C68)
    public static let paper700 = RGB(0x575552)
    public static let paper800 = RGB(0x3E3D3A)
    public static let paper850 = RGB(0x2F2E2B)
    public static let paper900 = RGB(0x21201E)
    public static let paper925 = RGB(0x1A1917)
    public static let paper950 = RGB(0x161513)
    public static let paper975 = RGB(0x11100F)
    public static let paper1000 = RGB(0x0C0B0A)
    public static let qing50 = RGB(0xE5F8F7)
    public static let qing100 = RGB(0xCEF0EE)
    public static let qing200 = RGB(0xABE0DD)
    public static let qing300 = RGB(0x7FCAC7)
    public static let qing400 = RGB(0x51B0AD)
    public static let qing500 = RGB(0x279592)
    public static let qing600 = RGB(0x067976)
    public static let qing700 = RGB(0x055F5D)
    public static let qing800 = RGB(0x024745)
    public static let qing900 = RGB(0x00302F)
    public static let amber50 = RGB(0xFEF1E3)
    public static let amber100 = RGB(0xFEE3C5)
    public static let amber300 = RGB(0xE7B375)
    public static let amber500 = RGB(0xBA7E2D)
    public static let amber600 = RGB(0x9D671C)
    public static let amber700 = RGB(0x7F5314)
    public static let markerLight = RGB(0xF6EBB1)
    public static let markerDark = RGB(0x554619)
}

/// 九个生活领域的颜色（规范 01 第 3.1 节）：实色、浅底、文字，亮暗各一
public enum PourDomain: String, CaseIterable, Sendable {
    /// 石
    case stone
    /// 陶
    case clay
    /// 杏
    case apricot
    /// 麦
    case straw
    /// 苔
    case moss
    /// 湖
    case lake
    /// 藤
    case wisteria
    /// 樱
    case sakura
    /// 砖
    case brick

    public var palette: DomainPalette {
        switch self {
        case .stone:
            DomainPalette(
                name: "石",
                solidLight: RGB(0x88847D), solidDark: RGB(0xABA7A0),
                bgLight: RGB(0xF1F0EE), bgDark: RGB(0x2C2B29),
                textLight: RGB(0x524F4A), textDark: RGB(0xD3D1CC))
        case .clay:
            DomainPalette(
                name: "陶",
                solidLight: RGB(0xA37A64), solidDark: RGB(0xC69E88),
                bgLight: RGB(0xF8EEE8), bgDark: RGB(0x342822),
                textLight: RGB(0x674836), textDark: RGB(0xE4CBBE))
        case .apricot:
            DomainPalette(
                name: "杏",
                solidLight: RGB(0xB57343), solidDark: RGB(0xD89769),
                bgLight: RGB(0xFDEDE2), bgDark: RGB(0x3A2619),
                textLight: RGB(0x744118), textDark: RGB(0xF0C8AE))
        case .straw:
            DomainPalette(
                name: "麦",
                solidLight: RGB(0x9C813B), solidDark: RGB(0xBFA563),
                bgLight: RGB(0xF6F0E1), bgDark: RGB(0x322A18),
                textLight: RGB(0x624D0F), textDark: RGB(0xDFD0AB))
        case .moss:
            DomainPalette(
                name: "苔",
                solidLight: RGB(0x63926D), solidDark: RGB(0x88B590),
                bgLight: RGB(0xE9F3EA), bgDark: RGB(0x222F24),
                textLight: RGB(0x355A3D), textDark: RGB(0xBFD9C3))
        case .lake:
            DomainPalette(
                name: "湖",
                solidLight: RGB(0x5A8AB2), solidDark: RGB(0x7FADD5),
                bgLight: RGB(0xE7F2FC), bgDark: RGB(0x202D39),
                textLight: RGB(0x2D5373), textDark: RGB(0xBAD5ED))
        case .wisteria:
            DomainPalette(
                name: "藤",
                solidLight: RGB(0x8C7AAE), solidDark: RGB(0xAF9DD1),
                bgLight: RGB(0xF2EEFB), bgDark: RGB(0x2D2837),
                textLight: RGB(0x564770), textDark: RGB(0xD5CBEA))
        case .sakura:
            DomainPalette(
                name: "樱",
                solidLight: RGB(0xAB7087), solidDark: RGB(0xCF94AA),
                bgLight: RGB(0xFBECF1), bgDark: RGB(0x37262C),
                textLight: RGB(0x6D3F52), textDark: RGB(0xEAC6D2))
        case .brick:
            DomainPalette(
                name: "砖",
                solidLight: RGB(0xB96D60), solidDark: RGB(0xDD9184),
                bgLight: RGB(0xFFEBE7), bgDark: RGB(0x3B2521),
                textLight: RGB(0x783C33), textDark: RGB(0xF3C4BC))
        }
    }
}
