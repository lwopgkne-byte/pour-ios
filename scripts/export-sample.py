#!/usr/bin/env python3
"""样张用的示例数据（M1）：网页版演示数据里那个人真实的一天，不是编的。

做法：在临时目录起一个隔离的网页版服务（切到演示数据，不碰 data/），从它自己的接口取「一天」「钱」
「关于我」「回顾」，整理成画廊 App 用的一份小文件 ios/Gallery/Resources/Sample.json。

用法：python3 ios/scripts/export-sample.py [日子，默认昨天]
"""
import datetime
import json
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "ios" / "Gallery" / "Resources" / "Sample.json"
PORT = 5297

# 网页版的生活领域 → iOS 的九个领域色（规范 01 第 3.1 节的「默认给」；表里没有的四个是 M1 定的，见 M1 自验收）
DOMAIN_OF = {
    "其他": "stone", "家务": "clay", "饮食": "apricot", "学习": "straw", "运动": "moss",
    "工作": "lake", "出行": "lake", "睡眠": "wisteria", "娱乐": "wisteria",
    "家人朋友": "sakura", "育儿": "sakura", "健康": "brick",
    "购物": "clay", "宠物": "moss", "兴趣": "wisteria", "办事": "stone", "冥想": "wisteria",
}
WEEKDAYS = "一二三四五六日"


def fetch(path):
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/api/{path}", timeout=30) as r:
        return json.load(r)


