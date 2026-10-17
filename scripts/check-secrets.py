#!/usr/bin/env python3
"""密钥检查：要进 Git 的文件里不能有证书、密钥、描述文件、本机配置（docs/ios/07-代码管理与发布.md 第 1 节）。
查的是「已提交的 + 新建还没被 .gitignore 排除的」文件，也就是 git add -A 会带上的那些。
每次先自检一遍规则还拦得住已知的坏例子。用法：python3 scripts/check-secrets.py [目录]（默认当前目录）
"""
import re, subprocess, sys
from pathlib import Path

# 永远不能进 Git 的文件
FORBIDDEN_PATHS = [
    ("苹果的证书和密钥（.p8 .p12 .mobileprovision）", re.compile(r"\.(p8|p12|mobileprovision)$", re.I)),
    ("本机的密钥配置 Secrets.xcconfig", re.compile(r"(^|/)Secrets\.xcconfig$")),
    ("本机的签名配置 Local.xcconfig（bootstrap.sh 生成）", re.compile(r"(^|/)Local\.xcconfig$")),
    (".env（只能提交 .env.example）", re.compile(r"(^|/)\.env(\.[^/]*)?$")),
]
ALLOWED = re.compile(r"(^|/)\.env\.example$")
# 内容里像真密钥的东西（文档里的 sk-... 这种示意不算）
SECRET_PATTERNS = [
    ("大模型密钥（sk-…）", re.compile(r"\bsk-[A-Za-z0-9]{24,}")),
    ("GitHub 令牌", re.compile(r"\b(ghp|gho|ghu|ghs)_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}")),
    ("私钥", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
]
BINARY = re.compile(r"\.(png|jpe?g|gif|ico|webp|heic|pdf|zip|car|ttf|otf|woff2?|bin|mlmodel|xcresult)$", re.I)


def path_leaks(path):
    if ALLOWED.search(path):
        return []
    return [rule for rule, pattern in FORBIDDEN_PATHS if pattern.search(path)]


def content_leaks(text):
    return [(number, rule) for number, line in enumerate(text.splitlines(), 1)
            for rule, pattern in SECRET_PATTERNS if pattern.search(line)]


def self_test():
    """规则还拦得住已知的坏例子、不误拦正常文件（坏例子拼起来写，免得这个文件自己被拦）"""
    for bad in ["AuthKey_ABC123.p8", "dist.p12", "X.P12", "Pour_Dev.mobileprovision", "Config/Secrets.xcconfig",
                "Config/Local.xcconfig", ".env", ".env.local"]:
        assert path_leaks(bad), f"规则拦不住 {bad}"
    for good in ["Config/Base.xcconfig", "project.yml", ".env.example", "App/Sources/PourApp.swift"]:
        assert not path_leaks(good), f"规则误拦 {good}"
    assert content_leaks("-----BEGIN " + "EC PRIVATE KEY-----"), "拦不住私钥"
    assert content_leaks("token = ghp_" + "a" * 36), "拦不住 GitHub 令牌"
    assert not content_leaks("密钥长这样：sk-...（示意）"), "误拦文档里的示意"


def main():
    self_test()
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "."],
                           cwd=root, capture_output=True, text=True, check=True).stdout.split("\0")
    leaks = []
    for name in filter(None, files):
        leaks += [f"{name}  {rule}" for rule in path_leaks(name)]
        file = root / name
        if BINARY.search(name) or not file.is_file():
            continue
        text = file.read_text(encoding="utf-8", errors="ignore")
        leaks += [f"{name}:{number}  {rule}" for number, rule in content_leaks(text)]
    if leaks:
        print(f"发现 {len(leaks)} 处不能进 Git 的东西：")
        print("\n".join(f"  {leak}" for leak in leaks))
        print("把它移出仓库（或加进 .gitignore）；已经提交过的密钥要去发放的地方作废、重新生成。")
        sys.exit(1)
    print("密钥检查通过：要进 Git 的文件里没有证书、密钥和本机配置。")


if __name__ == "__main__":
    main()
