import PourAPI
import PourDesign
import SwiftUI

/// 类别的图标（docs/模块/生活画布2.0.md 4.7）：预置的类别和领域用苹果的线条图标；
/// AI 新长出来的类别（冥想、钓鱼……）没有对应的，用它自己的 emoji——emoji 没法一一对应，硬换会错
enum CategoryIcon {
    /// 按类别的 key（预置的几个 key 是固定的）
    static let byKey: [String: String] = [
        "sleep": "moon.zzz", "exercise": "figure.run", "diet": "fork.knife", "study": "book",
        "work": "briefcase", "other": "pin", "insight": "lightbulb", "todo": "checklist", "mood": "heart",
        CanvasPlan.moneyKey: "yensign.circle",
    ]

    /// 按名称（十个生活领域和运动的子类别是程序按名字建的，key 每个人不一样）
    static let byName: [String: String] = [
        "睡眠": "moon.zzz", "运动": "figure.run", "饮食": "fork.knife", "学习": "book", "工作": "briefcase",
        "其他": "pin", "感悟": "lightbulb", "待办": "checklist", "心情": "heart",
        "育儿": "figure.and.child.holdinghands", "宠物": "pawprint", "健康": "cross.case", "家人朋友": "person.2",
        "兴趣": "paintpalette", "娱乐": "film", "家务": "house", "出行": "car", "购物": "bag", "办事": "doc.text",
        "跑步": "figure.run", "力量": "dumbbell", "瑜伽": "figure.yoga",
    ]

    /// 这个类别用哪个线条图标；nil 就用它的 emoji
    static func symbol(key: String, name: String) -> String? {
        byKey[key] ?? byName[name]
    }

    /// 一张卡的图标小方块
    @MainActor static func tile(_ key: String, _ categories: [API.Category]) -> IconTile {
        let meta = CanvasPlan.meta(key, categories)
        return IconTile(symbol: symbol(key: key, name: meta.name), emoji: meta.emoji, color: Theme.tag(meta.color))
    }
}
