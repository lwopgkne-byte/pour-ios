import PourCore
import PourDesign
import SwiftUI

/// 底部的输入框（网页版 Composer 手机那一档 1 比 1）：浅底色的圆角框贴着屏幕底部；
/// 发出去就向上展开成半屏的对话面板，右边的按钮收起、展开；键盘的换行键换行，右边的蓝按钮发送
struct Composer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.visibleHeight) private var visibleHeight
    @FocusState private var focused: Bool
    @State private var drag: CGFloat = 0

    var body: some View {
        @Bindable var model = model
        let open = model.chatOpen
        VStack(spacing: 0) {
            if open {
                ChatPanel(drag: $drag)
                    .frame(height: visibleHeight * 0.55)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .bottom, spacing: Web.space2) {
                TextField(placeholder, text: $model.draft, axis: .vertical)
                    .font(Web.body)
                    .foregroundStyle(Web.fg)
                    .lineLimit(1...6)
                    .padding(.vertical, Web.space2)
                    .focused($focused)
                    .accessibilityLabel(Text("说说今天"))
                    .accessibilityIdentifier("pourbar.input")
                Button {
                    withAnimation(Web.panel) { model.chatOpen.toggle() }
                } label: {
                    Image(systemName: open ? "chevron.down" : "bubble.left")
                        .font(Web.section).foregroundStyle(Web.fgSecondary)
                        .frame(width: Web.touch, height: Web.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(open ? "收起对话" : "展开对话"))
                .accessibilityIdentifier("pourbar.chat")
                let empty = model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    withAnimation(Web.panel) { model.send() }
                } label: {
                    Image(systemName: "arrow.up").font(Web.section.weight(.semibold)).foregroundStyle(Web.onAccent)
                        .frame(width: Web.touch, height: Web.touch)
                        .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.accent))
                        .contentShape(Rectangle())
                        .opacity(empty ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(empty)
                .accessibilityLabel(Text("发送"))
                .accessibilityIdentifier("pourbar.send")
            }
            .padding(.leading, open ? Web.space4 : Web.space3)
            .padding([.trailing, .vertical], open ? Web.space2 : Web.space1)
            .background(open ? Web.bg : Web.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: open ? 0 : Web.radiusPanel))
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Web.radiusPanel, topTrailingRadius: Web.radiusPanel))
        .offset(y: max(0, drag))
        .padding(.horizontal, open ? 0 : Web.space3)
        .padding(.top, open ? 0 : Web.space2)
        .padding(.bottom, open ? 0 : Web.space2)
        // 收起对话是要看画布：键盘一起收起来
        .onChange(of: model.chatOpen) { _, open in
            if !open { focused = false }
        }
        .background {
            Web.bg.ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { if !open { Rectangle().fill(Web.line).frame(height: 1) } }
        }
    }

    /// 白天问做了什么；晚上（6 点到日界线）换成「今天哪一刻觉得挺好？」
    private var placeholder: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < PourDate.defaultBoundary / 60 ? "今天哪一刻觉得挺好？" : "今天做了什么？比如：跑步1小时"
    }
}
