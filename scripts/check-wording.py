#!/usr/bin/env python3
"""文案检查（docs/归档/设计规范/10-文案与格式.md 第 4 节）：界面上的字里不许有责备、催促、夸张讨好、诊断、因果的说法，
不许有感叹号。查 Swift 代码里的字符串（注释不查）和 String Catalog；用户的原话（样张数据）不查——原话原样。
每次先自检一遍规则还拦得住已知的坏例子。用法：python3 scripts/check-wording.py；check.sh 每次都跑
"""
import json, re, subprocess, sys
from pathlib import Path

BANNED = {
    "责备": ["又没", "断了", "没坚持", "偷懒", "又忘了", "怎么又", "懈怠", "半途而废", "掉链子"],
    "催促": ["赶紧", "快去", "别忘了", "记得要"],
    "夸张、讨好": ["太棒了", "恭喜", "厉害", "超级", "最强", "亲", "宝"],
    "诊断": ["焦虑症", "抑郁", "失眠症", "强迫"],
    "因果": ["因为", "导致", "造成", "所以才", "使得"],
    "标点": ["！"],
}
# 例外：规范 10 第 5 节的固定文案「网络断了」是说网络，不是责备。
# 原来就有的两句（产品主人 2026-10-19：界面 1 比 1 照原来的样子）：「不会因为连不上而丢失」说的是程序怎么存原话、
# 不是对人下因果判断；「pro · 最强」说的是模型，不是夸人
ALLOWED = ["网络断了", "不会因为连不上而丢失", "pro · 最强"]
STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"')


def strings_in_swift(text):
    """一行一行找字符串；字符串外面的 // 后面是注释，不查"""
    for number, line in enumerate(text.splitlines(), 1):
        position = 0
        while True:
            literal = STRING.search(line, position)
            comment = line.find("//", position)
            if comment != -1 and (literal is None or comment < literal.start()):
                break
            if literal is None:
                break
            yield number, literal.group()[1:-1]
            position = literal.end()


def problems(text):
    for allowed in ALLOWED:
        text = text.replace(allowed, "")
    return [f"{kind}「{word}」" for kind, words in BANNED.items() for word in words if word in text]


def self_test():
    assert problems("你又没记") and problems("太棒了！") and problems("因为加班所以累"), "规则拦不住已知的坏例子"
    assert not problems("没整理成：网络断了。联网后会自动再试"), "误拦固定文案"
    found = list(strings_in_swift('Text("好") // 因为注释不查\nlet a = "这是 // 不是注释"'))
    assert found == [(1, "好"), (2, "这是 // 不是注释")], f"字符串找错了：{found}"


def main():
    self_test()
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "App", "Gallery",
                            "Packages/PourKit/Sources"], cwd=root, capture_output=True, text=True, check=True).stdout
    found = []
    for name in filter(None, files.split("\0")):
        path = root / name
        if name.endswith(".swift"):
            for number, literal in strings_in_swift(path.read_text(encoding="utf-8")):
                found += [f"{name}:{number}  {p}：{literal[:40]}" for p in problems(literal)]
        elif name.endswith(".xcstrings"):
            catalog = json.loads(path.read_text(encoding="utf-8"))
            for key in catalog.get("strings", {}):
                found += [f"{name}  {p}：{key[:40]}" for p in problems(key)]
    if found:
        print(f"文案里有 {len(found)} 处不许用的说法（规范 10 第 4 节）：")
        print("\n".join(f"  {line}" for line in found))
        sys.exit(1)
    print("文案检查通过：界面上的字里没有责备、催促、夸张、诊断、因果的说法和感叹号。")


if __name__ == "__main__":
    main()