def start_server(data_dir):
    (data_dir / "mode.json").write_text('{"mode":"demo"}')
    env = dict(os.environ, POUR_DATA_DIR=str(data_dir), PORT=str(PORT), TZ="Asia/Shanghai")
    proc = subprocess.Popen(
        ["fnm", "exec", "--using=24", "npx", "tsx", "server/src/index.ts"], cwd=ROOT, env=env,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(90):
        try:
            fetch("meta")
            return proc
        except Exception:
            time.sleep(1)
    os.killpg(proc.pid, signal.SIGTERM)
    sys.exit("网页版服务没起来")


def hhmm(iso):
    return iso[11:16] if iso and len(iso) >= 16 else None


def yuan(v):
    return f"¥{v:,.0f}" if float(v).is_integer() else f"¥{v:,.2f}"


def duration(m):
    h, r = divmod(int(m), 60)
    return f"{r} 分钟" if h == 0 else (f"{h} 小时" if r == 0 else f"{h} 小时 {r} 分")


def build(day):
    cats = fetch("categories")
    cats = cats if isinstance(cats, list) else cats.get("categories", cats)
    by_key = {c["key"]: c for c in cats}

    def domain_name(key):
        c = by_key.get(key)
        while c and c.get("parent"):
            c = by_key.get(c["parent"])
        return c["name"] if c else "其他"

    d = fetch(f"day/{day}")
    timeline, skipped, receipt = [], [], None
    for e in d["entries"]:
        data = e["data"]
        src = e["sources"][0]["text"] if e.get("sources") else ""
        start = data.get("start")
        if start and not start.startswith(day) and e["kind"] == "event" and data.get("label") != "睡觉":
            # 网页版演示数据的一个毛病：这一天的事，开始时间落到了第二天（产品主人说网页版不修，样张里先不放）
            skipped.append(f"{data.get('label')}（开始时间 {start}）")
            continue
        item = {"quote": src, "kind": e["kind"], "time": hhmm(start)}
        if e["kind"] == "event":
            name = domain_name(e["category"])
            money = [m for m in data.get("metrics", []) if m.get("unit") == "元"]
            other = [m for m in data.get("metrics", []) if m.get("unit") != "元"]
            value = yuan(money[0]["value"]) if money else (
                duration(data["durationMin"]) if data.get("durationMin") else
                (f"{other[0]['value']} {other[0]['unit']}" if other else None))
            item.update(domain=DOMAIN_OF.get(name, "stone"), domainName=name, title=data["label"],
                        value=value, person=(data.get("people") or [None])[0])
        elif e["kind"] == "mood":
            item.update(level=data["mood"], feeling="、".join(data.get("emotions", [])) or None,
                        moment=data.get("moment"))
        elif e["kind"] == "todo":
            item.update(title=data["content"], done=data.get("done", False), due=data.get("due"))
        else:
            item.update(title=data.get("title") or data.get("label") or "")
        timeline.append(item)

    # 收据：这一天整理出最多几件事的那一段话
    groups = {}
    for item in timeline:
        if item["kind"] == "event":
            groups.setdefault(item["quote"], []).append(item)
    if groups:
        quote, lines = max(groups.items(), key=lambda kv: len(kv[1]))
        receipt = {"quote": quote, "lines": [
            {"domain": x["domain"], "title": x["title"], "person": x["person"], "value": x["value"]} for x in lines]}

    reviews = fetch(f"review?date={day}")["items"]
    daily = next((r for r in reviews if r.get("day") == day and r["kind"] == "daily"), None)
    dt = datetime.date.fromisoformat(day)

    m = fetch(f"money/{day[:7]}")
    first = datetime.date.fromisoformat(m["from"])
    spent = {x["day"]: x["spent"] for x in m["days"]}
    last_day = (datetime.date(first.year + first.month // 12, first.month % 12 + 1, 1) - datetime.timedelta(days=1)).day
    calendar = [spent.get(f"{day[:7]}-{i:02d}") if f"{day[:7]}-{i:02d}" <= m["to"] else None for i in range(1, last_day + 1)]

    a = fetch("about/home")
    comp = a["composition"]
    money_angle = next((x for x in a["angles"] if x["key"] == "money"), None)
    finding = a["findings"][0] if a.get("findings") else None

    return {
        "说明": "M1 样张的示例数据：网页版演示数据（9 周的那个人）在这一天的真实内容，由 ios/scripts/export-sample.py 生成，不要手改",
        "day": day,
        "today": {
            "title": f"{dt.month}月{dt.day}日",
            "weekday": f"周{WEEKDAYS[dt.weekday()]}",
            "summary": daily["summary"] if daily else "",
            "goals": [{"name": g["title"], "fraction": min(g["pct"], 1), "headline": g["headline"],
                       "behind": g["tone"] == "warn", "domain": DOMAIN_OF.get(domain_name(g["category"]), "stone")}
                      for g in (d.get("goals") or [])][:3],
            "timeline": timeline,
            "skipped": skipped,
        },
        "receipt": receipt,
        "money": {
            "month": f"{int(day[5:7])}月",
            "spent": yuan(m["spent"]),
            "count": m["count"],
            "compare": (m.get("compare") or {}).get("text"),
            "firstWeekday": first.weekday(),
            "today": int(m["today"][8:]) if m["today"][:7] == day[:7] else None,
            "calendar": calendar,
            "domains": [{"name": x["name"], "domain": DOMAIN_OF.get(x["name"], "stone"), "amount": yuan(x["amount"])}
                        for x in m["domains"][:5]],
            "watch": [{"name": w["name"], "amount": yuan(w["amount"]), "sub": w["sub"]} for w in fetch("money/overview")["watch"]],
        },
        "about": {
            "caption": a["caption"],
            "tiles": [{"name": t["name"], "domain": DOMAIN_OF.get(t["name"], "stone"), "notes": t["notes"]}
                      for t in comp["tiles"] + comp.get("later", [])],
            "finding": finding and {
                "sentence": finding["sentence"], "these": finding["bars"][0]["share"], "others": finding["bars"][1]["share"],
                "basis": f"{finding['bars'][0]['value']} · {finding['bars'][1]['value']}"},
            "moneyAngle": money_angle and {"big": money_angle["big"], "sub": money_angle["sub"], "week": money_angle["week"]},
        },
        "review": [{"title": r["title"], "summary": r["summary"], "kind": r["kind"]} for r in reviews[:6]],
    }


def main():
    day = sys.argv[1] if len(sys.argv) > 1 else (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="pour-sample-"))
    proc = start_server(tmp)
    try:
        sample = build(day)
    finally:
        os.killpg(proc.pid, signal.SIGTERM)
        shutil.rmtree(tmp, ignore_errors=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(sample, ensure_ascii=False, indent=1) + "\n")
    print(f"已生成 {OUT.relative_to(ROOT)}：{day}，时间轴 {len(sample['today']['timeline'])} 条"
          + (f"，没放进来的 {len(sample['today']['skipped'])} 条：{'；'.join(sample['today']['skipped'])}" if sample['today']['skipped'] else ""))


if __name__ == "__main__":
    main()
