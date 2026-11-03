#!/usr/bin/env python3
"""依赖方向检查（docs/归档/03-架构与开发方案.md 第 6.1 节、ADR A18）。

编译器已经保证「没声明的依赖用不了」；这里再保证「声明的依赖本身是对的」：
  - 每一层只依赖 6.1 节表里允许的层
  - 功能包（Feature 开头）之间不互相依赖
  - 没有写进 ADR 的第三方库

用法：python3 scripts/check-deps.py   （scripts/check.sh 会自动跑）
"""
import json
import pathlib
import subprocess
import sys

PACKAGE = pathlib.Path(__file__).resolve().parent.parent / "Packages" / "PourKit"

# 6.1 节：每一层能依赖哪些层
ALLOWED = {
    "PourCore": set(),
    "PourDesign": set(),
    "PourPlatform": {"PourCore"},
    # 服务器的接口（产品主人 2026-10-19 选 B）：日期换算用 PourCore 的
    "PourAPI": {"PourCore"},
}
LAYERS = set(ALLOWED)

# 写进了 ADR 的第三方库（包的身份 → ADR 编号）。加一个库：先写 ADR，再加到这里
# （3.0 第 0 步删掉了第一阶段的本机数据库和它用的第三方库，现在一个都没有）
APPROVED_THIRD_PARTY: dict[str, str] = {}


def target_deps(target: dict) -> set[str]:
    names = set()
    for dep in target.get("dependencies", []):
        for kind in ("byName", "target", "product"):
            if kind in dep:
                names.add(dep[kind][0])
    return names


def check(manifest: dict) -> list[str]:
    problems = []
    for package in manifest.get("dependencies", []):
        identity = next(iter(package.values()))[0].get("identity", "?")
        if identity not in APPROVED_THIRD_PARTY:
            problems.append(f"第三方库 {identity} 没有写进 ADR（A18：每个第三方库先写 ADR）")

    for target in manifest["targets"]:
        name, kind = target["name"], target["type"]
        if kind == "test":
            continue
        deps = target_deps(target)
        if name in ALLOWED:
            for dep in sorted(deps - ALLOWED[name]):
                problems.append(f"{name} 不能依赖 {dep}（6.1 节：{name} 只能依赖 {sorted(ALLOWED[name]) or '系统框架'}）")
        elif name.startswith("Feature"):
            for dep in sorted(d for d in deps if d.startswith("Feature")):
                problems.append(f"功能包 {name} 不能依赖另一个功能包 {dep}")
            for dep in sorted(d for d in deps if not d.startswith("Feature") and d not in LAYERS):
                problems.append(f"功能包 {name} 依赖了不认识的 {dep}")
        else:
            problems.append(f"{name} 不在 6.1 节的分层表里：新的层先改方案，功能包用 Feature 开头")
    return problems


def main() -> int:
    if len(sys.argv) > 1:  # 测试用：直接读一份清单
        manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
    else:
        out = subprocess.run(
            ["swift", "package", "dump-package"], cwd=PACKAGE, capture_output=True, text=True, check=True
        ).stdout
        manifest = json.loads(out)
    problems = check(manifest)
    if problems:
        print("依赖方向检查没通过：")
        for p in problems:
            print("  ✗", p)
        return 1
    names = [t["name"] for t in manifest["targets"] if t["type"] != "test"]
    libraries = "、".join(f"{name}（{adr}）" for name, adr in sorted(APPROVED_THIRD_PARTY.items())) or "没有"
    print(f"依赖方向检查通过：{len(names)} 个包（{', '.join(names)}）；第三方库：{libraries}。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
