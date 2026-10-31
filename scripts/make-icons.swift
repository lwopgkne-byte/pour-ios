// App 图标（M1，docs/归档/设计规范/04-图标与图形.md 第 4 节：「倾」字 + 一条平稳的青线）。
// 一套亮色（纸底，不透明）和暗色（透明底，系统垫深色）。用系统字体（产品主人决定）。
// 另外两个方案（倾斜的杯子、一笔青线）和放它们的设计画廊在 3.0 第 0 步删掉了，要看去 Git 历史（标签 ios-2.8）。
// 用法：swift scripts/make-icons.swift   （在仓库根目录运行；会写 App 的资源目录）
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

// 正式 App 用方案一
let app = "App/Resources/Assets.xcassets/AppIcon.appiconset"
for file in ["icon-light.png", "icon-dark.png"] { try? FileManager.default.removeItem(atPath: "\(app)/\(file)") }
try iconSet(dir: app)
try render(drawChar, dark: false, to: app + "/light.png")
try render(drawChar, dark: true, to: app + "/dark.png")
print("App 图标已生成：\(app)")
