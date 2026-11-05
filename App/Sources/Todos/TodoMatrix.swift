import PourAPI
import PourDesign
import SwiftUI

/// 四象限（待办 2.0 第 7 步做）：这一步先占着位置
struct TodoMatrixSection: View {
    let page: API.TodoPage
    let now: String

    var body: some View {
        Section {
            Text("四象限下一步做好").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .listRowBackground(Color.clear)
        }
    }
}
