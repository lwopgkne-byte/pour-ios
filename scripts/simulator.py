#!/usr/bin/env python3
"""找（没有就建）一台专用模拟器，打印它的编号。
用法：python3 ios/scripts/simulator.py <名字前缀> <机型，如 "iPhone 17 Pro"> [系统大版本，如 26]
系统：这个机型支持的最新的 iOS（给了大版本就只在这个版本里找）。机型这台电脑没有，就用第一个能用的 iPhone。
"""
import json, subprocess, sys

def simctl(*args):
    return json.loads(subprocess.run(["xcrun", "simctl", "list", "-j", *args], capture_output=True, text=True, check=True).stdout)

prefix, wanted = sys.argv[1], sys.argv[2]
major = sys.argv[3] if len(sys.argv) > 3 else None
runtimes = [r for r in simctl("runtimes")["runtimes"] if r["isAvailable"] and r["platform"] == "iOS"
            and (major is None or r["version"].split(".")[0] == major)]
runtimes.sort(key=lambda r: [int(x) for x in r["version"].split(".")], reverse=True)
choice = None
for r in runtimes:
    phones = [t for t in r.get("supportedDeviceTypes", []) if t["name"].startswith("iPhone")]
    match = next((t for t in phones if t["name"] == wanted), None)
    if match or (phones and choice is None):
        choice = (r, match or phones[0])
        if match:
            break
if not choice:
    sys.exit("没有可用的 iOS 模拟器系统：在 Xcode → 设置 → Components 里装一个")
runtime, device_type = choice
name = f"{prefix}（{device_type['name']} · iOS {runtime['version']}）"
devices = simctl("devices")["devices"].get(runtime["identifier"], [])
found = next((d for d in devices if d["name"] == name and d["isAvailable"]), None)
udid = found["udid"] if found else subprocess.run(
    ["xcrun", "simctl", "create", name, device_type["identifier"], runtime["identifier"]],
    capture_output=True, text=True, check=True).stdout.strip()
print(udid, name, sep="\t")
