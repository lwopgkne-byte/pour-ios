import Foundation
import PourAPI

// MARK: - 「说到的」里的名字：改名字、不再显示（docs/模块/产品优化.md R2）

extension AppModel {
    /// 改名字：以后都按对的名字算（改成已经有的名字就是合成一个）；轻提示上能撤销
    func renameMention(kind: String, name: String, to canonical: String) {
        let target = canonical.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, target != name else { return }
        act { client in try await client.rename(kind: kind, name: name, to: target) }
        toast("以后都算「\(target)」", action: "撤销") { [weak self] in
            self?.act { client in try await client.forgetName(kind: kind, name: name) }
        }
    }

    /// 不再显示：画布和关于我里不出现，原话和记录不动；轻提示上能撤销，关于我里也能恢复
    func hideMention(kind: String, name: String) {
        act { client in try await client.hideName(kind: kind, name: name) }
        toast("「\(name)」不再显示", action: "撤销") { [weak self] in
            self?.act { client in try await client.hideName(kind: kind, name: name, false) }
        }
    }
}
