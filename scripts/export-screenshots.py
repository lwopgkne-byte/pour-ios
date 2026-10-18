#!/usr/bin/env python3
"""把测试结果（.xcresult）里每一屏的截图导出成好认的文件名：<输出目录>/样张-today-暗色-第2屏.png
用法：python3 scripts/export-screenshots.py <结果.xcresult> <输出目录>
"""
import json, os, re, shutil, subprocess, sys, tempfile

result, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
with tempfile.TemporaryDirectory() as raw:
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", raw],
                   check=True, capture_output=True)
    with open(os.path.join(raw, "manifest.json")) as f:
        manifest = json.load(f)
    count = 0
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.endswith(".png"):
                continue
            # 「样张-today-暗色-第2屏_0_<编号>.png」→「样张-today-暗色-第2屏.png」
            clean = re.sub(r"_\d+_[0-9A-F-]{36}(?=\.png$)", "", name)
            # 同名的（比如测试失败时系统自动截的「App Screenshot」）加上测试名和序号，不互相覆盖
            target, n = os.path.join(out, clean), 1
            while os.path.exists(target):
                n += 1
                test_name = re.sub(r"\W+", "", test.get("testIdentifier", "").split("/")[-1])
                target = os.path.join(out, f"{clean[:-4]}-{test_name}-{n}.png")
            shutil.copyfile(os.path.join(raw, attachment["exportedFileName"]), target)
            count += 1
print(f"  截图 {count} 张 → {out}")
