import SwiftUI

/// 心情分析（下一层，06 交互细节 10.1）：现在先放以前「关于我 → 心情」那一页，第 4 步后半换成新的样子
struct MoodAnalysisPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        AboutMoodView { model.open($0) }
    }
}

/// 好时刻（全部）：现在先放笔记库的「好时刻」，第 4 步后半换成按月分组的新样子
struct MoodMomentsPage: View {
    var body: some View {
        LibraryPage(ask: LibraryAsk(view: "moments"))
    }
}
