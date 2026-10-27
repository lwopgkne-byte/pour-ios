#if DEBUG
    import Foundation
    import PourCore

    /// 假服务器的演示日程（docs/模块/演示数据.md，服务器的 server/src/data/demo-calendar.ts）：
    /// 今天有全天的结婚纪念日、10:00 给客户回电话；别的日子是每周固定的会（这里只放周一的周会）
    extension StubServer.State {
        static func demoCalendar(_ day: String, today: String) -> [String: Any] {
            var items: [[String: Any]] = []
            if day == today {
                items.append([
                    "id": "anniversary-\(day)", "title": "结婚纪念日", "start": "\(day)T00:00",
                    "end": "\(PourDate.addDays(day, 1))T00:00", "allDay": true, "calendar": "纪念日",
                ])
                items.append([
                    "id": "client-call-\(day)", "title": "给客户回电话", "start": "\(day)T10:00", "end": "\(day)T10:15",
                    "allDay": false, "calendar": "工作",
                ])
            }
            if PourDate.weekdayMon0(day) == 0 {
                items.append([
                    "id": "weekly-\(day)", "title": "周会", "start": "\(day)T10:00", "end": "\(day)T11:00",
                    "allDay": false, "calendar": "工作",
                ])
            }
            return ["day": day, "items": items]
        }
    }
#endif
