"""
Pour 的原始色板：按 OKLCH 色彩空间的亮度阶梯生成，并按 WCAG 2.2 公式实测对比度。
设计规范 docs/ios/设计规范/01-颜色.md 里的每个色值都来自这里，不手调十六进制。

用法：python3 ios/scripts/palette.py [输出的 json 路径，默认 ios/scripts/palette.json]
      python3 ios/scripts/palette.py --swift          重新生成 PourDesign 的原始色板（PourPalette.swift）
      python3 ios/scripts/palette.py --swift --check  只核对生成的 Swift 是不是最新的（ios/scripts/check.sh 会跑）
改颜色：只改下面的亮度 / 饱和度 / 色相，重新生成；对比度由 PourDesign 的测试把关，不达标就红。
"""
import math, json, sys
sys.stdout.reconfigure(encoding='utf-8')
def oklch_to_srgb(L, C, h):
    a = C*math.cos(math.radians(h)); b = C*math.sin(math.radians(h))
    l_ = L + 0.3963377774*a + 0.2158037573*b
    m_ = L - 0.1055613458*a - 0.0638541728*b
    s_ = L - 0.0894841775*a - 1.2914855480*b
    l, m, s = l_**3, m_**3, s_**3
    r = 4.0767416621*l - 3.3077115913*m + 0.2309699292*s
    g = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
    bb = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
    return [r, g, bb]
def inside(rgb): return all(-1e-4 <= c <= 1+1e-4 for c in rgb)
def to_hex(L, C, h):
    # 超出色域就降饱和度
    c = C
    while c > 0 and not inside(oklch_to_srgb(L, c, h)): c -= 0.002
    rgb = [min(1, max(0, v)) for v in oklch_to_srgb(L, max(c, 0), h)]
    enc = [ (v*12.92 if v <= 0.0031308 else 1.055*v**(1/2.4)-0.055) for v in rgb]
    return '#%02X%02X%02X' % tuple(round(v*255) for v in enc)
def lin(c):
    c = c/255; return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
def lum(hx):
    hx = hx.lstrip('#'); r, g, b = [int(hx[i:i+2], 16) for i in (0, 2, 4)]
    return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b)
def cr(a, b):
    la, lb = lum(a), lum(b); hi, lo = max(la, lb), min(la, lb); return (hi+0.05)/(lo+0.05)

out = {}
# 纸墨中性色：暖灰，色相 85，饱和度很低
NEU = [(0,1.000,0.000),(25,0.985,0.003),(50,0.968,0.006),(100,0.940,0.006),(150,0.905,0.006),(200,0.865,0.006),(300,0.790,0.006),
       (400,0.700,0.006),(500,0.610,0.006),(600,0.530,0.006),(700,0.450,0.006),(800,0.360,0.005),(850,0.300,0.005),(900,0.245,0.005),(925,0.215,0.004),(950,0.195,0.004),(975,0.175,0.004),(1000,0.150,0.003)]
out['neutral'] = {k: to_hex(L, C, 85) for k, L, C in NEU}
# 青：色相 192
QING = [(50,0.965,0.020),(100,0.930,0.035),(200,0.870,0.055),(300,0.790,0.075),(400,0.700,0.090),(500,0.610,0.095),(600,0.520,0.088),(700,0.440,0.078),(800,0.360,0.065),(900,0.280,0.050)]
out['qing'] = {k: to_hex(L, C, 192) for k, L, C in QING}
# 琥珀：色相 70
AMB = [(50,0.965,0.030),(100,0.930,0.050),(300,0.800,0.100),(500,0.640,0.120),(600,0.560,0.110),(700,0.480,0.095)]
out['amber'] = {k: to_hex(L, C, 70) for k, L, C in AMB}
# 荧光笔（搜索命中、原话里对应的那一段）
out['marker'] = {'light': to_hex(0.935, 0.075, 98), 'dark': to_hex(0.40, 0.065, 90)}
# 九个领域色：亮色 solid、暗色 solid、亮色浅底、暗色浅底、亮色文字、暗色文字
DOM = [('stone','石',85,0.012),('clay','陶',50,0.060),('apricot','杏',55,0.105),('straw','麦',88,0.095),('moss','苔',150,0.075),
       ('lake','湖',245,0.080),('wisteria','藤',300,0.080),('sakura','樱',355,0.080),('brick','砖',30,0.100)]
out['domain'] = {}
for key, name, h, c in DOM:
    out['domain'][key] = {
        'name': name, 'hue': h,
        'solidLight': to_hex(0.615, c, h), 'solidDark': to_hex(0.730, c*0.95, h),
        'bgLight': to_hex(0.955, c*0.22, h), 'bgDark': to_hex(0.290, c*0.35, h),
        'textLight': to_hex(0.430, c*0.85, h), 'textDark': to_hex(0.860, c*0.55, h),
    }
