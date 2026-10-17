/// 颜色的语义令牌（docs/设计规范/01-颜色.md 第 2 节）。
///
/// M0 只放启动页用得到的几个；M1 把规范 01 的全部令牌落进来、由 `scripts/palette.py` 生成、
/// 产品主人在真机样张上拍板 D10 后锁定为令牌 v1。改色值只改这里，界面代码只用令牌名。
public enum PourColor {
    /// 纸：页面底色
    public static let canvas = ColorToken(light: RGB(0xF6F4F0), dark: RGB(0x0C0B0A))
    /// 墨：正文、标题
    public static let ink = ColorToken(light: RGB(0x161513), dark: RGB(0xF6F4F0))
    /// 淡墨：次要信息（日期、说明、单位）
    public static let inkSecondary = ColorToken(light: RGB(0x575552), dark: RGB(0xBCBAB6))
    /// 青：只表示「它懂你」；启动页的品牌标志在规范的使用清单里（01 第 2.4 节第 6 条）
    public static let qing = ColorToken(light: RGB(0x067976), dark: RGB(0x7FCAC7))
}
