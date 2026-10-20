// App 图标的三个方案（M1，docs/归档/设计规范/04-图标与图形.md 第 4 节：「倾倒 → 一条平稳的线」）。
// 每个方案一套亮色（纸底，不透明）和暗色（透明底，系统垫深色）。全部用系统字体（产品主人决定）。
// 用法：swift scripts/make-icons.swift   （在仓库根目录运行；会写画廊和 App 的资源目录）
import AppKit

let size = 1024.0
let paper = color(0xF6F4F0), ink = color(0x161513), qing = color(0x067976)
let inkDark = color(0xF6F4F0), qingDark = color(0x7FCAC7)

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// 方案一：「倾」字 + 青线
func drawChar(ink: NSColor, qing: NSColor) {
    let font = NSFont.systemFont(ofSize: 500, weight: .medium)
    let glyph = NSAttributedString(string: "倾", attributes: [.font: font, .foregroundColor: ink])
    let bounds = glyph.size()
    glyph.draw(at: NSPoint(x: (size - bounds.width) / 2, y: (size - bounds.height) / 2 + 70))
    qing.setFill()
    NSBezierPath(roundedRect: NSRect(x: size / 2 - 150, y: 210, width: 300, height: 24), xRadius: 12, yRadius: 12).fill()
}

/// 方案二：倾斜的杯子（开口朝右下），从杯沿流下一笔青，落成一条平稳的线
func drawPour(ink: NSColor, qing: NSColor) {
    // 杯身：上宽下窄、没有顶的杯子，绕中心转 40°
    let cup = NSBezierPath()
    cup.move(to: NSPoint(x: -105, y: 150))
    cup.line(to: NSPoint(x: -80, y: -140))
    cup.curve(to: NSPoint(x: -50, y: -170), controlPoint1: NSPoint(x: -78, y: -160), controlPoint2: NSPoint(x: -66, y: -170))
    cup.line(to: NSPoint(x: 50, y: -170))
    cup.curve(to: NSPoint(x: 80, y: -140), controlPoint1: NSPoint(x: 66, y: -170), controlPoint2: NSPoint(x: 78, y: -160))
    cup.line(to: NSPoint(x: 105, y: 150))
    var transform = AffineTransform()
    transform.translate(x: 370, y: 610)
    transform.rotate(byDegrees: -40)
    cup.transform(using: transform)
    ink.setStroke()
    cup.lineWidth = 36
    cup.lineCapStyle = .round
    cup.lineJoinStyle = .round
    cup.stroke()
    // 杯沿（右上角转过去的位置）流下来，落地后变成一条平线
    let lip = transform.transform(NSPoint(x: 105, y: 150))
    let stream = NSBezierPath()
    stream.move(to: NSPoint(x: lip.x + 6, y: lip.y - 4))
    stream.curve(to: NSPoint(x: 640, y: 270), controlPoint1: NSPoint(x: lip.x + 90, y: lip.y - 60), controlPoint2: NSPoint(x: 620, y: 400))
    stream.curve(to: NSPoint(x: 720, y: 230), controlPoint1: NSPoint(x: 650, y: 240), controlPoint2: NSPoint(x: 680, y: 230))
    stream.line(to: NSPoint(x: 820, y: 230))
    stream.move(to: NSPoint(x: 204, y: 230))
    stream.line(to: NSPoint(x: 720, y: 230))
    qing.setStroke()
    stream.lineWidth = 36
    stream.lineCapStyle = .round
    stream.lineJoinStyle = .round
    stream.stroke()
}

/// 方案三：只有一笔青——从高处顺势落下，慢慢收成一条平稳的线
func drawLine(ink _: NSColor, qing: NSColor) {
    let stroke = NSBezierPath()
    stroke.move(to: NSPoint(x: 250, y: 740))
    stroke.curve(to: NSPoint(x: 560, y: 330), controlPoint1: NSPoint(x: 290, y: 520), controlPoint2: NSPoint(x: 410, y: 330))
    stroke.line(to: NSPoint(x: 790, y: 330))
    qing.setStroke()
    stroke.lineWidth = 52
    stroke.lineCapStyle = .round
    stroke.lineJoinStyle = .round
    stroke.stroke()
}

func render(_ draw: (NSColor, NSColor) -> Void, dark: Bool, to path: String) throws {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
            bitsPerPixel: 0)
    else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    if !dark {
        paper.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
    }
    draw(dark ? inkDark : ink, dark ? qingDark : qing)
    NSGraphicsContext.restoreGraphicsState()
    // 亮色图标不能带透明通道（App Store 会拒）：拍平成不透明
    var output = rep
    if !dark, let cgImage = rep.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    {
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        if let flat = context.makeImage() { output = NSBitmapImageRep(cgImage: flat) }
    }
    guard let png = output.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: URL(fileURLWithPath: path))
}

func iconSet(dir: String) throws {
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let json = """
        {
          "images" : [
            { "filename" : "light.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
            { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
          ],
          "info" : { "author" : "xcode", "version" : 1 }
        }

        """
    try json.write(toFile: dir + "/Contents.json", atomically: true, encoding: .utf8)
}

func previewSet(dir: String, source: String) throws {
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(atPath: dir + "/preview.png")
    try FileManager.default.copyItem(atPath: source, toPath: dir + "/preview.png")
    let json = """
        { "images" : [ { "filename" : "preview.png", "idiom" : "universal" } ], "info" : { "author" : "xcode", "version" : 1 } }

        """
    try json.write(toFile: dir + "/Contents.json", atomically: true, encoding: .utf8)
}

let designs: [(String, (NSColor, NSColor) -> Void)] = [("IconChar", drawChar), ("IconPour", drawPour), ("IconLine", drawLine)]
let gallery = "Gallery/Resources/Assets.xcassets"
for (name, draw) in designs {
    // 画廊：方案一是默认图标 AppIcon，另外两个是可以切换的图标
    let set = "\(gallery)/\(name == "IconChar" ? "AppIcon" : name).appiconset"
    try iconSet(dir: set)
    try render(draw, dark: false, to: set + "/light.png")
    try render(draw, dark: true, to: set + "/dark.png")
    try previewSet(dir: "\(gallery)/\(name)-preview.imageset", source: set + "/light.png")
}
// 正式 App 先用方案一（产品主人选定后换成选中的那个）
let app = "App/Resources/Assets.xcassets/AppIcon.appiconset"
for file in ["icon-light.png", "icon-dark.png"] { try? FileManager.default.removeItem(atPath: "\(app)/\(file)") }
try iconSet(dir: app)
try render(drawChar, dark: false, to: app + "/light.png")
try render(drawChar, dark: true, to: app + "/dark.png")
print("三个图标方案已生成：画廊 \(gallery)，正式 App 先用方案一")
