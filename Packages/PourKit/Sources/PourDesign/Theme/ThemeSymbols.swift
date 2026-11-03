/// 3.0 每个功能用哪个 SF Symbol（docs/3.0/06-交互细节.md 第 8 节的对照表）：页面只用这里的名字，换图标只改这一处。
/// 选中、填满的样子用 `.fill`；功能格子是白色填充图标放在彩色圆角方块里（HubTileIcon）
extension Theme {
    public enum Symbol {
        // 画布顶上、卡片上的加
        public static let search = "magnifyingglass"
        public static let dayMenu = "chevron.down"
        public static let add = "plus"

        // 记录
        public static let todos = "checklist"
        public static let money = "yensign.circle.fill"
        public static let mood = "face.smiling.inverse"
        public static let insights = "lightbulb.fill"
        public static let health = "heart.text.square.fill"

        // 说一句
        public static let chat = "bubble.left.and.bubble.right"
        public static let mic = "mic.fill"
        public static let send = "arrow.up.circle.fill"

        // 回看、了解自己
        public static let review = "book.fill"
        public static let calendar = "calendar"
        public static let library = "doc.text.fill"
        public static let moments = "sparkles"
        public static let year = "calendar.badge.clock"
        public static let about = "person.fill"
        public static let people = "person.2.fill"
        public static let talk = "waveform.and.mic"
        public static let finds = "chart.line.uptrend.xyaxis"

        // 钱
        public static let moneyList = "list.bullet.rectangle.fill"
        public static let watch = "tray.full.fill"
        public static let fixed = "pin.fill"
        public static let renqing = "gift.fill"
        public static let worth = "hand.thumbsup.fill"

        // 目标
        public static let goals = "flag.fill"
        public static let streak = "flame.fill"
        public static let budget = "chart.pie.fill"

        // 一行上的操作
        public static let snooze = "clock.arrow.circlepath"
        public static let repeats = "repeat"
        public static let remind = "bell.fill"
        public static let delete = "trash.fill"
        public static let done = "checkmark"

        // 类别（饮食 · 购物 · 家人朋友 · 宠物 · 娱乐 · 出行 · 办事）
        public static let diet = "fork.knife"
        public static let shopping = "bag.fill"
        public static let family = "person.3.fill"
        public static let pets = "pawprint.fill"
        public static let fun = "film.fill"
        public static let transport = "car.fill"
        public static let errands = "doc.fill"

        // 设置里的页
        public static let settings = "gearshape.fill"
        public static let notifications = "bell.badge.fill"
        public static let categories = "square.grid.2x2.fill"
        public static let data = "externaldrive.fill"
        public static let computer = "desktopcomputer"
        public static let model = "cpu"
        public static let accuracy = "checkmark.seal.fill"
        public static let widgets = "square.grid.3x3.fill"
        public static let privacy = "lock.fill"
    }
}
