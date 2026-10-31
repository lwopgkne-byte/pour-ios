import Foundation
import PourAPI

// MARK: - 钱（3.0 第 3 步，docs/3.0/01-需求文档.md 第 5 章）

extension AppModel {
    /// 记一笔（钱主页的圆按钮、「我的」的快捷、画布钱卡的「＋ 记一笔」、按住图标）
    func recordMoney() {
        startSaying("/记 ")
    }
}
