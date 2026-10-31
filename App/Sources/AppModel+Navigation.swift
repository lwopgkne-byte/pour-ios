import Foundation

// MARK: - 3.0 外壳的导航（docs/3.0/01-需求文档.md 2.5）：一个导航栈，根是生活画布

extension AppModel {
    /// 打开对话、填好开头（「我的」的四个快捷、画布卡片右上角的「＋ 记一笔」「记心情」「＋」）：
    /// 第 1 步先这样接，第 2–5 步换成加待办、记一笔、记心情、记一句的正式弹层
    func startSaying(_ start: String) {
        chatOpen = true
        compose(start)
    }

    /// 打开一个页面地址（对话里的回顾、周报月报链接，页面里互相跳）：推进来一页；同一种页面里翻页（上一天、下个月）
    /// 换掉最上面那一页；「/」回到画布。收起对话和搜索
    func open(_ path: String) {
        chatOpen = false
        search = nil
        guard path != "/" else {
            goHome()
            return
        }
        guard let route = Route(path: path) else { return }
        if let below = stack.dropLast().lastIndex(of: route) {
            // 要去的那一页就在下面（页面里的「每日回顾」回到列表、从一天的钱回到这个月）：退回去，不再推一个一样的
            stack.removeSubrange((below + 1)...)
        } else if let top = stack.last, top.sameKind(as: route) {
            stack[stack.count - 1] = route
        } else {
            stack.append(route)
        }
    }

    /// 从 App 外面打开（pour://open?path=、推送、小组件）：画布在最底下，只推这一页，返回就回到画布
    func openLink(_ path: String) {
        chatOpen = false
        search = nil
        stack = Route(path: path).map { [$0] } ?? []
    }

    /// 说一句的那一页（docs/3.0/01-需求文档.md 2.2）：发出去带上，意图识别作参考；输入框的提示跟着变。在画布上是 nil
    var sayContext: String? {
        switch stack.last {
        case .money?: "money"
        case .goals?: "goals"
        case .about(.mood, _)?: "mood"
        case .library(let ask)? where ask.view == "insights": "insights"
        default: nil
        }
    }

    /// 回到画布（返回到底）
    func goHome() {
        stack = []
    }

    /// 回到画布、打开「跳到某一天」（3.0 的日历页第 10 步做，先用它）
    func pickDay() {
        goHome()
        dayPickerRequest += 1
    }
}