if '--swift' in sys.argv:
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, '..', 'Packages', 'PourKit', 'Sources', 'PourDesign', 'Generated', 'PourPalette.swift')
    def h(x): return '0x' + x.lstrip('#')
    lines = ['// 生成的文件：ios/scripts/palette.py --swift。不要手改——改颜色改脚本里的亮度、饱和度、色相。',
             '// 原始色板只在令牌定义里用（PourColor），界面代码不直接引用（设计规范 01 第 1 节）。', '',
             '/// 原始色板（OKLCH 生成）', 'public enum PourPalette {']
    for k, v in out['neutral'].items(): lines.append(f'    public static let paper{k} = RGB({h(v)})')
    for k, v in out['qing'].items(): lines.append(f'    public static let qing{k} = RGB({h(v)})')
    for k, v in out['amber'].items(): lines.append(f'    public static let amber{k} = RGB({h(v)})')
    lines.append(f"    public static let markerLight = RGB({h(out['marker']['light'])})")
    lines.append(f"    public static let markerDark = RGB({h(out['marker']['dark'])})")
    lines.append('}')
    lines += ['', '/// 九个生活领域的颜色（规范 01 第 3.1 节）：实色、浅底、文字，亮暗各一',
              'public enum PourDomain: String, CaseIterable, Sendable {']
    for k, d in out['domain'].items(): lines.append(f"    /// {d['name']}\n    case {k}")
    lines += ['', '    public var palette: DomainPalette {', '        switch self {']
    for k, d in out['domain'].items():
        lines.append(f"        case .{k}:")
        lines.append("            DomainPalette(")
        lines.append(f"                name: \"{d['name']}\",")
        lines.append(f"                solidLight: RGB({h(d['solidLight'])}), solidDark: RGB({h(d['solidDark'])}),")
        lines.append(f"                bgLight: RGB({h(d['bgLight'])}), bgDark: RGB({h(d['bgDark'])}),")
        lines.append(f"                textLight: RGB({h(d['textLight'])}), textDark: RGB({h(d['textDark'])}))")
    lines += ['        }', '    }', '}', '']
    text = '\n'.join(lines).replace('\\n', '\n')
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if '--check' in sys.argv:
        current = open(target, encoding='utf-8').read() if os.path.exists(target) else ''
        if current != text:
            print('PourPalette.swift 不是最新的：运行 python3 ios/scripts/palette.py --swift'); sys.exit(1)
        print('原始色板是最新的'); sys.exit(0)
    open(target, 'w', encoding='utf-8').write(text)
    print('已生成', os.path.normpath(target)); sys.exit(0)

json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else 'ios/scripts/palette.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

N, Q = out['neutral'], out['qing']
print('中性色', N)
print('青', Q)
print('琥珀', out['amber'], '荧光', out['marker'])
# 语义令牌对应和对比度
light = {'canvas': N[50], 'surface': N[0], 'ink': N[950], 'ink2': N[700], 'ink3': N[500]}
dark = {'canvas': N[1000], 'surface': N[925], 'raised': N[900], 'ink': N[50], 'ink2': N[300], 'ink3': N[500]}
print('\n亮色：', light)
for t in ['ink','ink2','ink3']:
    print(f"  {t} 卡上 {cr(light[t], light['surface']):.1f} 纸上 {cr(light[t], light['canvas']):.1f}")
print('暗色：', dark)
for t in ['ink','ink2','ink3']:
    print(f"  {t} 卡上 {cr(dark[t], dark['surface']):.1f} 纸上 {cr(dark[t], dark['canvas']):.1f} 浮层 {cr(dark[t], dark['raised']):.1f}")
print(f"\n墨色按钮（亮）：白字在 {N[950]} 上 {cr('#FFFFFF', N[950]):.1f}；暗色模式按钮 {N[50]} 上墨字 {cr(N[950], N[50]):.1f}")
print(f"青（亮，文字/图形用 600）：卡上 {cr(Q[600], light['surface']):.1f} 纸上 {cr(Q[600], light['canvas']):.1f}；青 700 卡上 {cr(Q[700], light['surface']):.1f}")
print(f"青（暗，用 300）：卡上 {cr(Q[300], dark['surface']):.1f} 纸上 {cr(Q[300], dark['canvas']):.1f}")
print(f"青浅底上的墨字（亮 50/100）：{cr(light['ink'], Q[50]):.1f} / {cr(light['ink'], Q[100]):.1f}；暗 900 上的浅字：{cr(dark['ink'], Q[900]):.1f}")
A = out['amber']
print(f"琥珀 700 文字（亮）：卡上 {cr(A[700], light['surface']):.1f} 纸上 {cr(A[700], light['canvas']):.1f}；暗用 300：{cr(A[300], dark['surface']):.1f}")
M = out['marker']
print(f"荧光底上的墨字：亮 {cr(light['ink'], M['light']):.1f}  暗 {cr(dark['ink'], M['dark']):.1f}")
print('\n领域色：')
for k, d in out['domain'].items():
    print(f"  {d['name']} solid亮 {d['solidLight']} 白卡{cr(d['solidLight'], light['surface']):.2f}/纸{cr(d['solidLight'], light['canvas']):.2f} | solid暗 {d['solidDark']} 暗卡{cr(d['solidDark'], dark['surface']):.2f} | 文字亮 {d['textLight']} 在浅底{cr(d['textLight'], d['bgLight']):.2f}/白{cr(d['textLight'], light['surface']):.2f} | 文字暗 {d['textDark']} 在暗底{cr(d['textDark'], d['bgDark']):.2f}")
print('\n心情五档（亮：青 100/200/300/500/700；暗：900/800/700/500/300）')
for lv,(l,dk) in enumerate([(100,900),(200,800),(300,700),(500,500),(700,300)],1):
    print(f"  {lv} 级 亮 {Q[l]} 对纸 {cr(Q[l], light['canvas']):.2f} · 暗 {Q[dk]} 对暗纸 {cr(Q[dk], dark['canvas']):.2f}")
